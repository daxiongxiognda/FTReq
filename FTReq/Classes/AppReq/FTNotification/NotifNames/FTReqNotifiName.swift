//
//  FTReqNotifiName.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/27.
//

import Foundation

/// 网络模块的通知名称枚举。
///
/// 设计意图：
/// 1. 把通知名收敛到一个枚举，避免字符串散落各处
/// 2. 编译期检查：用 `FTReqNotifiName.didForbidden.name` 而不是 `"didForbidden"`
/// 3. 便于全局搜索：找某个通知的所有使用处，直接搜枚举值
///
/// 使用方式：
/// ```swift
/// // 发通知
/// NotificationCenter.default.post(name: FTReqNotifiName.didForbidden.name, object: self, userInfo: [...])
///
/// // 监听
/// NotificationCenter.default.addObserver(self, selector: #selector(onForbidden), name: FTReqNotifiName.didForbidden.name, object: nil)
/// ```
public enum FTReqNotifiName: String {

    // ═══════════════════════════════════════════════════════════
    // MARK: - 鉴权相关
    // ═══════════════════════════════════════════════════════════

    /// Token 初始化完成。
    ///
    /// 触发时机：登录成功、token 刷新成功后。
    /// 监听方：需要 token 的业务模块（如 IM、埋点）。
    case authTokenIsInit = "AuthTokenIsInit"

    /// 被禁止访问（token 失效、账号异常）。
    ///
    /// 触发时机：`NetworkManager.checkLogout` 检测到 4 种业务码（101004 / 101006 / 101007 / 101011）。
    /// 监听方：登录模块（跳登录页）、业务模块（清理用户数据）。
    /// 携带 userInfo：`["code": Int, "desc": String]`
    case didForbidden = "xyz.xtt.tongtong.notification.name.request.didForbidden"

    // ═══════════════════════════════════════════════════════════
    // MARK: - 配置更新
    // ═══════════════════════════════════════════════════════════

    /// 更新地区码（adcode）。
    ///
    /// 触发时机：用户切换地区、定位变化。
    /// 监听方：`NetworkManager`（更新 `NetworkConfig.adcode`）。
    case updateAdCode = "xyz.xtt.tongtong.notification.name.request.updateAdCode"

    /// 更新位置（经纬度）。
    ///
    /// 触发时机：用户位置变化。
    /// 监听方：`NetworkManager`（更新请求头里的 `lonlat`）。
    case updateLocaion = "xyz.xtt.tongtong.notification.name.request.updateLocaion"

    /// 更新网络请求头。
    ///
    /// 触发时机：token 变化、设备信息变化。
    /// 监听方：`NetworkManager`（重新构建 `defaultHeaders`）。
    ///
    /// ⚠️ 拼写错误：`Locaion` 应该是 `Location`。
    case updateNetHeader = "xyz.xtt.tongtong.notification.name.request.updateNetHeader"

    // ═══════════════════════════════════════════════════════════
    // MARK: - 业务通知
    // ═══════════════════════════════════════════════════════════

    /// H5 金币领取成功后通知原生刷新待领取余额。
    ///
    /// 触发时机：H5 页面完成金币领取。
    /// 监听方：原生金币模块（刷新余额显示）。
    case goldRewardClaimed = "xyz.xtt.tongtong.notification.name.reward.goldRewardClaimed"
}

// ═══════════════════════════════════════════════════════════════
// MARK: - TTNotificationNameProvider
// ═══════════════════════════════════════════════════════════════

/// 把枚举转成 `Notification.Name`。
///
/// 协议 `TTNotificationNameProvider` 是项目定义的（在 FTTool 里），
/// 要求实现者提供 `name` 属性。
extension FTReqNotifiName: FTNotificationNameProvider {

    /// 通知名。
    ///
    /// 直接用枚举的 `rawValue` 作为通知名。
    ///
    /// 为什么不用加前缀：
    /// - 枚举的 `rawValue` 已经带完整命名空间（如 `xyz.xtt.tongtong.notification.name.request.didForbidden`）
    /// - 不需要再额外加前缀，否则会重复
    public var name: Notification.Name {
        // 旧写法（已注释）：加前缀 "com.tongtong.req."
        // Notification.Name("com.tongtong.req.\(rawValue)")

        // 新写法：直接用 rawValue
        Notification.Name(rawValue)
    }
}

