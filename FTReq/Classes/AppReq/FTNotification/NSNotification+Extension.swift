//
//  NSNotification+Extension.swift
//  FTTool
//
//  Created by 熊坤鹏 on 2026/10/26.
//

import Foundation

// ═══════════════════════════════════════════════════════════════
// MARK: - Notification 扩展（类型安全 UserInfo）
// ═══════════════════════════════════════════════════════════════

extension Notification {

    /// 类型安全的 UserInfo key。
    ///
    /// 泛型 `ValueType` 表示这个 key 对应的值类型。
    ///
    /// 用法：
    /// ```swift
    /// // 定义 key
    /// extension Notification.UserInfoKey {
    ///     static var code: Notification.UserInfoKey<Int> { .init(key: "code") }
    ///     static var desc: Notification.UserInfoKey<String> { .init(key: "desc") }
    /// }
    ///
    /// // 发通知
    /// NotificationCenter.default.post(
    ///     name: .didForbidden,
    ///     typedUserInfo: [.code: 101006, .desc: "登录失效"]
    /// )
    ///
    /// // 接收
    /// let code = notification.getUserInfo(for: .code)   // Int?
    /// let desc = notification.getUserInfo(for: .desc)   // String?
    /// ```
    public struct UserInfoKey<ValueType>: Hashable {

        /// 实际的 key 字符串（用于存到 userInfo 字典）。
        let key: String

        // ⚠️ 问题：没有显式 init，默认的 memberwise init 是 internal 的，
        //    外部模块无法创建（除非用下面的方式扩展）。
        //    但 `static var` 扩展里用了 `.init(key:)`，
        //    说明项目里可能还有其他地方让 init 可见。
    }

    /// 从 userInfo 里取值（类型安全）。
    ///
    /// - Parameter key: 类型安全的 key
    /// - Returns: 对应类型的值；不存在或类型不匹配返回 nil
    public func getUserInfo<T>(for key: Notification.UserInfoKey<T>) -> T? {
        return userInfo?[key] as? T
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - NotificationCenter 扩展（类型安全发送）
// ═══════════════════════════════════════════════════════════════

extension NotificationCenter {

    /// 发通知（类型安全 userInfo）。
    ///
    /// 用 `[UserInfoKey<T>: T]` 代替 `[AnyHashable: Any]`，
    /// 编译期检查 key 和值的类型匹配。
    ///
    /// - Parameters:
    ///   - aName: 通知名
    ///   - anObject: 发送者
    ///   - aUserInfo: 类型安全的 userInfo
    public func post<T>(
        name aName: NSNotification.Name,
        object anObject: Any? = nil,
        typedUserInfo aUserInfo: [Notification.UserInfoKey<T>: T]? = nil
    ) {
        // 直接转调原生的 post（Swift 会自动桥接）
        // UserInfoKey 是 Hashable，值类型是 T
        post(name: aName, object: anObject, userInfo: aUserInfo)
    }
}
