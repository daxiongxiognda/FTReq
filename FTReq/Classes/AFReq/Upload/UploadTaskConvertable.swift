//
//  UploadTaskConvertable.swift
//  FTTool
//
//  Created by 熊坤鹏 on 2026/10/28.
//

import FTTool
import Alamofire

// MARK: - 上传任务

/// 单个上传任务的封装
/// 实现 ApiConvertable,复用网络层的请求描述能力(URL/headers/方法/拦截器)
/// 核心方法 upload<T> 提供 async 版本的上传,并解析为 TaskResult<T>
public class UploadTask: ApiConvertable {

    /// 任务唯一标识(默认 UUID),用于日志追踪与重试管理
    public var id: String

    /// 上传数据源(文件 URL / 内存 Data / UIImage 等,遵循 UploadDatable)
    public var data: UploadDatable

    public init(data: UploadDatable, id: String = UUID().uuidString) {
        self.data = data
        self.id = id
    }

    // MARK: - ApiConvertable 协议实现(子类/调用方可覆写)

    /// 请求地址(默认空,由调用 upload(url:) 传入实际地址或子类覆写)
    public var requestUrlString: String {
        return ""
    }

    /// 请求头(默认空,子类可覆写以携带鉴权、Content-Type 等)
    public var headers: [String: String] {
        return [:]
    }

    /// 鉴权拦截器(默认 nil,子类可注入 token 刷新等逻辑)
    public var authInterceptor: BaseInterceptor? {
        return nil
    }

    /// HTTP 方法(默认 POST)
    public var method: Alamofire.HTTPMethod {
        return .post
    }

    // MARK: - 响应转换

    /// 将 Alamofire 的原始响应转换为 TaskResult<T>
    /// - Parameter response: AFDataResponse<Data?>,即 Alamofire 的原始响应
    /// - Returns: 统一的任务结果(含 code 与泛型数据)
    ///
    /// 解析策略:
    ///   1. 取 HTTP statusCode(失败时为 0)
    ///   2. success 且有 data → 尝试 JSONDecoder 解码为 T
    ///      - 解码成功:TaskResult(code:statusCode, data: res)
    ///      - 解码失败:记录错误,返回无 data 的 TaskResult(code:statusCode)
    ///   3. success 但 data 为 nil → 记录"未返回数据",返回无 data 结果
    ///   4. failure → 取 error.responseCode(无则用 statusCode),返回无 data 结果
    ///
    /// ⚠️ 问题:
    ///   1. code 直接用 HTTP statusCode(如 200/500),没有区分业务码,
    ///      若服务端把业务错误放在 body 里而 HTTP 仍是 200,这里无法识别失败
    ///   2. 解码失败也返回 code=statusCode(可能 200),调用方会误判成功
    ///   3. 失败时把 error.responseCode(可能是 -999 等)当业务码,
    ///      与成功码语义不一致
    public func convertResponse<T: Codable>(response: AFDataResponse<Data?>) -> TaskResult<T> {
        let statusCode = response.response?.statusCode ?? 0
        FTLogger.info(message: "\(id) 上传结束：\(statusCode)")

        switch response.result {
        case .success(let data):
            if let data = data {
                let dataStr = String(data: data, encoding: .utf8) ?? ""
                FTLogger.success(message: dataStr)
                do {
                    // 把响应 Data 解码为目标类型 T
                    let res = try JSONDecoder().decode(T.self, from: data)
                    return TaskResult(code: statusCode, data: res)
                } catch let error {
                    FTLogger.error(message: "JSON Decode error: \(error.localizedDescription)")
                    // ⚠️ 解码失败仍返回 statusCode(可能 200),调用方易误判成功
                    return TaskResult(code: statusCode)
                }
            } else {
                FTLogger.error(message: "上传成功，但未返回数据")
                return TaskResult(code: statusCode)
            }
        case .failure(let error):
            // ⚠️ errCode 可能是 -999(取消)/ -1001(超时)等,与业务码语义不同
            let errCode = error.responseCode ?? statusCode
            FTLogger.error(message: "上传失败(\(statusCode)--\(errCode))，\(error.localizedDescription)")
            return TaskResult(code: errCode)
        }
    }

    // MARK: - async 上传

    /// 以 Swift Concurrency 方式上传,并返回解析后的结果
    /// - Parameters:
    ///   - url: 上传地址;为空则使用 requestUrlString
    ///   - progressHandler: 进度回调 0~1(⚠️ 当前实现未调用!)
    /// - Returns: TaskResult<T>
    ///
    /// ⚠️ 严重问题:
    ///   1. `progressHandler` 参数**完全未使用**,进度回调形同虚设
    ///   2. `[weak self]` + `guard let strongSelf = self else { return }`
    ///      在 self 释放时**既不 resume 也不回调** → continuation 永久挂起(泄漏)
    ///   3. `totalUnitCount = data.size` 若为 0 → 进度除零得到 inf/nan
    ///   4. 无取消支持,也不检查 Task.isCancelled
    ///   5. `NetworkManager.shared.dataQueue` 是硬编码,无法自定义回调队列
    public func upload<T: Codable>(url: String, progressHandler: ((Double) -> Void)?) async -> TaskResult<T> {
        return await withCheckedContinuation { con in

            // 获取数据流(流式上传,避免大文件进内存)
            guard let stream = data.stream else {
                FTLogger.error(message: "data stream create failed!")
                con.resume(returning: TaskResult(code: -1))
                return
            }

            // 决定上传地址
            let uploadUrl = url.isEmpty ? requestUrlString : url

            // 总字节数(用于计算进度)
            // ⚠️ 若 data.size 为 0,下面除法会得到 inf/nan
            let totalUnitCount = data.size

            // 发起上传
            let uploadRequest = AF.upload(stream,
                                          to: uploadUrl,
                                          method: method,
                                          headers: HTTPHeaders(headers))
                .uploadProgress { [weak self] progress in
                    guard let strongSelf = self else { return }
                    // ⚠️ 进度只打了日志,没有调用外部传入的 progressHandler
                    let tempProgress = Double(progress.completedUnitCount) / Double(totalUnitCount)
                    FTLogger.info(message: "\(strongSelf.id) 上传进度: \(tempProgress)")
                    FTLogger.info(message: "\(strongSelf.id) 已上传: \(progress.completedUnitCount) bytes, 总大小: \(totalUnitCount) bytes")
                }

            // 加入失败重试:此前注释说"加入失败重试",但实际没有调用 addRetryInfo
            // ⚠️ 注释与代码不符,重试逻辑缺失

            // 响应回调
            uploadRequest.response(queue: NetworkManager.shared.dataQueue) { [weak self] response in
                // ⚠️ self 释放时直接 return → continuation 永不 resume → 调用方永久挂起
                guard let strongSelf = self else { return }
                con.resume(returning: strongSelf.convertResponse(response: response))
            }
        }
    }
}


/* UploadTaskOperation(TaskOperation 子类)已注释,未启用
   设计意图:把 UploadTask 包装成 Operation,利用 TaskOperation 的
   暂停/恢复/重试能力。当前未实现完,且 TaskOperation 本身有信号量竞态问题。
class UploadTaskOperation: TaskOperation{
    var task: UploadTask
    var res: TaskResult
    public init(task: UploadTask) {
        self.task = task
        super.init(maxRetryCount: task.defaultRetryCount)
    }

    override func excuteTask(progressHandler: ((Double) -> Void)?) async throws {
        let
        task.upload(url: "")
    }
}*/
