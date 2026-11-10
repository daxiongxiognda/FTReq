//
//  FTSocketNotifiName.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/30.
//

import Foundation

/// Socket 相关通知名
/// - 枚举用 String 原始值定义通知名
/// - 通过 `TTNotificationNameProvider` 扩展把 rawValue 转成 `Notification.Name`
public enum FTSocketNotifiName: String {
    /// Socket 已打开（连接建立成功）
    case didSocketOpened = "didSocketOpened"
    /// Socket 已激活（连接可用/心跳正常）
    case didSocketActive = "didSocketActive"
    /// Socket 已关闭（连接断开）
    case didSocketClosed = "didSocketClosed"
    /// Socket 已登出（主动登出导致的断开）
    case didSocketLogout = "didSocketLogout"
    /// 同步成功（消息/会话同步完成）
    case didSyncSuccess = "didSyncSuccess"
}

extension FTSocketNotifiName: FTNotificationNameProvider {
    /// 通知名：直接用 rawValue
    /// - 注释掉的写法是加前缀 `com.tongtong.socket.` 的旧版
    /// - 当前直接用 rawValue，意味着通知名就是 "didSocketOpened" 这种短名
    public var name: Notification.Name {
        // Notification.Name("com.tongtong.socket.\(rawValue)")
        Notification.Name(rawValue)
    }
}
