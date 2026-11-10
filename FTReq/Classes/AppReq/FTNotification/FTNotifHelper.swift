//
//  FTNotifHelper.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/27.
//

import Foundation

/// 通知操作协议。
///
/// 让任何类型（枚举、String 等）只要实现 `name` 属性，
/// 就能直接调用 `post` / `addObserver`，不用每次写 `NotificationCenter.default.xxx(name: ...)`。
///
/// 实现者：
/// - `FTReqNotifiName`（网络模块通知）
/// - `String`（字符串直接作为通知名）
/// - 其他模块的通知枚举（如 `TTChatNotifName`、`TTIMNotifiName`）
public protocol FTNotificationNameProvider {

    /// 通知名。
    var name: Notification.Name { get }

    /// 发通知（带 object 和 userInfo）。
    func post(object: Any?, userInfo: [AnyHashable: Any]?)

    /// 发通知（只带 object）。
    func post(object: Any?)

    /// 发通知（无参数）。
    func post()

    /// 加监听。
    func addObserver(_ target: Any, select: Selector, object: Any?)
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 默认实现
// ═══════════════════════════════════════════════════════════════

public extension FTNotificationNameProvider {

    /// 发通知（带 object 和 userInfo）。
    ///
    /// 用法：
    /// ```swift
    /// FTReqNotifiName.didForbidden.post(object: self, userInfo: ["code": 101006])
    /// ```
    func post(object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        NotificationCenter.default.post(name: name, object: object, userInfo: userInfo)
    }

    /// 发通知（只带 object）。
    ///
    /// 用法：
    /// ```swift
    /// FTReqNotifiName.authTokenIsInit.post(object: self)
    /// ```
    func post(object: Any?) {
        NotificationCenter.default.post(name: name, object: object, userInfo: nil)
    }

    /// 发通知（无参数）。
    ///
    /// 用法：
    /// ```swift
    /// FTReqNotifiName.updateNetHeader.post()
    /// ```
    func post() {
        NotificationCenter.default.post(name: name, object: nil)
    }

    /// 加监听。
    ///
    /// 用法：
    /// ```swift
    /// FTReqNotifiName.didForbidden.addObserver(self, select: #selector(onForbidden))
    /// ```
    ///
    /// - Parameters:
    ///   - target: 监听者
    ///   - select: 回调方法
    ///   - object: 只监听某个 object 的通知（nil 表示监听所有）
    func addObserver(_ target: Any, select: Selector, object: Any? = nil) {
        
        NotificationCenter.default.addObserver(target, selector: select, name: name, object: object)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - String 扩展（字符串也能发通知）
// ═══════════════════════════════════════════════════════════════

/// 让 String 也遵循 TTNotificationNameProvider。
///
/// 用途：临时发一个字符串通知，不用定义枚举。
///
/// 用法：
/// ```swift
/// "my.custom.notification".post(userInfo: ["key": "value"])
/// ```
extension String: FTNotificationNameProvider {

    /// 字符串本身作为通知名。
    public var name: Notification.Name {
        Notification.Name(rawValue: self)
    }
}
