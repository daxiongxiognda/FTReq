//
//  App.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/28.
//

import FTTool

// MARK: - 应用类型

/// 应用类型（区分不同 App / 端）
/// - 遵循 `EnumCodable`：Int 原始值，未知值解码回退到 `defaultCase`
public enum TAppTypeAppType: Int, EnumCodable {
    /// ⚠️ defaultCase 设为 .all（0），意味着"解码失败/未知"会被当成"全部应用"，
    ///    而不是一个明确的"未知"值。若业务用 .all 表示"跨端/不限"，则解码失败
    ///    与真实 .all 无法区分，建议加 .unknown = -1 或 999 作为兜底
    public static var defaultCase: TAppTypeAppType = .all

    /// 全部应用（多端通用）
    case all = 0
    /// 通通 App
    case tongTong = 1
}


// MARK: - 设备类型

/// 设备/平台类型
public enum TDeviceTypeDeviceType: Int, EnumCodable {
    public static var defaultCase: TDeviceTypeDeviceType = .unknown

    case unknown = 0
    case ios = 1
    /// ⚠️ 拼写为 androID（D 大写），与常见 Android/androId 不一致，
    ///    但这是代码内标识符，不影响 JSON 编解码（枚举值走 Int）；
    ///    仅影响可读性，重命名需同步所有引用，建议保持现状别乱改
    case androID = 2
    case web = 3
    case pc = 4
    case mac = 5
}
