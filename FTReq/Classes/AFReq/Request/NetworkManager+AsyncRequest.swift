//
//  NetworkManager+AsyncRequest.swift
//  FTTool
//
//  Created by 熊坤鹏 on 2026/10/27.
//

import Alamofire
import Combine

// ═══════════════════════════════════════════════════════════════
// MARK: - 模块 1：async/await 封装（不支持取消）
// ═══════════════════════════════════════════════════════════════
//
// 说明：
// - 这些方法用 async/await 语法包装了原有的回调式网络请求
// - 但底层没有传递"取消"信号，所以调用方无法通过 Task.cancel() 取消请求
// - 适合"不关心取消"的场景（如简单的数据加载）
// - 如果需要取消，见后面的 "模块 2：async 支持取消"

extension NetworkManager {

    /// 【async 不支持取消】发请求，返回 (model, error) 元组。
    ///
    /// 用法：
    /// ```swift
    /// let (model, error) = await NetworkManager.shared.sendAsyn(
    ///     request,
    ///     resType: User.self
    /// )
    /// if let user = model { ... }
    /// ```
    ///
    /// ⚠️ 注意：
    /// - **不支持取消**：调用方 `task.cancel()` 无法中断底层请求
    /// - 适合"不关心取消"的场景（如页面已销毁，请求继续跑完也无所谓）
    ///
    /// - Parameters:
    ///   - request: 接口配置
    ///   - resType: 响应模型类型
    ///   - queue: 回调队列（默认主队列）
    ///   - file/function/line: 调用位置（编译期注入）
    /// - Returns: `(model: T?, err: NetworkError?)`
    public func sendAsyn<T: Codable>(
        _ request: ApiConvertable,
        resType: T.Type,
        queue: DispatchQueue = .main,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) async -> (model: T?, err: NetworkError?) {

        // ① withCheckedContinuation：把回调式 API 包装成 async
        //    - 闭包里的 `con` 是 continuation，调用 `con.resume` 恢复 async 函数
        //    - 必须且只能调用一次 resume，否则会崩溃/挂起
        await withCheckedContinuation { con in

            // ② 调 normalRequest（回调式）
            normalRequest(
                apiConvertable: request,
                resType: resType,
                queue: queue,
                file: file,
                function: function,
                line: line
            ) { res, error in

                // ③ 回调里恢复 async 函数，返回 (model, error)
                //    - res?.model：从 ResponseData<T> 里取 data 部分
                //    - error：网络错误
                con.resume(returning: (res?.model, error))
            }
        }
    }

    /// 【async 不支持取消】发请求，返回完整的 (ResponseData<T>?, NetworkError?)。
    ///
    /// 和 `sendAsyn` 的区别：
    /// - `sendAsyn` 只返回 data 部分
    /// - `sendAllAsyn` 返回完整 ResponseData（含 code / msg / 分页字段）
    public func sendAllAsyn<T: Codable>(
        _ request: ApiConvertable,
        resType: T.Type,
        queue: DispatchQueue = .main,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) async -> (res: ResponseData<T>?, err: NetworkError?) {

        await withCheckedContinuation { con in
            normalRequest(
                apiConvertable: request,
                resType: resType,
                queue: queue,
                file: file,
                function: function,
                line: line
            ) { res, error in
                // 直接返回 (ResponseData, error)，不做 model 提取
                con.resume(returning: (res, error))
            }
        }
    }

    /// 【async 不支持取消】发请求，失败时 **throw**。
    ///
    /// 用 `withCheckedThrowingContinuation`（注意多了 Throwing）：
    /// - 成功：`continuation.resume(returning: result)`
    /// - 失败：`continuation.resume(throwing: error)`
    ///
    /// 用法：
    /// ```swift
    /// do {
    ///     let res = try await NetworkManager.shared.asyncThrowingRequest(
    ///         api: request,
    ///         resType: User.self
    ///     )
    ///     print(res.model?.name)
    /// } catch {
    ///     print("失败: \(error)")
    /// }
    /// ```
    public func asyncThrowingRequest<T: Codable>(
        api: ApiConvertable,
        resType: T.Type,
        queue: DispatchQueue = .main,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) async throws -> ResponseData<T> {

        return try await withCheckedThrowingContinuation { continuation in
            NetworkManager.shared.normalRequest(
                apiConvertable: api,
                resType: resType,
                queue: queue,
                file: file,
                function: function,
                line: line
            ) { result, error in
                if let error {
                    // ① 有错误 → 抛错（async 函数会 throw）
                    continuation.resume(throwing: error)
                } else if let result {
                    // ② 成功 → 返回值
                    continuation.resume(returning: result)
                } else {
                    // ③ 既无错误也无结果（理论上不会）→ 抛自定义错误
                    continuation.resume(throwing: NetworkError.custom("Result is nil"))
                }
            }
        }
    }

    /// 【async 不支持取消】发请求，返回 (ResponseData<T>?, NetworkError?) 元组。
    ///
    /// 和 `asyncThrowingRequest` 的区别：
    /// - `asyncThrowingRequest` 失败时 throw
    /// - `asyncRequest` 失败时返回 error 元组（不 throw）
    ///
    /// 适合"不想用 do-catch，想用元组解包"的场景。
    public func asyncRequest<T: Codable>(
        api: ApiConvertable,
        resType: T.Type,
        queue: DispatchQueue = .main,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) async -> (result: ResponseData<T>?, error: NetworkError?) {

        return await withCheckedContinuation { continuation in
            NetworkManager.shared.normalRequest(
                apiConvertable: api,
                resType: resType,
                queue: queue,
                file: file,
                function: function,
                line: line
            ) { result, error in
                // 直接返回 (result, error)
                continuation.resume(returning: (result, error))
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 模块 1 续：ApiConvertable 扩展（让接口对象直接 await）
// ═══════════════════════════════════════════════════════════════
//
// 说明：
// - 给 ApiConvertable 加扩展，让接口对象可以直接 `try await request.asyncThrowingRequest()`
// - 比 `NetworkManager.shared.asyncThrowingRequest(api: request)` 更简洁

extension ApiConvertable {

    /// 【async 不支持取消】发请求，返回 data 部分（T）。
    ///
    /// 用法：
    /// ```swift
    /// let user = try await loginRequest.asyncThrowingRequest(resType: User.self)
    /// ```
    ///
    /// 内部流程：
    /// 1. 调 NetworkManager.asyncThrowingRequest 拿到 ResponseData<T>
    /// 2. 从 ResponseData 里取 model
    /// 3. model 为 nil → throw
    /// 4. 否则返回 model
    public func asyncThrowingRequest<T: Codable>(
        resType: T.Type = ResNil.self,
        queue: DispatchQueue = .main,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) async throws -> T {

        // ① 调 NetworkManager 的 asyncThrowingRequest（拿 ResponseData<T>）
        guard let model = try await NetworkManager.shared.asyncThrowingRequest(
            api: self,
            resType: resType,
            queue: queue,
            file: file,
            function: function,
            line: line
        ).model else {
            // ② model 为 nil → throw
            throw NetworkError.custom("Model is nil")
        }

        // ③ 返回 model
        return model
    }

    /// 【async 不支持取消】发请求，返回完整 ResponseData<T>。
    public func asyncAllThrowingRequest<T: Codable>(
        resType: T.Type = ResNil.self,
        queue: DispatchQueue = .main,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) async throws -> ResponseData<T> {

        // 直接转调 NetworkManager 的 asyncThrowingRequest
        return try await NetworkManager.shared.asyncThrowingRequest(
            api: self,
            resType: resType,
            queue: queue,
            file: file,
            function: function,
            line: line
        )
    }

    /// 【async 不支持取消】发请求，返回 (model, error) 元组。
    ///
    /// 内部流程：
    /// 1. 调 NetworkManager.asyncRequest（拿 ResponseData<T> + error）
    /// 2. 从 ResponseData 里取 model
    /// 3. 返回 (model, error)
    public func asyncRequest<T: Codable>(
        resType: T.Type = ResNil.self,
        queue: DispatchQueue = .main,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) async -> (model: T?, error: NetworkError?) {

        // ① 调 NetworkManager.asyncRequest
        let value = await NetworkManager.shared.asyncRequest(
            api: self,
            resType: resType,
            queue: queue,
            file: file,
            function: function,
            line: line
        )

        // ② 从 ResponseData 里取 model，返回 (model, error)
        return (value.result?.model, value.error)
    }

    /// 【async 不支持取消】发请求，返回完整 (ResponseData<T>, error) 元组。
    public func asyncAllRequest<T: Codable>(
        resType: T.Type = ResNil.self,
        queue: DispatchQueue = .main,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) async -> (result: ResponseData<T>?, error: NetworkError?) {

        // 直接转调 NetworkManager.asyncRequest
        return await NetworkManager.shared.asyncRequest(
            api: self,
            resType: resType,
            queue: queue,
            file: file,
            function: function,
            line: line
        )
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 模块 2：async 支持取消（AsyncRequest）
// ═══════════════════════════════════════════════════════════════

/// 可取消的异步请求封装。
///
/// 用法：
/// ```swift
/// let asyncReq = NetworkManager.shared.asyncReq(request, resType: User.self)
///
/// // 方式 1：等待结果
/// let (user, error) = await asyncReq.tupleRes
///
/// // 方式 2：取消
/// asyncReq.cancel()
/// ```
///
/// 核心设计：
/// - 内部持有 `Task<ResponseData<T>, Error>`
/// - 通过 `withTaskCancellationHandler` 实现取消
/// - 通过关联对象把 Alamofire.Request 绑定到 Task，取消时一起取消
public struct AsyncRequest<T: Codable> {

    /// 内部的 Task。
    ///
    /// 类型是 `Task<ResponseData<T>, Error>`：
    /// - 成功：`ResponseData<T>`
    /// - 失败：`Error`（实际是 NetworkError）
    ///
    /// `private`：外部不能直接访问，只能通过 `tupleRes` 和 `cancel` 操作。
    private let task: Task<ResponseData<T>, Error>

    /// 初始化方法。
    ///
    /// `fileprivate`：只允许 `NetworkManager.asyncReq` 内部创建，
    /// 外部不能直接 new。
    fileprivate init(task: Task<ResponseData<T>, Error>) {
        self.task = task
    }

    /// 等待请求结果（异步属性）。
    ///
    /// 用法：
    /// ```swift
    /// let (res, err) = await asyncReq.tupleRes
    /// ```
    ///
    /// 内部逻辑：
    /// - 成功：`task.value` 返回 ResponseData，包装成 (resModel, nil)
    /// - 失败：catch 到 error，包装成 (nil, error as? NetworkError)
    public var tupleRes: (res: ResponseData<T>?, err: NetworkError?) {
        get async {
            do {
                // ① 等待 Task 完成
                let resModel = try await task.value
                return (resModel, nil)
            } catch {
                // ② 失败：error 转 NetworkError
                //    ⚠️ 如果 error 不是 NetworkError，会返回 (nil, nil)
                return (nil, error as? NetworkError)
            }
        }
    }

    /// 取消请求。
    ///
    /// 流程：
    /// 1. 取消 Alamofire 请求（`task.afReq?.cancel()`）
    /// 2. 取消 Task（`task.cancel()`）
    ///
    /// 两者都要取消：
    /// - `afReq.cancel()`：中断网络请求
    /// - `task.cancel()`：触发 `withTaskCancellationHandler` 的 `onCancel`
    public func cancel() {
        task.afReq?.cancel()
        task.cancel()
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 模块 2 续：NetworkManager.asyncReq（创建可取消请求）
// ═══════════════════════════════════════════════════════════════

extension NetworkManager {

    /// 创建可取消的异步请求。
    ///
    /// 用法：
    /// ```swift
    /// let req = NetworkManager.shared.asyncReq(request, resType: User.self)
    /// let (user, error) = await req.tupleRes
    /// // 或
    /// req.cancel()
    /// ```
    ///
    /// 核心流程：
    /// 1. 创建 Alamofire 请求
    /// 2. 创建 Task（含 withTaskCancellationHandler）
    /// 3. 把 Alamofire 请求绑定到 Task（关联对象）
    /// 4. 返回 AsyncRequest 包装
    public func asyncReq<T: Codable>(
        _ request: ApiConvertable,
        resType: T.Type,
        queue: DispatchQueue = .main,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) -> AsyncRequest<T> {

        // ① 创建 Alamofire 请求
        //    注意：createNormalRequest 内部会显示 HUD、合并 headers、加 Cookie、加入重试
        let normalRequest = createNormalRequest(apiConvertable: request)

        // ② 创建 Task
        //    `var` 是因为后面要绑定 afReq（关联对象）
        var task = Task<ResponseData<T>, Error> {

            // ③ withTaskCancellationHandler：监听取消
            //    - 正常执行：执行 `try await withCheckedThrowingContinuation`
            //    - 取消时：执行 `onCancel` 闭包
            try await withTaskCancellationHandler {

                try await withCheckedThrowingContinuation { continuation in

                    // ④ 定义回调闭包
                    let completion: NetworkResponseCompletion<T> = { res, error in
                        if let error = error {
                            // 有错误 → throw
                            continuation.resume(throwing: error)
                        } else if let res = res {
                            // 成功 → 返回 ResponseData
                            continuation.resume(returning: res)
                        } else {
                            // 既无错误也无结果 → 抛自定义错误
                            let typeStr = String(describing: resType)
                            continuation.resume(throwing: NetworkError.custom("\(typeStr)对象序列化失败"))
                        }
                    }

                    // ⑤ 发起请求，响应回调
                    normalRequest.response(queue: queue) { response in
                        NetworkManager.shared.handleDataResponse(
                            response,
                            apiConvertable: request,
                            request: normalRequest,
                            file: file,
                            function: function,
                            line: line,
                            completion: completion
                        )
                    }
                }
            } onCancel: {
                // ⑥ 取消时：中断 Alamofire 请求
                normalRequest.cancel()
            }
        }

        // ⑦ 把 Alamofire 请求绑定到 Task（关联对象）
        //    这样 cancel() 时可以通过 task.afReq 拿到请求并取消
        task.afReq = normalRequest

        // ⑧ 包装成 AsyncRequest 返回
        return AsyncRequest(task: task)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 模块 2 续：Task 关联对象（绑定 Alamofire 请求）
// ═══════════════════════════════════════════════════════════════

/// 关联对象的 key（全局唯一地址）。
///
/// 用 `UInt8` 作为 key 的地址，配合 `objc_getAssociatedObject` / `objc_setAssociatedObject`
/// 把 `Alamofire.Request` 绑定到 `Task` 上。
private var alamofireRequestKey: UInt8 = 0

extension Task {

    /// 绑定的 Alamofire 请求。
    ///
    /// 为什么需要：
    /// - `Task` 本身只能取消 Task，无法直接取消 Alamofire 请求
    /// - 通过关联对象把 Alamofire 请求挂到 Task 上
    /// - `cancel()` 时能同时取消两者
    ///
    /// `OBJC_ASSOCIATION_RETAIN`：强引用，保证请求不被释放。
    var afReq: Alamofire.Request? {
        get {
            objc_getAssociatedObject(self, &alamofireRequestKey) as? Alamofire.Request
        }
        set {
            objc_setAssociatedObject(self, &alamofireRequestKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 模块 3：Combine 封装
// ═══════════════════════════════════════════════════════════════

extension NetworkManager {

    /// 把回调式请求转换成 Combine 的 `AnyPublisher`。
    ///
    /// 用法：
    /// ```swift
    /// NetworkManager.shared
    ///     .publisher(for: request, responseType: User.self)
    ///     .receive(on: DispatchQueue.main)
    ///     .sink(
    ///         receiveCompletion: { completion in
    ///             if case .failure(let error) = completion { ... }
    ///         },
    ///         receiveValue: { response in
    ///             print(response.model?.name)
    ///         }
    ///     )
    ///     .store(in: &cancellables)
    /// ```
    ///
    /// 内部实现：
    /// 1. 用 `Future` 包装回调式请求（Future 只能发一次事件，符合网络请求语义）
    /// 2. `promise(result)`：成功发 value，失败发 failure
    /// 3. `eraseToAnyPublisher()`：类型擦除，对外隐藏 Future 具体类型
    public func publisher<T: Codable>(
        for request: ApiConvertable,
        responseType: T.Type
    ) -> AnyPublisher<ResponseData<T>, NetworkError> {

        // ① Future：包装回调
        //    - promise(.success(value))：发成功事件
        //    - promise(.failure(error))：发失败事件
        Future { promise in
            // ② 调 sendAll（回调式）
            self.sendAll(request, resType: responseType) { result in
                // ③ 把 Result 转发给 promise
                promise(result)
            }
        }
        // ④ 类型擦除：Future<ResponseData<T>, NetworkError> → AnyPublisher<ResponseData<T>, NetworkError>
        .eraseToAnyPublisher()
    }
}
