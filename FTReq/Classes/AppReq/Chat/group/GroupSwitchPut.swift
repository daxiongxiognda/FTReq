//
//  GroupSwitchPut.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/28.
//

import FTTool

// MARK: - 群开关类型枚举族

/// 禁止加好友开关
/// - allow(0)：允许加好友
/// - prohibit(1)：禁止加好友
public enum TGroupSwitchPutProhibitAddFriendSwitchType: Int, EnumCodable {
    public static var defaultCase: TGroupSwitchPutProhibitAddFriendSwitchType = .allow
    case allow = 0
    case prohibit = 1
}

/// 群公开/私有开关
/// - privateModel(0)：私密群
/// - publicModel(1)：公开群
/// ⚠️ 命名 `privateModel` 中 Model 更像拼写习惯（应为 mode），但作为协议枚举保持一致即可
public enum TGroupSwitchPutPublicSwitchType: Int, EnumCodable {
    public static var defaultCase: TGroupSwitchPutPublicSwitchType = .privateModel
    case privateModel = 0
    case publicModel = 1
}

/// 谁可以操作（@全体/邀请等）的权限模式
/// - adminModel(0)：仅管理员
/// - memberModel(1)：全体成员
public enum TGroupSwitchPutSwitchType: Int, EnumCodable {
    public static var defaultCase: TGroupSwitchPutSwitchType = .adminModel
    case adminModel = 0
    case memberModel = 1
}

/// 通用"允许/禁止"开关
/// - allowModel(0)：允许
/// - prohibitModel(1)：禁止
public enum TGroupSwitchPutProhibitType: Int, EnumCodable {
    public static var defaultCase: TGroupSwitchPutProhibitType = .allowModel
    case allowModel = 0
    case prohibitModel = 1
}

/// 加群申请开关
/// - unNeed(0)：无需申请
/// - need(1)：需要申请
public enum TGroupSwitchPutJoinApplySwitchType: Int, EnumCodable {
    public static var defaultCase: TGroupSwitchPutJoinApplySwitchType = .unNeed
    case unNeed = 0
    case need = 1
}

/// 全员禁言开关
/// - unMute(0)：未禁言（可发言）
/// - muted(1)：已全员禁言
public enum TGroupSwitchPutAllMembersMuteSwitchType: Int, EnumCodable {
    public static var defaultCase: TGroupSwitchPutAllMembersMuteSwitchType = .unMute
    case unMute = 0
    case muted = 1
}

/// 历史消息条数可见范围
/// - all(-1)：全部可见
/// - zero(0)：不可见
/// - recent10/20/30：最近 N 条可见
/// ⚠️ 默认值是 .zero（0，不可见），意味着解码失败/未知值时新成员看不到历史消息，
///    这是"保守兜底"；若产品期望默认可见，需改为 .all 或明确注释
public enum TGroupSwitchPutHistoryMessageCountType: Int, EnumCodable {
    public static var defaultCase: TGroupSwitchPutHistoryMessageCountType = .zero
    case all = -1
    case zero = 0
    case recent10 = 10
    case recent20 = 20
    case recent30 = 30
}

/// 广告/背景横幅开关
/// - close(0)：关闭
/// - open(1)：开启
public enum TGroupSwitchPutAdBannerSwitchType: Int, EnumCodable {
    public static var defaultCase: TGroupSwitchPutAdBannerSwitchType = .close
    case close = 0
    case open = 1
}

/// 通用开关（开/关）
public enum TGroupSwitchType: Int, EnumCodable {
    public static var defaultCase: TGroupSwitchType = .close
    case close = 0
    case open = 1
}


// MARK: - 群开关设置请求

/// 更新群开关设置的请求
/// - 遵循 `Encodable`（标准 Codable）：属性名即 JSON key
/// - 所有开关字段均为 `Optional`：只传需要修改的字段，
///   nil 表示"不修改该项"（部分更新语义）
/// - ⚠️ 注意与 `TGroupInfoCommonResource` 的字段对应关系：
///   那边的同名属性（如 publicSwitch）类型是本文件的枚举，
///   修改时类型要一致，避免传错枚举
public struct TGroupSwitchPutReq: Encodable {

    /// 群 id（必填）
    public var groupId = ""

    /// 公开/私密
    public var publicSwitch: TGroupSwitchPutPublicSwitchType?
    /// @全体成员权限
    public var atAllSwitch: TGroupSwitchPutSwitchType?
    /// 邀请权限
    public var inviteSwitch: TGroupSwitchPutSwitchType?
    /// 加群申请开关
    public var joinApplySwitch: TGroupSwitchPutJoinApplySwitchType?
    /// 全员禁言开关
    public var allMembersMuteSwitch: TGroupSwitchPutAllMembersMuteSwitchType?
    /// 禁止加好友开关
    public var prohibitAddFriendSwitchType: TGroupSwitchPutProhibitAddFriendSwitchType?
    /// 历史消息可见条数
    public var historyMessageCount: TGroupSwitchPutHistoryMessageCountType?
    /// 禁止发送链接
    public var prohibitSendLinkSwitch: TGroupSwitchPutProhibitType?
    /// 禁止发送二维码
    public var prohibitSendQRCodeSwitch: TGroupSwitchPutProhibitType?
    /// 禁止修改群名
    public var prohibitModifyNameSwitchType: TGroupSwitchPutProhibitType?
    /// 广告横幅开关
    public var adBannerSwitch: TGroupSwitchPutAdBannerSwitchType?
    /// 背景开关
    public var backgroundSwitch: TGroupSwitchPutAdBannerSwitchType?
    /// 经营管理开关
    public var managementBusinessSwitch: TGroupSwitchType?
    /// 限制时长（分钟）
    /// ⚠️ 非可选且默认 0：标准 Codable 会**始终编码该字段**（输出 0），
    ///    而其他开关是 Optional，nil 时不输出。若服务端把 0 当成"设置为 0 分钟"，
    ///    可能与"不修改"语义冲突；建议确认协议，或改为 Int? 保持部分更新一致
    public var limitMinutes = 0

    public init() {}
}
