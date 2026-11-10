//
//  NetworkManager+Upload.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/26.
//

import FTTool
import Alamofire

// MARK: - 批量上传(并发调度层)

public extension NetworkManager {

    // ─────────────────────────────────────────────────────────────
    // 批量上传入口(基于文件 URL)
    // 参数:
    //   - url: 上传接口地址,默认空(由 UploadTask 自己决定)
    //   - fileUrls: 待上传文件的本地 URL 列表
    //   - callbackQueue: 回调派发队列,默认主线程
    //   - completion: 全部完成后的回调
    //
    // ⚠️ 严重问题:这是一个"空壳"实现
    //   1. createUploadTasks 创建了任务列表,但 tasks 之后从未被使用 → 没有任何上传真正发生
    //   2. completion 从未调用 → 调用方永远等不到回调
    //   3. callbackQueue 从未使用
    //   4. url 从未使用
    //   这个 API 看起来能批量上传,实际什么都不做,极易误用,应删除或补全实现。
    // ─────────────────────────────────────────────────────────────
    func upload(url: String = "", fileUrls: [URL], callbackQueue: DispatchQueue = .main, completion: VoidClosure?) {
        let tasks = createUploadTasks(fileUrls: fileUrls)
        // ⚠️ 到这里 tasks 被丢弃,没有发起上传,也没有回调
    }

    // ─────────────────────────────────────────────────────────────
    // 批量上传入口(基于已创建的 UploadTask)
    // 使用 TaskGroup 并发执行所有上传任务,等待全部完成后统一返回结果。
    //
    // 参数:
    //   - url: 上传接口地址,透传给每个子任务
    //   - uploadTasks: 已构建好的上传任务列表
    // 返回:
    //   - [TaskResult<T>]: 每个任务的结果集合
    //
    // ⚠️ 问题:
    //   1. 泛型 T 必须能由 task.upload(...) 的返回类型推断出来,调用方需显式指定 T,
    //      否则编译失败或推断错误(需核对 UploadTask.upload 是否为泛型方法)。
    //   2. TaskGroup 的结果是"完成顺序",不是 addTask 顺序 →
    //      返回数组与入参 uploadTasks 顺序不一致,调用方按下标对应会错位。
    //   3. 无并发上限:uploadTasks 有 100 个就并发 100 个,会打满连接池/服务端限流。
    //   4. 不可取消:外层取消时子任务感知不到(除非 task.upload 内部检查 Task.isCancelled)。
    //   5. progressHandler 固定传 nil,丢失了进度能力。
    // ─────────────────────────────────────────────────────────────
    func upload<T: Codable>(url: String = "", uploadTasks: [UploadTask]) async -> [TaskResult<T>] {

        // 使用 TaskGroup 并发执行所有上传任务
        // of: 子任务返回类型;returning: 整个 group 的聚合返回类型
        let allResults = await withTaskGroup(of: TaskResult<T>.self, returning: [TaskResult<T>].self) { taskGroup in

            // 为每个上传任务创建一个子 Task,并发执行
            for task in uploadTasks {
                taskGroup.addTask {
                    // ⚠️ progressHandler 传 nil,批量场景下没有暴露进度
                    await task.upload(url: url, progressHandler: nil)
                }
            }

            // 等待所有任务完成,并收集结果
            // for await 会按"任务完成先后"逐个产出结果
            var childTaskResults = [TaskResult<T>]()
            for await result in taskGroup {
                // ⚠️ 追加顺序 = 完成顺序,与 uploadTasks 入参顺序不一致
                childTaskResults.append(result)
            }
            return childTaskResults
        }

        FTLogger.info(message: "所有任务已完成")
        return allResults
    }

    // ─────────────────────────────────────────────────────────────
    // 根据文件 URL 列表批量创建 UploadTask
    // 参数:
    //   - fileUrls: 本地文件 URL 列表
    // 返回:
    //   - [UploadTask]: 每个 URL 对应一个上传任务
    // 说明:
    //   简单的 map 转换,无异常处理;UploadFileURL 封装了文件路径。
    // ─────────────────────────────────────────────────────────────
    func createUploadTasks(fileUrls: [URL]) -> [UploadTask] {
        let tasks = fileUrls.map { UploadTask(data: UploadFileURL(fileURL: $0)) }
        return tasks
    }
}


// MARK: - 单个上传任务实现

public extension NetworkManager {

    // MARK: - 普通上传
    // ─────────────────────────────────────────────────────────────
    // 单个文件上传(Alamofire stream 上传 + 进度 + 失败重试)
    //
    // 参数:
    //   - task: 上传任务(含请求地址、headers、数据 stream、超时、重试次数、鉴权拦截器)
    //   - resType: 期望的响应模型类型(用于类型推断/解析)
    //   - url: 覆盖 task 自带的请求地址;为空则用 task.requestUrlString
    //   - callbackQueue: 响应回调派发队列,默认主线程
    //   - file/function/line: 调用位置信息,用于错误日志定位
    //   - completion: 上传完成回调(成功模型 / 错误)
    // 返回:
    //   - Alamofire.Request?: 可用于外部取消/监听;创建失败返回 nil
    //
    // 流程:
    //   1. 显示 loading
    //   2. 构建 URLRequest
    //   3. 获取数据 stream
    //   4. 发起 AF.upload,挂进度回调
    //   5. 若配置了重试次数,注册重试信息
    //   6. 响应回调:清理重试信息 → 交给 handleDataResponse 统一处理
    // ─────────────────────────────────────────────────────────────
    @discardableResult
    public func normalUpload<T>(_ task: UploadTask,
                                resType: T.Type,
                                url: String = "",
                                callbackQueue: DispatchQueue = .main,
                                file: StaticString = #file,
                                function: StaticString = #function,
                                line: UInt = #line,
                                completion: NetworkResponseCompletion<T>? = nil) -> Alamofire.Request? {

        // 显示 loading(全局 HUD)
        // ⚠️ 注意:后续任何失败路径都应有对应的 HUD 收尾,否则 loading 会残留
        checkShowHUD(apiConvertable: task)

        // 构建 URLRequest
        // 使用隐式解包可选,配合 catch 只打日志 + 后面 nil 判断兜底
        // ⚠️ catch 里没有 return,依赖 urlRequest == nil 兜底,逻辑较脆
        var urlRequest: URLRequest!
        do {
            let uploadUrl = url.isEmpty ? task.requestUrlString : url
            urlRequest = try URLRequest(url: uploadUrl, method: .post, headers: HTTPHeaders(task.headers))
            urlRequest.timeoutInterval = task.timeout
            FTLogger.info(message: "开始上传\(task.id)：\(uploadUrl)")
            FTLogger.info(message: task.headers)
        } catch let error {
            // ⚠️ 只记录日志,未立即返回,依赖下面 nil 判断
            FTLogger.error(message: "\(task.id) 上传失败: \(error.localizedDescription)")
        }

        // URLRequest 创建失败:回调错误并返回
        // ⚠️ 未关闭 HUD,可能导致 loading 残留
        if urlRequest == nil {
            completion?(nil, NetworkError.uploadFailed("url request create failed!", 1))
            return nil
        }

        // 获取数据流(用于流式上传,避免一次性把大文件读进内存)
        // ⚠️ 失败时同样未关闭 HUD
        guard let stream = task.data.stream else {
            completion?(nil, NetworkError.uploadFailed("data stream create failed!", 1))
            return nil
        }

        // 执行上传任务
        // - interceptor: 鉴权拦截器(自动加 token 等)
        // - uploadProgress: 上传进度回调
        let uploadRequest = AF.upload(stream, with: urlRequest, interceptor: task.authInterceptor)
            .uploadProgress { progress in
                // ⚠️ 性能问题:进度回调频率很高(每上传一块数据一次),
                //    这里每次都打日志(字符串拼接 + IO)会显著拖慢上传。
                //    应改为采样(如进度每变化 5% 才打)或降低日志级别。
                FTLogger.info(message: "\(task.id) 上传进度: \(progress.fractionCompleted)")
            }

        // 加入失败重试:若配置了重试次数,注册重试信息
        // 说明:addRetryInfo 应该是把 request 与重试策略关联起来(具体实现依赖 FTTool)
        if task.defaultRetryCount > 0 {
            addRetryInfo(with: uploadRequest)
        }

        // 响应回调
        // ⚠️ 问题:
        //   1. [weak self] + guard let strongSelf = self else { return }
        //      → self 释放时 completion 永不回调,调用方挂起;且重试信息不清理会泄漏
        //   2. deleteRetryInfo 依赖 self,应解耦为不依赖实例的调用
        uploadRequest.response(queue: callbackQueue) { [weak self] response in
            guard let strongSelf = self else { return }   // ⚠️ 直接 return,回调丢失

            // 清理重试信息(必须在响应后执行,避免重试表无限增长)
            if task.defaultRetryCount > 0 {
                strongSelf.deleteRetryInfo(with: uploadRequest)
            }

            // 统一处理响应(解析模型、错误映射、HUD 收尾等,由 handleDataResponse 实现)
            strongSelf.handleDataResponse(response,
                                          apiConvertable: task,
                                          request: uploadRequest,
                                          file: file,
                                          function: function,
                                          line: line,
                                          completion: completion)
        }
        return uploadRequest
    }
}
