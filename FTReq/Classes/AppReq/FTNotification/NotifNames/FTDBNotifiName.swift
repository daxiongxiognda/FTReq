//
//  FTDBNotifiName.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/28.
//

import Foundation

/// 数据库相关的通知名定义
public enum FTDBNotifiName: String {
    /// 数据库初始化完成
    case dbOnInit = "xyz.tongtong.dbOnInit"
}

extension FTDBNotifiName: FTNotificationNameProvider {
    /// 把枚举的原始值转成 Notification.Name
    public var name: Notification.Name {
        // 下面注释掉的写法是加前缀的旧版；当前直接用 rawValue
        // Notification.Name("com.tongtong.db.\(rawValue)")
        Notification.Name(rawValue)
    }
}

