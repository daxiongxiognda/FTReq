//
//  NetworkProtocol.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/26.
//

/// 网络状态枚举。
///
/// 用 String 做原始值：
/// - 便于日志打印（直接输出 "wifi" 而不是数字）
/// - 便于上报（CLS 里直接存字符串）
public enum NetworkStatu: String {

    /// 未知网络状态。
    ///
    /// 场景：
    /// - 刚启动，还没开始监听网络
    /// - 监听器还没回调第一次状态
    /// - 系统 API 返回了无法识别的状态
    case unavailable

    /// 无网络。
    ///
    /// 场景：
    /// - 飞行模式
    /// - WiFi 和蜂窝都关闭
    /// - 网络接口断开
    case none

    /// 蜂窝网络（2G / 3G / 4G / 5G）。
    ///
    /// 注意：不区分具体制式（2G/3G/4G/5G），统一归为 cellular。
    /// 如果需要区分制式，可以扩展枚举或加关联值。
    case cellular

    /// WiFi 网络。
    case wifi
}


/// 网络状态变化监听协议。
///
/// 实现者通过 `NetworkManager.addNetworkObserver(_:)` 注册，
/// 网络状态变化时被 `didReceiveNetworkStatuChangged(statu:)` 回调。
///
/// 用 `AnyObject` 约束：
/// - 限制只能被 class 遵循
/// - 便于 `NetworkManager` 用弱引用管理（`NSPointerArray.weakObjects()`）
/// - 避免循环引用
public protocol NetworkEventable: AnyObject {

    /// 网络状态变化时回调。
    ///
    /// - Parameter statu: 新的网络状态
    ///
    /// 注意：
    /// - 回调可能在非主线程执行（取决于 `NetworkManager` 的监听实现）
    /// - 如果需要更新 UI，记得切主线程
    func didReceiveNetworkStatuChangged(statu: NetworkStatu)
}


/// Token 刷新协议。
///
/// 实现者通过 `NetworkManager.addTokenRefresher(_:)` 注册，
/// 当请求返回 401（token 过期）时，`NetworkManager` 调用它刷新 token。
///
/// 用 class（非 AnyObject）约束：
/// - 允许 struct 也可以实现（虽然实际用 class 更多）
/// - 便于注入不同的刷新策略（如测试 mock）
public protocol TokenRefreshable {

    /// 触发 token 刷新。
    ///
    /// - Parameter completion: 刷新完成回调
    ///   - `nil`：刷新成功
    ///   - `Error`：刷新失败
    ///
    /// 实现者职责：
    /// 1. 调用刷新 token 的接口
    /// 2. 成功后更新本地 token（如 `NetworkManager.config`）
    /// 3. 调用 `completion(nil)` 通知 `NetworkManager` 重放等待的请求
    /// 4. 失败时调用 `completion(error)`
    func didReceiveTokenRefreshRequired(completion: ((_ err: Error?) -> Void)?)
}


/// `NetworkEventable` 的默认实现。
///
/// 让实现者可以选择性地实现 `didReceiveNetworkStatuChangged`：
/// - 如果只关心某些状态，可以不实现（用默认空实现）
/// - 如果需要处理所有状态，重写即可
///
/// 这是 Swift 协议的"可选方法"实现方式（不用 `@objc optional`）。
public extension NetworkEventable {

    /// 默认空实现。
    ///
    /// 为什么需要：
    /// - 有些实现者只关心"网络可用/不可用"，不需要处理每个状态
    /// - 提供默认实现后，这些实现者不用写空方法
    func didReceiveNetworkStatuChangged(statu: NetworkStatu) {}
}
