//
//  NetworkManager+Download.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/26.
//

import Alamofire
import FTTool

// ═══════════════════════════════════════════════════════════════
// MARK: - 下载完成回调类型
// ═══════════════════════════════════════════════════════════════

/// 下载完成回调。
///
/// 成功和失败共用一个回调，通过两个 Optional 区分：
/// - 成功：`destUrl` 非 nil，`error` 为 nil
/// - 失败：`destUrl` 为 nil，`error` 非 nil
///
/// - Parameters:
///   - destUrl: 下载后的本地文件 URL
///   - error: 网络错误
public typealias DownloadCompletion = (_ destUrl: URL?, _ error: NetworkError?) -> Void


extension NetworkManager {

    // ═══════════════════════════════════════════════════════════
    // MARK: - 普通下载（完整实现）
    // ═══════════════════════════════════════════════════════════

    /// 下载文件（完整实现）。
    ///
    /// 完整链路：
    /// 1. 显示 loading HUD
    /// 2. 参数转 Encodable（Alamofire 5 要求）
    /// 3. 创建 DownloadRequest（含目标路径、超时）
    /// 4. 记录重试信息
    /// 5. 监听下载进度
    /// 6. 监听响应（成功/失败映射错误）
    /// 7. 隐藏 loading HUD
    ///
    /// - Parameters:
    ///   - apiConvertable: 下载请求对象（含 URL、参数、目标路径等）
    ///   - progressCallback: 下载进度回调（0.0~1.0）
    ///   - queue: 回调和进度的执行队列（默认全局队列）
    ///   - completion: 下载完成回调
    /// - Returns: 请求 id（UUID 字符串，用于取消/暂停）
    @discardableResult
    public func download(
        apiConvertable: DownloadConvertable,
        progressCallback: ((Progress) -> Void)? = nil,
        queue: DispatchQueue = .global(),
        completion: @escaping DownloadCompletion
    ) -> String {

        // ① 显示 loading HUD
        //    如果 apiConvertable.hudConfig?.loading 有配置，会显示
        checkShowHUD(apiConvertable: apiConvertable)

        // ② 参数转 Encodable
        //    Alamofire 5 的 download 要求参数是 Encodable
        //    但 apiConvertable.parameters 是 [String: Any]?，需要包装
        let encodableParameters: AnyEncodable? = {
            // 参数为 nil，直接返回 nil
            guard let parameters = apiConvertable.parameters else { return nil }

            // 如果已经是 Encodable，直接包装
            if let encodable = parameters as? Encodable {
                return AnyEncodable(encodable)
            }

            // 否则包装原始参数（[String: Any]）
            // ⚠️ 注意：AnyEncodable 内部用 JSONEncoder 编码，
            //    [String: Any] 里的 Any 值（如 Date）可能编码失败
            return AnyEncodable(parameters)
        }()

        // ③ 下载目标目录（可能为 nil）
        //    用 var 是因为 destination 闭包里会修改它
        var fileUrl = apiConvertable.downloadDir

        // ④ 创建 DownloadRequest
        let downloadRequest = session.download(
            apiConvertable.requestUrlString,           // URL
            method: apiConvertable.method,             // HTTP 方法（GET / POST）
            parameters: encodableParameters,           // 参数
            encoder: apiConvertable.encoder,           // 参数编码器
            headers: HTTPHeaders(apiConvertable.headers),   // 请求头
            interceptor: apiConvertable.authInterceptor,    // 拦截器（token 刷新等）
            requestModifier: { request in
                // ⑤ 设置超时
                request.timeoutInterval = apiConvertable.timeout
            }
        ) { _, response -> (destinationURL: URL, options: DownloadRequest.Options) in
            // ⑥ 目标路径闭包
            //    在下载开始时调用（收到响应头后），决定文件最终存哪

            // 如果没指定目录，用 Caches 目录
            if fileUrl == nil {
                fileUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            }

            // 如果有指定文件名，用它
            if let filename = apiConvertable.filename, !filename.isEmpty {
                fileUrl = fileUrl?.appendingPathComponent(filename)
            } else {
                // 否则用服务端建议的文件名（从 Content-Disposition 头解析）
                fileUrl = fileUrl?.appendingPathComponent(response.suggestedFilename ?? "download")
            }

            // 返回目标路径 + 选项
            // - removePreviousFile：同名文件覆盖
            // - createIntermediateDirectories：自动创建中间目录
            return (fileUrl!, [.removePreviousFile, .createIntermediateDirectories])
        }

        // ⑦ 记录重试信息
        //    用于后续的 addRetryInfo / deleteRetryInfo / cancelRequest
        addRetryInfo(with: downloadRequest)

        // ⑧ 监听下载进度
        downloadRequest
            .downloadProgress(queue: queue) { progress in
                // 打进度日志（含文件路径和百分比）
                FTLogger.info(message: "\(fileUrl?.absoluteString ?? "") 下载进度：\(progress.fractionCompleted)")
                // 回调给调用方
                progressCallback?(progress)
            }
            // ⑨ 监听响应
            //    ⚠️ 用 responseData 而不是 response：
            //       - responseData 的 success 是 Data（文件内容）
            //       - response 的 success 是 URL（文件路径）
            //       - 这里用 responseData 是为了算 MD5
            .responseData(queue: queue) { response in

                // ⑩ 清除重试信息
                self.deleteRetryInfo(with: downloadRequest)

                var networkError: NetworkError?

                switch response.result {
                case let .success(fileData):
                    // ⑪ 成功：打日志（含 MD5）+ 回调
                    FTLogger.success(message: "下载完成 SUCCESS \(fileData.md5String ?? "md5_failed")")
                    completion(fileUrl, nil)

                case let .failure(err):
                    // ⑫ 失败：打日志 + 映射错误
                    FTLogger.error(message: "下载失败 FAILED:\n\(err.localizedDescription)")

                    // 先转 NSError 判断常见的 URL 错误
                    let nserr = err as NSError

                    if nserr.code == NSURLErrorNotConnectedToInternet {
                        // 无网络
                        networkError = NetworkError.noNetwork
                    } else if nserr.code == NSURLErrorTimedOut {
                        // 超时
                        networkError = NetworkError.networkTimeout
                    } else {
                        // 其他 AFError，进一步细分
                        let aferr = err as AFError
                        switch aferr {
                        case let .sessionTaskFailed(error: tempErr):
                            // 底层 URLSession 任务失败（如 DNS 失败、连接中断）
                            networkError = NetworkError.responseError(tempErr)
                        case .explicitlyCancelled:
                            // 主动取消
                            networkError = NetworkError.cancelError
                        default:
                            // 其他 AFError
                            networkError = NetworkError.responseError(aferr)
                        }
                    }
                    // 回调失败
                    completion(nil, networkError)
                }

                // ⑬ 隐藏 loading HUD
                //    根据 err 是否 nil 决定显示成功还是失败提示
                self.checkHideHUD(apiConvertable: apiConvertable, err: networkError)
            }

        // ⑭ 返回请求 id（用于取消/暂停）
        return downloadRequest.id.uuidString
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 普通下载（半成品）
    // ═══════════════════════════════════════════════════════════

    /// 下载文件（半成品）。
    ///
    /// ⚠️ 问题：
    /// 1. 没有调用 `completion`（调用方永远收不到结果）
    /// 2. 没有调用 `progressCallback`（调用方收不到进度）
    /// 3. 没有显示/隐藏 HUD
    /// 4. 没有 `addRetryInfo` / `deleteRetryInfo`（无法重试和取消）
    /// 5. `destination` 闭包打"文件下载且保存成功1"日志（时机不对，还没下载完）
    /// 6. `[weak self]` 未使用（闭包里没用到 self）
    ///
    /// 结论：**半成品，生产代码应该用 `download`**。
    public func download2(
        apiConvertable: DownloadConvertable,
        progressCallback: ((Progress) -> Void)? = nil,
        queue: DispatchQueue = .global(),
        completion: @escaping DownloadCompletion
    ) -> String {

        // ① 下载目标目录
        var fileUrl = apiConvertable.downloadDir

        // ② 目标路径闭包
        let destination: DownloadRequest.Destination = { [weak self] _, res in
            // ⚠️ 时机不对：这里在下载"开始时"调用，还没下载完
            FTLogger.info(message: "文件下载且保存成功1")

            // 如果没指定目录，用 Caches
            if fileUrl == nil {
                fileUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            }

            // 如果有指定文件名，用它
            if let filename = apiConvertable.filename {
                fileUrl = fileUrl?.appendingPathComponent(filename)
            } else {
                // 否则用服务端建议的文件名
                fileUrl = fileUrl?.appendingPathComponent(res.suggestedFilename ?? "download")
            }

            // 返回目标路径 + 选项
            // 两个选项表示：
            // - 如果有同名文件则覆盖
            // - 如果路径中文件夹不存在则自动创建
            return (fileUrl!, [.removePreviousFile, .createIntermediateDirectories])
        }

        // ③ 参数转 Encodable（和 download 一样）
        let encodableParameters: AnyEncodable? = {
            guard let parameters = apiConvertable.parameters else { return nil }
            if let encodable = parameters as? Encodable {
                return AnyEncodable(encodable)
            }
            return AnyEncodable(parameters)
        }()

        // ④ 创建 DownloadRequest + 监听响应 + 监听进度
        let request = session.download(
            apiConvertable.requestUrlString,
            method: apiConvertable.method,
            parameters: encodableParameters,
            encoder: apiConvertable.encoder,
            headers: HTTPHeaders(apiConvertable.headers),
            interceptor: apiConvertable.authInterceptor,
            requestModifier: { request in
                request.timeoutInterval = apiConvertable.timeout
            },
            to: destination
        )
        // ⑤ 响应回调（⚠️ 只打日志，没调 completion）
        .response(completionHandler: { [weak self] response in
            switch response.result {
            case .success(let fileUrl):
                FTLogger.info(message: "fileUrl:\(fileUrl)")
            case .failure(let error):
                FTLogger.info(message: "downloadRequest: \(error.localizedDescription)===\(apiConvertable.requestUrlString)")
            }
        })
        // ⑥ 进度回调（⚠️ 只打日志，没调 progressCallback）
        .downloadProgress(closure: { [weak self] progress in
            FTLogger.info(message: "=======下载进度：\(progress)")
        })

        // ⑦ 返回请求 id
        return request.id.uuidString
    }
}
