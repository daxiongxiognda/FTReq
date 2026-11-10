//
//  NetworkManager+Request.swift
//  FTTool
//
//  Created by 熊坤鹏 on 2026/10/27.
//

import Alamofire
import FTTool

// ═══════════════════════════════════════════════════════════════
// MARK: - 类型别名
// ═══════════════════════════════════════════════════════════════

/// 下载进度回调。
///
/// - Parameter progress: 下载进度，0.0 ~ 1.0
///
/// 用法：
/// ```swift
/// NetworkManager.shared.download(request) { progress in
///     print("下载进度: \(progress * 100)%")
/// }
/// ```
public typealias NetworkingProgress = (_ progress: Double) -> Void

/// 原始响应回调。
///
/// - Parameters:
///   - response: 原始响应（statusCode / data / request / response），可能为 nil
///   - error: 网络错误，成功时为 nil
///
/// 用途：调用方自己处理响应，不做业务模型解析。
public typealias NetworkResponseClosure = (_ response: NetworkResponse?, _ error: NetworkError?) -> Void

/// 泛型响应回调（业务模型已解析成 ResponseData<T>）。
///
/// - Parameters:
///   - res: 解析后的 ResponseData<T>，失败时为 nil
///   - error: 网络错误，成功时为 nil
///
/// 泛型 T 是 `data` 字段的类型（如 User、[Order]、ResNil）。
public typealias NetworkResponseCompletion<T: Codable> = (_ res: ResponseData<T>?, _ error: NetworkError?) -> Void

// ═══════════════════════════════════════════════════════════════
// MARK: - NetworkManager 扩展：原始数据请求
// ═══════════════════════════════════════════════════════════════

extension NetworkManager {

    /// 发起请求，返回**原始** `NetworkResponse`（不解析业务模型）。
    ///
    /// 适用场景：
    /// - 调用方需要自己判断 HTTP 状态码（如 201、204）
    /// - 调用方需要自定义解析（如 protobuf、图片）
    /// - 调用方只需要原始 Data，不需要 ResponseData 包装
    ///
    /// 完整流程：
    /// 1. 显示 loading HUD
    /// 2. 把 `Any?` 参数包装成 `AnyEncodable`
    /// 3. 合并请求头（自定义 headers + 默认 headers + Cookie）
    /// 4. 发起请求 + validate（401 特殊处理）
    /// 5. 记录重试信息
    /// 6. 响应回来 → handleXNGResponse
    ///
    /// - Parameters:
    ///   - apiConvertable: 接口配置对象
    ///   - queue: 回调执行队列（默认主队列）
    ///   - file: 调用位置文件（编译期注入）
    ///   - function: 调用位置函数（编译期注入）
    ///   - line: 调用位置行号（编译期注入）
    ///   - completion: 响应回调
    /// - Returns: Alamofire 的 Request（可用于取消）
    @discardableResult
    public func normalDataRequest(
        apiConvertable: ApiConvertable,
        queue: DispatchQueue = .main,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line,
        completion: NetworkResponseClosure? = nil
    ) -> Alamofire.Request {

        // ───────── 第 1 步：显示 loading HUD ─────────
        // 如果 apiConvertable.hudConfig?.loading 有配置，会显示 loading
        checkShowHUD(apiConvertable: apiConvertable)

        // ───────── 第 2 步：参数转 Encodable ─────────
        // 为什么需要：Alamofire 5 的 request 要求参数是 Encodable
        // 但 apiConvertable.parameters 是 Any?，需要包装
        let encodableParameters: AnyEncodable? = {
            // 参数为 nil，直接返回 nil
            guard let parameters = apiConvertable.parameters else { return nil }

            // 如果已经是 Encodable，直接包装
            if let encodable = parameters as? Encodable {
                return AnyEncodable(encodable)
            }

            // 否则用 AnyEncodable 包装（如 [String: Any]）
            return AnyEncodable(parameters)
        }()

        // ───────── 第 3 步：合并请求头 ─────────
        // 优先级：defaultHeaders > headers（defaultHeaders 覆盖 headers）
        var headers = apiConvertable.headers
        if let defaultHeaders = apiConvertable.defaultHeaders, !defaultHeaders.isEmpty {
            // merging 的闭包 { $1 } 表示冲突时用新值（defaultHeaders）
            headers = headers.merging(defaultHeaders) { $1 }
        }

        // ───────── 第 4 步：加 Cookie ─────────
        // getCookies 会合并自定义 Cookie + 全局 Cookie（自定义优先）
        let cookies = getCookies(apiConvertable: apiConvertable)
        if !cookies.isEmpty {
            headers["Cookie"] = cookies
        }

        // ───────── 第 5 步：发起请求 ─────────
        let normalRequest = session.request(
            apiConvertable.requestUrlString,        // URL
            method: apiConvertable.method,          // HTTP 方法
            parameters: encodableParameters,        // 参数
            encoder: apiConvertable.encoder,        // 编码器（JSON / URL / DataBody）
            headers: HTTPHeaders(headers),          // 请求头
            interceptor: apiConvertable.authInterceptor,  // 拦截器（token 刷新、签名）
            requestModifier: { [weak self] request in
                // ───────── 第 6 步：修改请求 ─────────
                // 设置超时
                request.timeoutInterval = apiConvertable.timeout
                // 有 Cookie 时才让 URLSession 处理 Cookie
                request.httpShouldHandleCookies = !cookies.isEmpty
            }
        ).validate { _, response, data -> DataRequest.ValidationResult in
            // ───────── 第 7 步：自定义 validate ─────────
            // ① 没有响应数据，视为失败
            guard let _ = data else {
                return .failure(NSError(domain: apiConvertable.domain, code: 10089, userInfo: nil))
            }

            // ② HTTP 401（未授权），隐藏 HUD 并返回 token 错误
            if response.statusCode == 401 {
                self.checkHideHUD(
                    apiConvertable: apiConvertable,
                    err: NetworkError.tokenError("token失效"),
                    msg: "token失效"
                )
                return .failure(NSError(domain: apiConvertable.domain, code: 10088, userInfo: nil))
            }

            // ③ 其他情况视为成功
            return .success(Void())
        }

        // ───────── 第 8 步：记录重试信息 ─────────
        // 如果配置了重试次数，把请求加入 requestsAndRetryCounts
        if apiConvertable.defaultRetryCount > 0 {
            addRetryInfo(with: normalRequest)
        }

        // ───────── 第 9 步：响应回调 ─────────
        normalRequest.response(queue: dataQueue) { [weak self] response in
            // 弱引用 self，避免循环引用
            guard let strongSelf = self else { return }

            // ⑨-1：移出重试信息（请求完成，不再重试）
            if apiConvertable.defaultRetryCount > 0 {
                strongSelf.deleteRetryInfo(with: normalRequest)
            }

            // ⑨-2：交给 handleXNGResponse 处理
            strongSelf.handleXNGResponse(
                apiConvertable: apiConvertable,
                dataResponse: response,
                queue: queue,
                reqUUID: normalRequest.id,
                file: file,
                function: function,
                line: line,
                completion: completion
            )
        }
        return normalRequest
    }

    /// 处理原始响应（不解析业务模型）。
    ///
    /// 核心流程：
    /// 1. 判断网络错误 / 提取响应数据
    /// 2. 从响应 JSON 里提取 code / message
    /// 3. 校验 code（validateServerCodeResult）
    /// 4. 上报异常
    /// 5. 隐藏 HUD + 回调
    /// 6. 输出日志
    ///
    /// - Parameters:
    ///   - apiConvertable: 接口配置
    ///   - dataResponse: Alamofire 的原始响应
    ///   - queue: 回调队列
    ///   - reqUUID: 请求 id（用于取耗时）
    ///   - file/function/line: 调用位置
    ///   - completion: 响应回调
    func handleXNGResponse(
        apiConvertable: ApiConvertable,
        dataResponse: AFDataResponse<Data?>,
        queue: DispatchQueue = .main,
        reqUUID: UUID,
        file: StaticString,
        function: StaticString,
        line: UInt,
        completion: NetworkResponseClosure? = nil
    ) {
        // ① 声明待填充的变量
        var networkError: NetworkError?          // 网络错误
        var response: NetworkResponse! = nil     // 原始响应
        var validateCodeResult = ServerCodeValidateResult.failed   // code 校验结果
        var serviceCode: Int?                    // 业务码
        var msg = ""                             // 业务消息

        if let err = dataResponse.error {
            // ───────── 情况 A：有网络错误 ─────────
            networkError = handleResponseError(err: err)
        } else {
            // ───────── 情况 B：有响应数据 ─────────
            if let responseData = dataResponse.data,
               let tempResponse = dataResponse.response,
               let tempRequest = dataResponse.request {
                // ② 构造 NetworkResponse
                response = NetworkResponse(
                    statusCode: tempResponse.statusCode,
                    data: responseData,
                    request: tempRequest,
                    response: tempResponse
                )

                // ③ 从 JSON 里提取 code / message
                let responseDict = try? response?.mapJSON() as? [String: Any]
                let ret = responseDict?["code"] as? Int ?? 2009
                serviceCode = ret
                msg = responseDict?["message"] as? String ?? ""

                // ④ 校验业务码
                validateCodeResult = apiConvertable.validateServerCodeResult(code: ret)
                if validateCodeResult != .successed {
                    networkError = NetworkError.serverError(msg, ret)
                }
            } else {
                // 响应数据不全（缺 data / response / request）
                networkError = NetworkError.serverError("服务器错误，响应数据有误", 2009)
            }
        }

        // ⑤ 上报异常（如果配置了上报器）
        

        // ⑥ 隐藏 HUD + 回调
        checkHideHUD(apiConvertable: apiConvertable, err: networkError, msg: msg, completion: {
            // 切到调用方指定的队列（默认主队列）
            queue.async { completion?(response, networkError) }
        })

        // ⑦ 输出日志
        let statusCode = dataResponse.response?.statusCode ?? -1
        let reqHeaders = dataResponse.request?.allHTTPHeaderFields
        let resHeaders = dataResponse.response?.allHeaderFields
        if let tempResponse = response {
            // 成功日志
            apiConvertable.resSuccessLog(
                reqUUID: reqUUID,
                statuCode: statusCode,
                method: apiConvertable.method.rawValue,
                resData: tempResponse.data,
                reqHeaders: reqHeaders,
                resHeaders: resHeaders,
                file: file,
                function: function,
                line: line
            )
        } else {
            // 失败日志
            apiConvertable.resFailedLog(
                reqUUID: reqUUID,
                statuCode: statusCode,
                method: apiConvertable.method.rawValue,
                resData: nil,
                error: networkError,
                reqHeaders: reqHeaders,
                resHeaders: resHeaders,
                file: file,
                function: function,
                line: line
            )
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - NetworkManager 扩展：send / sendAll
// ═══════════════════════════════════════════════════════════════

extension NetworkManager {

    /// 发请求，成功时**只返回 `data` 部分**（`T`）。
    ///
    /// 适用场景：调用方只关心业务数据，不关心 code / msg。
    ///
    /// 用法：
    /// ```swift
    /// NetworkManager.shared.send(request, resType: User.self) { result in
    ///     switch result {
    ///     case .success(let user): print(user.name)
    ///     case .failure(let error): print(error)
    ///     }
    /// }
    /// ```
    @discardableResult
    public func send<T: Codable>(
        _ request: ApiConvertable,
        resType: T.Type,
        queue: DispatchQueue = .main,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line,
        completion: ((Result<T, NetworkError>) -> Void)? = nil
    ) -> Alamofire.Request {

        // ① 调 normalRequest（拿到 ResponseData<T>）
        let request = normalRequest(
            apiConvertable: request,
            resType: resType,
            queue: queue,
            file: file,
            function: function,
            line: line
        ) { res, error in
            if let tempError = error {
                // ② 有错误 → failure
                completion?(.failure(tempError))
            } else if let model = res?.model {
                // ③ 有数据 → success(model)
                completion?(.success(model))
            } else if resType == ResNil.self {
                // ④ 空数据类型（ResNil）→ 返回空 ResNil
                completion?(.success(ResNil() as! T))
            } else {
                // ⑤ 其他情况 → 序列化失败
                let typeStr = String(describing: resType)
                completion?(.failure(NetworkError.custom("\(typeStr)对象序列化失败")))
            }
        }
        return request
    }

    /// 发请求，成功时返回**完整 `ResponseData<T>`**（code / msg / data）。
    ///
    /// 适用场景：调用方需要 code / msg（如分页的 total / position）。
    @discardableResult
    public func sendAll<T: Codable>(
        _ request: ApiConvertable,
        resType: T.Type,
        queue: DispatchQueue = .main,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line,
        completion: ((Result<ResponseData<T>, NetworkError>) -> Void)? = nil
    ) -> Alamofire.Request {
        let request = normalRequest(
            apiConvertable: request,
            resType: resType,
            queue: queue,
            file: file,
            function: function,
            line: line
        ) { res, error in
            if let tempError = error {
                // 有错误 → failure
                completion?(.failure(tempError))
            } else if let tempRes = res {
                // 有响应 → success(ResponseData)
                completion?(.success(tempRes))
            } else {
                // 响应为 nil → 序列化失败
                let typeStr = String(describing: resType)
                completion?(.failure(NetworkError.custom("\(typeStr)对象序列化失败")))
            }
        }
        return request
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - normalRequest（核心请求入口）
    // ═══════════════════════════════════════════════════════════

    /// 普通网络请求（核心入口，解码 ResponseData<T>）。
    ///
    /// 流程：
    /// 1. createNormalRequest 创建请求
    /// 2. 响应回调 handleDataResponse
    @discardableResult
    public func normalRequest<T: Codable>(
        apiConvertable: ApiConvertable,
        resType: T.Type,
        queue: DispatchQueue = .main,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line,
        completion: NetworkResponseCompletion<T>? = nil
    ) -> Alamofire.Request {
        // ① 创建请求（显示 HUD、合并 headers、加 Cookie、validate、加入重试）
        let normalRequest = createNormalRequest(apiConvertable: apiConvertable)

        // ② 响应处理
        normalRequest.response(queue: dataQueue) { response in
            self.handleDataResponse(
                response,
                apiConvertable: apiConvertable,
                request: normalRequest,
                queue: queue,
                file: file,
                function: function,
                line: line,
                completion: completion
            )
        }
        return normalRequest
    }

    /// 创建 DataRequest（合并 headers、加 Cookie、validate、加入重试）。
    func createNormalRequest(apiConvertable: ApiConvertable) -> DataRequest {
        // ① 显示 loading HUD
        checkShowHUD(apiConvertable: apiConvertable)

        // ② 合并 headers（defaultHeaders 优先）
        var headers = apiConvertable.headers
        if let defaultHeaders = apiConvertable.defaultHeaders, !defaultHeaders.isEmpty {
            headers = headers.merging(defaultHeaders) { $1 }
        }

        // ③ 加 Cookie
        let cookies = getCookies(apiConvertable: apiConvertable)
        if !cookies.isEmpty {
            headers["Cookie"] = cookies
        }

        // ④ 参数编码 + 发起请求
        var normalRequest: DataRequest
        if let dataParam = apiConvertable.parameters as? Encodable {
            // 参数已经是 Encodable，直接传
            normalRequest = session.request(
                apiConvertable.requestUrlString,
                method: apiConvertable.method,
                parameters: dataParam,
                encoder: apiConvertable.encoder,
                headers: HTTPHeaders(headers),
                interceptor: apiConvertable.authInterceptor,
                requestModifier: { request in
                    request.timeoutInterval = apiConvertable.timeout
                    request.httpShouldHandleCookies = !cookies.isEmpty
                }
            )
        } else {
            // 参数不是 Encodable（如 [String: Any]），用 AnyEncodable 包装
            var encodableParam: AnyEncodable?
            if let tempParam = apiConvertable.parameters {
                encodableParam = AnyEncodable(tempParam)
            }
            normalRequest = session.request(
                apiConvertable.requestUrlString,
                method: apiConvertable.method,
                parameters: encodableParam,
                encoder: apiConvertable.encoder,
                headers: HTTPHeaders(headers),
                interceptor: apiConvertable.authInterceptor,
                requestModifier: { request in
                    request.timeoutInterval = apiConvertable.timeout
                    request.httpShouldHandleCookies = !cookies.isEmpty
                }
            )
        }

        // ⑤ validate（当前是空实现，401 处理被注释掉了）
        normalRequest.validate { _, response, data -> DataRequest.ValidationResult in
            /* 401 处理被注释掉了，当前全部视为成功 */
            return .success(Void())
        }

        // ⑥ 加入重试
        if apiConvertable.defaultRetryCount > 0 {
            addRetryInfo(with: normalRequest)
        }
        return normalRequest
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - pauseAd 特殊处理
    // ═══════════════════════════════════════════════════════════

    /// 处理 pauseAd 接口的**特殊响应格式**。
    ///
    /// 正常格式：`{ code, msg, data: { ... } }`
    /// pauseAd 格式：`{ items: { type, adData: { adId } } }`（没有 code/data 外壳）
    ///
    /// 这个方法把 pauseAd 的特殊格式转成标准格式：
    /// - 检测响应里没有 `code` 字段
    /// - 有 `items.adData.adId` 字段
    /// - 用 `JSONDecoder` 解码 `T`
    private func pauseAdRootPayload<T: Codable>(from data: Data, as type: T.Type) -> T? {
        // ① 解析 JSON
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["code"] == nil,                          // 没有 code 字段
              let items = object["items"] as? [String: Any],
              let adData = items["adData"] as? [String: Any] else {
            return nil
        }

        // ② 提取 adId（可能是 String 或 NSNumber）
        let adId: String
        if let text = adData["adId"] as? String {
            adId = text
        } else if let number = adData["adId"] as? NSNumber {
            adId = number.stringValue
        } else {
            return nil
        }

        // ③ adId 非空
        guard !adId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        // ④ 解码 T
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - handleDataResponse（核心响应处理）
    // ═══════════════════════════════════════════════════════════

    /// 处理 DataResponse：解码 ResponseData<T>、校验 code、处理 token 刷新、上报异常、回调。
    ///
    /// 完整流程：
    /// 1. 移出重试信息
    /// 2. 判断网络错误 / 解码 ResponseData<T>
    /// 3. pauseAd 特殊处理
    /// 4. checkLogout（token 失效业务码）
    /// 5. validateServerCodeResult（校验业务码）
    /// 6. token 过期 → handleTokenExpired（刷新 + 重放）
    /// 7. 业务错误 → serverError
    /// 8. 上报异常
    /// 9. 隐藏 HUD + 回调
    /// 10. 输出日志
    func handleDataResponse<T: Codable>(
        _ dataResponse: AFDataResponse<Data?>,
        apiConvertable: ApiConvertable,
        request: Alamofire.Request,
        queue: DispatchQueue = .main,
        file: StaticString,
        function: StaticString,
        line: UInt,
        completion: NetworkResponseCompletion<T>? = nil
    ) {
        // ① 移出重试信息
        if apiConvertable.defaultRetryCount > 0 {
            self.deleteRetryInfo(with: request)
        }

        var networkError: NetworkError?
        var responseModel: ResponseData<T>! = nil
        let statuCode = dataResponse.response?.statusCode ?? -1
        var serviceCode: Int?
        var msg = ""

        if let err = dataResponse.error {
            // ───────── 情况 A：网络错误 ─────────
            networkError = handleResponseError(err: err)
        } else {
            if let responseData = dataResponse.data {
                do {
                    // ───────── 情况 B：解码 ResponseData<T> ─────────
                    responseModel = try JSONDecoder().decode(ResponseData<T>.self, from: responseData)

                    // ② pauseAd 特殊处理
                    if responseModel.model == nil,
                       apiConvertable.path.contains("ugcData/pauseAd"),
                       let payload = pauseAdRootPayload(from: responseData, as: T.self) {
                        responseModel.code = 0        // 补默认 code
                        responseModel.model = payload // 补数据
                    }

                    serviceCode = responseModel.code

                    // ③ 检测是否需要登出（token 失效业务码）
                    let needLogout = self.checkLogout(
                        statusCode: statuCode,
                        serviceCode: responseModel.code,
                        msg: responseModel.msg
                    )
                    if needLogout { return }

                    // ④ 校验业务码
                    let checkResult = apiConvertable.validateServerCodeResult(code: responseModel.code)
                    if checkResult == .successed {
                        // 成功
                        msg = responseModel.msg
                    } else {
                        // ⑤ token 过期 → 刷新 + 重放
                        if checkResult == .refreshToken {
                            handleTokenExpired(
                                apiConvertable: apiConvertable,
                                file: file,
                                function: function,
                                line: line,
                                completion: completion
                            )
                            // 主线程隐藏 HUD
                            DispatchQueue.main.async {
                                apiConvertable.hideHUD(success: false)
                            }
                            return
                        }

                        // ⑥ 其他业务错误
                        msg = serverErrorCodeMessage(code: responseModel.code, serverMsg: responseModel.msg)
                        networkError = NetworkError.serverError(msg, responseModel.code)
                        responseModel = nil   // 清空，表示失败
                    }
                } catch let err {
                    // ⑦ 解码失败
                    let dataStr = String(data: responseData, encoding: .utf8) ?? ""
                    let desc = "JSON Decode error: \(err.localizedDescription)\n\(dataStr)"
                    networkError = NetworkError.decodeError(err, desc)
                }
            } else {
                // ⑧ 没有响应数据
                networkError = NetworkError.serverError("服务器错误，data字段为nil", 2009)
            }
        }

        // ⑨ 上报异常
        

        // ⑩ 隐藏 HUD + 回调
        checkHideHUD(
            apiConvertable: apiConvertable,
            err: networkError,
            msg: msg,
            tipLevel: responseModel?.tipLevel ?? .toast,
            completion: {
                // 切到调用方队列
                queue.async { completion?(responseModel, networkError) }
            }
        )

        // ⑪ 输出日志
        let reqHeaders = dataResponse.request?.allHTTPHeaderFields
        let resHeaders = dataResponse.response?.allHeaderFields
        if responseModel != nil {
            // 成功日志
            apiConvertable.resSuccessLog(
                reqUUID: request.id,
                statuCode: statuCode,
                method: apiConvertable.method.rawValue,
                resData: dataResponse.data,
                reqHeaders: reqHeaders,
                resHeaders: resHeaders,
                file: file,
                function: function,
                line: line
            )
        } else {
            // 失败日志
            apiConvertable.resFailedLog(
                reqUUID: request.id,
                statuCode: statuCode,
                method: apiConvertable.method.rawValue,
                resData: dataResponse.data,
                error: networkError,
                reqHeaders: reqHeaders,
                resHeaders: resHeaders,
                file: file,
                function: function,
                line: line
            )
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 错误处理
    // ═══════════════════════════════════════════════════════════

    /// 把 AFError / URLError / NSError 映射到 NetworkError。
    private func handleResponseError(err: Error) -> NetworkError {
        var networkError: NetworkError

        if networkStatu == .none {
            // ① 无网络（全局网络状态是 none）
            networkError = NetworkError.noNetwork
        } else if let aferr = err as? AFError {
            // ② AFError
            switch aferr {
            case .sessionTaskFailed(let error):
                // ②-1 底层 URLSession 任务失败，解包 NSError
                if let nserror = error as? NSError {
                    switch nserror.code {
                    case URLError.notConnectedToInternet.rawValue:
                        networkError = NetworkError.noNetwork
                    case URLError.timedOut.rawValue:
                        networkError = NetworkError.networkTimeout
                    default:
                        networkError = NetworkError.responseError(error)
                    }
                } else {
                    networkError = NetworkError.responseError(error)
                }
            default:
                // ②-2 其他 AFError
                networkError = NetworkError.responseError(aferr)
            }
        } else {
            // ③ NSError
            let nserr = err as NSError
            if nserr.code == NSURLErrorNotConnectedToInternet {
                networkError = NetworkError.noNetwork
            } else if nserr.code == NSURLErrorTimedOut {
                networkError = NetworkError.networkTimeout
            } else {
                networkError = NetworkError.responseError(nserr)
            }
        }
        return networkError
    }

    /// 服务端错误码转文案（服务端消息优先，否则从 Bundle 读）。
    private func serverErrorCodeMessage(code: Int, serverMsg: String) -> String {
        // ① 服务端有消息，直接用
        if !serverMsg.isEmpty { return serverMsg }

        // ② 从 Localizable.strings 里按 code 读文案
        let errCodeMsg = NetworkError.errorMessage(code: code)
        return errCodeMsg
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - NetworkManager 扩展：token 过期刷新
// ═══════════════════════════════════════════════════════════════

extension NetworkManager {

    /// 处理 token 过期：加入重试队列 + 触发刷新。
    ///
    /// 完整流程：
    /// 1. 把当前请求加入重试队列
    /// 2. 如果没在刷新，触发刷新
    /// 3. 刷新成功后，重放重试队列
    /// 4. 刷新失败，丢弃队列
    private func handleTokenExpired<T: Codable>(
        apiConvertable: ApiConvertable,
        queue: DispatchQueue = .main,
        file: StaticString,
        function: StaticString,
        line: UInt,
        completion: NetworkResponseCompletion<T>? = nil
    ) {
        // ① 加入重试队列（刷新成功后重放）
        addToRetryQueue(
            apiConvertable: apiConvertable,
            queue: queue,
            file: file,
            function: function,
            line: line,
            completion: completion
        )

        // ② 已在刷新，直接返回（避免并发刷新）
        guard !isRefreshingToken else { return }
        isRefreshingToken = true

        // ③ 触发刷新
        tokenRefresher?.didReceiveTokenRefreshRequired(completion: { [weak self] err in
            guard let strongSelf = self else { return }

            // ④ 重置刷新状态
            strongSelf.isRefreshingToken = false

            // ⑤ 取队列快照，清空原队列
            let queueCopy = strongSelf.retryQueue
            strongSelf.retryQueue.removeAll()

            // ⑥ 刷新失败，不重放
            guard err == nil else { return }

            // ⑦ 刷新成功，重放所有等待的请求
            queueCopy.forEach { $0() }
        })
    }

    /// 把请求加入重试队列（刷新成功后重放）。
    private func addToRetryQueue<T>(
        apiConvertable: ApiConvertable,
        queue: DispatchQueue = .main,
        file: StaticString,
        function: StaticString,
        line: UInt,
        completion: NetworkResponseCompletion<T>? = nil
    ) {
        // ① 把"重放逻辑"作为闭包加入队列
        retryQueue.append { [weak self] in
            guard let self = self else { return }

            // ② 重新创建请求
            let normalRequest = self.createNormalRequest(apiConvertable: apiConvertable)

            // ③ 重新发起请求
            normalRequest.response(queue: self.dataQueue) { response in
                self.handleDataResponse(
                    response,
                    apiConvertable: apiConvertable,
                    request: normalRequest,
                    queue: queue,
                    file: file,
                    function: function,
                    line: line,
                    completion: completion
                )
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - CMSBaseProtocol（CMS 业务模型基础协议）
// ═══════════════════════════════════════════════════════════════

/// CMS 业务响应基础协议。
///
/// 所有 CMS 业务模型必须遵循，统一以下字段：
/// - `isSuccess`：请求状态（Y=成功，N=失败）
/// - `traceId`：追踪 ID
/// - `serverTime`：服务器时间
/// - `dataSource`：数据源
/// - `failReason`：失败原因
public protocol CMSBaseProtocol: Codable {
    /// 请求状态（Y=成功，N=失败）。
    var isSuccess: String { get }

    /// 追踪 ID（用于排查问题）。
    var traceId: String { get }

    /// 服务器时间。
    var serverTime: String { get }

    /// 数据源（如 ttcms）。
    var dataSource: String { get }

    /// 失败原因（失败时返回）。
    var failReason: String? { get }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - NetworkManager 扩展：CMS 请求
// ═══════════════════════════════════════════════════════════════

extension NetworkManager {

    /// CMS 请求回调类型。
    public typealias CommonRequestCompletion<T: CMSBaseProtocol> = ((Result<T, NetworkError>) -> Void)?

    /// CMS 通用请求入口（所有 CMS 业务统一调用）。
    ///
    /// 与普通请求的区别：
    /// - 直接用 `AF.request`（不走 NetworkManager.session）
    /// - 用 `isSuccess == "Y"` 判断成功，不是 `code == 0`
    /// - 用 `JSONEncoding.default` 编码参数
    @discardableResult
    public func sendCommonRequestForCMS<T: CMSBaseProtocol>(
        _ request: ApiConvertable,
        resType: T.Type,
        queue: DispatchQueue = .main,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line,
        completion: CommonRequestCompletion<T>? = nil
    ) -> Alamofire.DataRequest {
        // ① 创建 CMS 请求
        let normalRequest = cmsCreateNormalRequest(apiConvertable: request)

        // ② 响应处理
        normalRequest.responseData(queue: dataQueue) { [weak self] (response: AFDataResponse<Data>) in
            guard let self = self else { return }
            self.cmsHandleCommonResponse(
                response,
                apiConvertable: request,
                alamofireRequest: normalRequest,
                resType: resType,
                queue: queue,
                file: file,
                function: function,
                line: line,
                completion: completion
            )
        }

        // ③ 加入重试
        if request.defaultRetryCount > 0 {
            addRetryInfo(with: normalRequest)
        }
        return normalRequest
    }

    /// 创建 CMS 请求（用 AF.request 全局单例，不走 session）。
    private func cmsCreateNormalRequest(apiConvertable: ApiConvertable) -> Alamofire.DataRequest {
        // ① 拼 URL
        let url = apiConvertable.baseURL + apiConvertable.path
        let method = apiConvertable.method
        let timeout = apiConvertable.timeout
        let parameters: Parameters? = apiConvertable.parameters as? Parameters

        // ② 合并 headers + Cookie
        var headersDict = apiConvertable.headers
        if apiConvertable.useGlobalCookie, let cookies = apiConvertable.cookies {
            headersDict.merge(cookies) { $1 }
        }
        let headers = HTTPHeaders(headersDict)

        // ③ 用 AF.request（全局单例，不走 NetworkManager.session）
        return AF.request(
            url,
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers,
            requestModifier: { $0.timeoutInterval = timeout }
        )
    }

    /// 处理 CMS 响应。
    private func cmsHandleCommonResponse<T: CMSBaseProtocol>(
        _ dataResponse: AFDataResponse<Data>,
        apiConvertable: ApiConvertable,
        alamofireRequest: Alamofire.DataRequest,
        resType: T.Type,
        queue: DispatchQueue,
        file: StaticString,
        function: StaticString,
        line: UInt,
        completion: CommonRequestCompletion<T>?
    ) {
        // ① 移出重试
        if apiConvertable.defaultRetryCount > 0 {
            deleteRetryInfo(with: alamofireRequest)
        }

        var networkError: NetworkError?
        var responseModel: T? = nil
        let statuCode = dataResponse.response?.statusCode ?? -1
        let requestId = alamofireRequest.id
        var msg = ""

        if let err = dataResponse.error {
            // ───────── 情况 A：网络错误 ─────────
            networkError = handleResponseError(err: err)
        } else {
            guard let responseData = dataResponse.data else {
                networkError = NetworkError.serverError("服务器返回数据为空", 2009)
                return
            }

            do {
                // ───────── 情况 B：解码 T（CMS 模型） ─────────
                responseModel = try JSONDecoder().decode(T.self, from: responseData)

                // ② 校验 isSuccess
                let checkResult = apiConvertable.validateServerWithCMSCodeResult(isSuccess: responseModel?.isSuccess ?? "N")
                if checkResult != .successed {
                    // 业务失败
                    let errorMsg = responseModel?.failReason ?? "业务处理失败"
                    networkError = NetworkError.serverError(errorMsg, -1000)
                    msg = errorMsg
                    responseModel = nil
                }
            } catch let decodeErr {
                // ③ 解码失败
                let dataStr = String(data: responseData, encoding: .utf8) ?? "无原始数据"
                let errorDesc = "错误信息：\(decodeErr.localizedDescription)，原始数据：\(dataStr)"
                networkError = NetworkError.decodeError(decodeErr, errorDesc)
            }
        }

        // ④ 没有回调：只隐藏 HUD
        guard let rawCompletion = completion else {
            checkHideHUD(apiConvertable: apiConvertable, err: networkError) {}
            return
        }

        let finishCompletion: (Result<T, NetworkError>) -> Void = rawCompletion!

        // ⑤ 隐藏 HUD + 回调
        checkHideHUD(
            apiConvertable: apiConvertable,
            err: networkError,
            msg: msg,
            tipLevel: .toast,
            completion: {
                queue.async(execute: {
                    if let error = networkError {
                        finishCompletion(.failure(error))
                    } else if let model = responseModel {
                        finishCompletion(.success(model))
                    } else {
                        finishCompletion(.failure(NetworkError.custom("响应模型为空")))
                    }
                })
            }
        )

        // ⑥ 输出日志
        let reqHeaders = dataResponse.request?.allHTTPHeaderFields
        let resHeaders = dataResponse.response?.allHeaderFields
        if responseModel != nil {
            // 成功日志
            apiConvertable.resSuccessLog(
                reqUUID: requestId,
                statuCode: statuCode,
                method: apiConvertable.method.rawValue,
                resData: dataResponse.data,
                reqHeaders: reqHeaders,
                resHeaders: resHeaders,
                file: file,
                function: function,
                line: line
            )
        } else {
            // 失败日志
            apiConvertable.resFailedLog(
                reqUUID: requestId,
                statuCode: statuCode,
                method: apiConvertable.method.rawValue,
                resData: dataResponse.data,
                error: networkError,
                reqHeaders: reqHeaders,
                resHeaders: resHeaders,
                file: file,
                function: function,
                line: line
            )
        }
    }
}
