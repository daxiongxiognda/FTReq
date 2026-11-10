//
//  NetworkMnager+RXRequest.swift
//  FTTool
//
//  Created by 熊坤鹏 on 2026/10/27.
//

import RxSwift
import Alamofire

// ═══════════════════════════════════════════════════════════════
// MARK: - Reactive 扩展声明（让 NetworkManager 支持 .rx 命名空间）
// ═══════════════════════════════════════════════════════════════

/// 让 NetworkManager 遵循 ReactiveCompatible 协议。
///
/// 作用：有了这行，就能用 `NetworkManager.shared.rx.send(...)` 这种语法。
///
/// 原理：
/// - `ReactiveCompatible` 是 RxSwift 提供的协议
/// - 遵循后，类型自动获得 `rx` 属性（返回 `Reactive<Self>`）
/// - `Reactive<Base>` 是泛型包装器，用于给原类型扩展响应式 API
///
/// 对比直接扩展 NetworkManager：
/// ```swift
/// // ❌ 直接扩展：污染 NetworkManager 的命名空间
/// extension NetworkManager {
///     func rxSend(...) -> Observable<T> { ... }
/// }
///
/// // ✅ Reactive 扩展：所有响应式 API 收敛到 .rx 下
/// extension Reactive where Base: NetworkManager {
///     func send(...) -> Observable<T> { ... }
/// }
/// ```
extension NetworkManager: ReactiveCompatible { }

// ═══════════════════════════════════════════════════════════════
// MARK: - Reactive 扩展（给 .rx 命名空间添加网络请求 API）
// ═══════════════════════════════════════════════════════════════

extension Reactive where Base: NetworkManager {

    // ═══════════════════════════════════════════════════════════
    // MARK: - send（泛型，同时支持 NetworkResponse 和 ResponseData）
    // ═══════════════════════════════════════════════════════════

    /// 发请求，返回 `Observable<T>`。
    ///
    /// 特点：**一个方法同时支持两种响应类型**——
    /// - 如果 `T == NetworkResponse`：返回原始响应（不走业务解析）
    /// - 其他 `T`：返回业务模型（走 ResponseData<T> 解析）
    ///
    /// 用法：
    /// ```swift
    /// // 拿业务模型
    /// NetworkManager.shared.rx
    ///     .send(apiModel: loginRequest)
    ///     .subscribe(onNext: { (user: User) in ... })
    ///     .disposed(by: bag)
    ///
    /// // 拿原始响应
    /// NetworkManager.shared.rx
    ///     .send(apiModel: loginRequest)
    ///     .subscribe(onNext: { (res: NetworkResponse) in ... })
    ///     .disposed(by: bag)
    /// ```
    ///
    /// - Parameters:
    ///   - apiModel: 接口配置对象
    ///   - file/function/line: 调用位置（编译期注入，用于日志）
    /// - Returns: Observable<T>
    public func send<R: ApiConvertable, T: Codable>(
        apiModel: R,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) -> Observable<T> {

        // ① Observable.create：手动创建 Observable
        //    - observer：观察者，通过 onNext / onError / onCompleted 发事件
        //    - 返回 Disposable：订阅取消时执行清理（这里取消网络请求）
        return Observable<T>.create { observer -> Disposable in

            // ② 声明请求变量（分支里赋值）
            var request: Alamofire.Request

            // ③ 分支判断：T 是否是 NetworkResponse
            if T.self == NetworkResponse.self {

                // ───────── 分支 A：T == NetworkResponse，走原始响应 ─────────
                // 用 normalDataRequest（返回原始 NetworkResponse）
                request = NetworkManager.shared.normalDataRequest(
                    apiConvertable: apiModel,
                    queue: DispatchQueue.global(),   // 回调切全局队列（Rx 层会再切主线程）
                    file: file,
                    function: function,
                    line: line
                ) { response, error in
                    if let tempResponse = response {
                        // A-1：有响应 → onNext + onCompleted
                        // ⚠️ 这里用 as! 强制转换，因为已经判断了 T.self == NetworkResponse.self
                        observer.onNext(tempResponse as! T)
                        observer.onCompleted()
                    } else if let tempError = error {
                        // A-2：有错误 → onError
                        observer.onError(tempError)
                    } else {
                        // A-3：既无响应也无错误 → 自定义错误
                        let typeStr = String(describing: T.self)
                        observer.onError(NetworkError.custom("\(typeStr)对象序列化失败"))
                    }
                }
            } else {

                // ───────── 分支 B：T != NetworkResponse，走业务模型 ─────────
                // 用 normalRequest（返回 ResponseData<T>）
                request = NetworkManager.shared.normalRequest(
                    apiConvertable: apiModel,
                    resType: T.self,
                    queue: DispatchQueue.global(),
                    file: file,
                    function: function,
                    line: line
                ) { respModel, error in
                    if let tempError = error {
                        // B-1：有错误 → onError
                        observer.onError(tempError)
                    } else if let model = respModel?.model {
                        // B-2：有模型 → onNext + onCompleted
                        observer.onNext(model)
                        observer.onCompleted()
                    } else {
                        // B-3：无模型 → 自定义错误
                        let typeStr = String(describing: T.self)
                        observer.onError(NetworkError.custom("\(typeStr)对象序列化失败"))
                    }
                }
            }

            // ④ 返回 Disposable：订阅取消时取消网络请求
            //    这样 `dispose()` 或 `disposed(by: bag)` 时会中断请求
            return Disposables.create { request.cancel() }
        }
        // ⑤ 切主线程：所有事件（onNext / onError / onCompleted）在主线程发出
        //    方便调用方直接更新 UI
        .observe(on: MainScheduler.instance)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - sendAll（返回完整 ResponseData<T>）
    // ═══════════════════════════════════════════════════════════

    /// 发请求，返回 `Observable<ResponseData<T>>`（含 code / msg / data）。
    ///
    /// 和 `send` 的区别：
    /// - `send`：只返回 data 部分（T）
    /// - `sendAll`：返回完整 ResponseData（含分页字段 total / position）
    ///
    /// 用法：
    /// ```swift
    /// NetworkManager.shared.rx
    ///     .sendAll(apiModel: listRequest)
    ///     .subscribe(onNext: { (res: ResponseData<[User]>) in
    ///         print("总数: \(res.total), 数据: \(res.model ?? [])")
    ///     })
    ///     .disposed(by: bag)
    /// ```
    public func sendAll<R: ApiConvertable, T: Codable>(
        apiModel: R,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) -> Observable<ResponseData<T>> {

        // ① 创建 Observable
        return Observable<ResponseData<T>>.create { observer -> Disposable in

            // ② 调 normalRequest（返回 ResponseData<T>）
            let request: Alamofire.Request = NetworkManager.shared.normalRequest(
                apiConvertable: apiModel,
                resType: T.self,
                queue: DispatchQueue.global(),
                file: file,
                function: function,
                line: line
            ) { respModel, error in
                if let tempError = error {
                    // ③ 有错误 → onError
                    observer.onError(tempError)
                } else if let model = respModel {
                    // ④ 有完整 ResponseData → onNext + onCompleted
                    observer.onNext(model)
                    observer.onCompleted()
                } else {
                    // ⑤ 无响应 → 自定义错误
                    let typeStr = String(describing: T.self)
                    observer.onError(NetworkError.custom("\(typeStr)对象序列化失败"))
                }
            }

            // ⑥ 订阅取消时取消请求
            return Disposables.create { request.cancel() }
        }
        // ⑦ 切主线程
        .observe(on: MainScheduler.instance)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - requestXNGResponse（只返回原始 NetworkResponse）
    // ═══════════════════════════════════════════════════════════

    /// 发请求，返回 `Observable<NetworkResponse>`（原始响应）。
    ///
    /// 适用场景：
    /// - 需要 HTTP 状态码
    /// - 需要自定义解析（如 protobuf、图片）
    /// - 需要响应头
    ///
    /// 用法：
    /// ```swift
    /// NetworkManager.shared.rx
    ///     .requestXNGResponse(apiModel: downloadRequest)
    ///     .subscribe(onNext: { res in
    ///         print("状态码: \(res.statusCode)")
    ///         print("数据: \(res.data)")
    ///     })
    ///     .disposed(by: bag)
    /// ```
    public func requestXNGResponse(apiModel: ApiConvertable) -> Observable<NetworkResponse> {

        // ① 创建 Observable
        return Observable.create { observer -> Disposable in

            // ② 调 normalDataRequest（返回原始 NetworkResponse）
            let request = NetworkManager.shared.normalDataRequest(
                apiConvertable: apiModel
            ) { response, error in
                if let tempResponse = response {
                    // ③ 有响应 → onNext + onCompleted
                    observer.onNext(tempResponse)
                    observer.onCompleted()
                } else {
                    // ④ 无响应 → onError（优先用 error，否则自定义）
                    observer.onError(error ?? NetworkError.custom("NetworkResponse对象序列化失败"))
                }
            }

            // ⑤ 订阅取消时取消请求
            return Disposables.create { request.cancel() }
        }
        // ⑥ 切主线程
        .observe(on: MainScheduler.instance)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - ObservableType 扩展（NetworkResponse 的 map 操作）
// ═══════════════════════════════════════════════════════════════

extension ObservableType where Element == NetworkResponse {

    // ═══════════════════════════════════════════════════════════
    // MARK: - mapJSON（转 JSON 对象）
    // ═══════════════════════════════════════════════════════════

    /// 把 NetworkResponse 的 data 转成 JSON 对象（字典 / 数组）。
    ///
    /// 用法：
    /// ```swift
    /// NetworkManager.shared.rx
    ///     .requestXNGResponse(apiModel: request)
    ///     .mapJSON()
    ///     .subscribe(onNext: { json in
    ///         print(json)   // ["name": "Tom", "age": 18]
    ///     })
    /// ```
    ///
    /// - Parameter failsOnEmptyData: 数据为空时是否失败
    /// - Returns: Observable<Any>
    public func mapJSON(failsOnEmptyData: Bool = true) -> Observable<Any> {

        // ① flatMap：把每个 NetworkResponse 转成新的 Observable
        // ② Observable.just：包装结果
        // ③ try $0.mapJSON(...)：调 NetworkResponse 的 mapJSON（可能抛错）
        //    ⚠️ 如果抛错，Observable.just 会变成 Observable.error
        return flatMap { Observable.just(try $0.mapJSON(failsOnEmptyData: failsOnEmptyData)) }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - map（转 Decodable 模型）
    // ═══════════════════════════════════════════════════════════

    /// 把 NetworkResponse 的 data 解码成指定模型。
    ///
    /// 用法：
    /// ```swift
    /// NetworkManager.shared.rx
    ///     .requestXNGResponse(apiModel: request)
    ///     .map(User.self)                     // 整个 data 解成 User
    ///     .subscribe(onNext: { (user: User) in ... })
    ///
    /// // 从 JSON 路径取
    /// NetworkManager.shared.rx
    ///     .requestXNGResponse(apiModel: request)
    ///     .map(User.self, atKeyPath: "data.user")
    ///     .subscribe(onNext: { (user: User) in ... })
    /// ```
    ///
    /// - Parameters:
    ///   - type: 目标模型类型
    ///   - keyPath: JSON 路径（如 "data.user"），nil 表示整个 data
    ///   - decoder: JSON 解码器
    ///   - failsOnEmptyData: 空数据时是否失败
    /// - Returns: Observable<D>
    public func map<D: Decodable>(
        _ type: D.Type,
        atKeyPath keyPath: String? = nil,
        using decoder: JSONDecoder = JSONDecoder(),
        failsOnEmptyData: Bool = true
    ) -> Observable<D> {

        // ① flatMap：把每个 NetworkResponse 转成 Observable<D>
        // ② try $0.map(...)：调 NetworkResponse 的 map（可能抛错）
        return flatMap {
            Observable.just(
                try $0.map(type, atKeyPath: keyPath, using: decoder, failsOnEmptyData: failsOnEmptyData)
            )
        }
    }
}
