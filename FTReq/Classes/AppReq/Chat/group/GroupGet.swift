//
//  GroupGet.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/28.
//

import FTTool

// MARK: - 加群来源

/// 加群来源（用户从哪个入口加入群）
/// - 原始值用 String，但额外提供 `toIntValue()` 映射到 Int，
///   用于上报/协议中以数字表示来源
/// - ⚠️ 注意：`EnumCodable` 的 String 原始值解码时按 case 名匹配，
///   而 `toIntValue()` 是另一套编码，两套表示需保持一致，新增 case 必须同步加 switch
public enum TGroupJoinSource: String, EnumCodable {
    public static var defaultCase: TGroupJoinSource = .unknown
    case unknown                // 未知
    case groupSearch            // 群搜索
    case groupSquare            // 群广场
    case groupRecommend         // 推荐群聊
    case groupAboutActivity     // 活动关联群组
    case groupConnectList       // 联系人的群列表
    case groupInvite            // 群邀请卡片（内部 IM 发送卡片消息）
    case groupHorn              // 群喇叭
    case groupShare             // 群分享（二维码/链接从外部进入）
    case groupVisitor           // 群中群
    case fightLowGoGroup        // 拼低低加群

    /// 枚举 → 协议数字
    /// ⚠️ 与 case 必须一一对应，新增 case 忘记加分支会导致编译失败（switch 穷尽检查）
    public func toIntValue() -> Int {
        switch self {
        case .unknown: return 0
        case .groupSearch: return 1
        case .groupSquare: return 2
        case .groupRecommend: return 3
        case .groupAboutActivity: return 4
        case .groupConnectList: return 5
        case .groupInvite: return 6
        case .groupHorn: return 7
        case .groupShare: return 8
        case .groupVisitor: return 9
        case .fightLowGoGroup: return 10
        }
    }
}

// MARK: - 用户与群关系

/// 当前用户与群的关系
public enum TGroupGetUserGroupRelationType: Int, EnumCodable {
    public static var defaultCase: TGroupGetUserGroupRelationType = .none
    case none = 0          // 无关系
    case joined = 1        // 已加入
    case applied = 2       // 已申请（待审核）
    case applyReject = 3   // 申请被拒绝
}

// MARK: - 加群申请开关

/// 是否需要申请才能加群
public enum TGroupGetJoinApplySwitchType: Int, EnumCodable {
    public static var defaultCase: TGroupGetJoinApplySwitchType = .unNeed
    case unNeed = 0    // 无需申请
    case need = 1      // 需要申请
}

// MARK: - 群状态

/// 群状态
/// ⚠️ 数值不连续（0/1/5/10），中间值被其他协议占用，不可重排
public enum TGroupGetGroupStatus: Int, EnumCodable {
    public static var defaultCase: TGroupGetGroupStatus = .unknown
    case unknown = 0
    case normal = 1
    case snowGroup = 5     // 雪藏群
    case dissolve = 10     // 已解散
}


// MARK: - 群列表项（TGroupGetData）

/// 群列表/搜索结果中的单个群数据（精简版）
public struct TGroupGetData: DynamicCodable {
    public var groupID = ""
    public var name = ""
    public var photo = ""
    public var status: TGroupGetGroupStatus = .defaultCase
    public var masterID: Int64 = 0
    public var memberCount = 0
    public var userGroupRelation: TGroupGetUserGroupRelationType = .defaultCase
    public var joinApplySwitch: TGroupGetJoinApplySwitchType = .defaultCase
    public var activityID: Int64 = 0
    public var category = ""
    public var femaleMemberCount = 0
    public var hotValue = 0
    public var cityID: Int64 = 0
    public var tagIds = [Int64]()
    public var description = ""
    public var activityName = ""
    public var activitySize = 0
    /// 是否展示（前端/服务端筛选标记）
    public var show = false
    public var recentMemberIds = [Int64]()
    public var allMembersMuteSwitch: TGroupSwitchPutAllMembersMuteSwitchType = .defaultCase
    public var leaderIds = [Int64]()

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.groupID, forKey: "groupId", in: &container)
        try encodeAny(self.name, forKey: "name", in: &container)
        try encodeAny(self.photo, forKey: "photo", in: &container)
        try encodeAny(self.status, forKey: "status", in: &container)
        try encodeAny(self.masterID, forKey: "masterId", in: &container)
        try encodeAny(self.memberCount, forKey: "memberCount", in: &container)
        try encodeAny(self.userGroupRelation, forKey: "userGroupRelation", in: &container)
        try encodeAny(self.joinApplySwitch, forKey: "joinApplySwitch", in: &container)
        try encodeAny(self.activityID, forKey: "activityId", in: &container)
        try encodeAny(self.category, forKey: "category", in: &container)
        try encodeAny(self.femaleMemberCount, forKey: "femaleMemberCount", in: &container)
        try encodeAny(self.hotValue, forKey: "hotValue", in: &container)
        try encodeAny(self.cityID, forKey: "cityId", in: &container)
        try encodeAny(self.tagIds, forKey: "tagIds", in: &container)
        try encodeAny(self.description, forKey: "description", in: &container)
        try encodeAny(self.activityName, forKey: "activityName", in: &container)
        try encodeAny(self.activitySize, forKey: "activitySize", in: &container)
        try encodeAny(self.show, forKey: "show", in: &container)
        try encodeAny(self.recentMemberIds, forKey: "recentMemberIds", in: &container)
        try encodeAny(self.allMembersMuteSwitch, forKey: "allMembersMuteSwitch", in: &container)
        try encodeAny(self.leaderIds, forKey: "leaderIds", in: &container)
    }

    /// 解码（硬解，缺字段抛错）
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.groupID = try decodeField("groupId", from: container)
        self.name = try decodeField("name", from: container)
        self.photo = try decodeField("photo", from: container)
        self.status = try decodeField("status", from: container)
        self.masterID = try decodeField("masterId", from: container)
        self.memberCount = try decodeField("memberCount", from: container)
        self.userGroupRelation = try decodeField("userGroupRelation", from: container)
        self.joinApplySwitch = try decodeField("joinApplySwitch", from: container)
        self.activityID = try decodeField("activityId", from: container)
        self.category = try decodeField("category", from: container)
        self.femaleMemberCount = try decodeField("femaleMemberCount", from: container)
        self.hotValue = try decodeField("hotValue", from: container)
        self.cityID = try decodeField("cityId", from: container)
        self.tagIds = try decodeField("tagIds", from: container)
        self.description = try decodeField("description", from: container)
        self.activityName = try decodeField("activityName", from: container)
        self.activitySize = try decodeField("activitySize", from: container)
        self.show = try decodeField("show", from: container)
        self.recentMemberIds = try decodeField("recentMemberIds", from: container)
        self.allMembersMuteSwitch = try decodeField("allMembersMuteSwitch", from: container)
        self.leaderIds = try decodeField("leaderIds", from: container)
    }
}


// MARK: - 群详情数据（TGroupInfoGetData）

/// 群详情（比 TGroupGetData 多备注名/头像列表/开关，且遵循 Hashable）
/// - 实现 Hashable 说明可能用于 Set/Dictionary 去重或 diff
/// ⚠️ 与 TGroupGetData 字段高度重叠但不一致（如 hotValue 这里 Int64、那边 Int），
///    两个"群数据"结构长期维护易混淆，建议注释说明各自使用场景
public struct TGroupInfoGetData: DynamicCodable, Hashable {
    public var groupID = ""
    public var name = ""
    public var photo = ""
    public var status: TGroupGetGroupStatus = .defaultCase
    public var masterID: Int64 = 0
    public var memberCount = 0
    public var userGroupRelation: TGroupGetUserGroupRelationType = .defaultCase
    public var joinApplySwitch: TGroupGetJoinApplySwitchType = .defaultCase
    public var activityID: Int64 = 0
    public var category = ""
    public var publicSwitch: TGroupSwitchPutPublicSwitchType = .defaultCase
    public var atAllSwitch: TGroupSwitchPutSwitchType = .defaultCase
    public var inviteSwitch: TGroupSwitchPutSwitchType = .defaultCase
    /// 我对该群的备注名
    public var noteName = ""
    public var cityID: Int64 = 0
    public var tagIds = [Int64]()
    public var description = ""
    public var femaleMemberCount = 0
    /// ⚠️ 这里是 Int64，而 TGroupGetData.hotValue 是 Int，类型不一致
    public var hotValue: Int64 = 0
    public var activityName = ""
    /// 群成员头像列表(展示用)
    public var avatars = [String]()
    public var recentMemberIds = [Int64]()
    public var allMembersMuteSwitch: TGroupSwitchPutAllMembersMuteSwitchType = .defaultCase
    public var leaderIds = [Int64]()

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.groupID, forKey: "groupId", in: &container)
        try encodeAny(self.name, forKey: "name", in: &container)
        try encodeAny(self.photo, forKey: "photo", in: &container)
        try encodeAny(self.status, forKey: "status", in: &container)
        try encodeAny(self.masterID, forKey: "masterId", in: &container)
        try encodeAny(self.memberCount, forKey: "memberCount", in: &container)
        try encodeAny(self.userGroupRelation, forKey: "userGroupRelation", in: &container)
        try encodeAny(self.joinApplySwitch, forKey: "joinApplySwitch", in: &container)
        try encodeAny(self.activityID, forKey: "activityId", in: &container)
        try encodeAny(self.category, forKey: "category", in: &container)
        try encodeAny(self.publicSwitch, forKey: "publicSwitch", in: &container)
        try encodeAny(self.atAllSwitch, forKey: "atAllSwitch", in: &container)
        try encodeAny(self.inviteSwitch, forKey: "inviteSwitch", in: &container)
        try encodeAny(self.noteName, forKey: "noteName", in: &container)
        try encodeAny(self.cityID, forKey: "cityId", in: &container)
        try encodeAny(self.tagIds, forKey: "tagIds", in: &container)
        try encodeAny(self.description, forKey: "description", in: &container)
        try encodeAny(self.femaleMemberCount, forKey: "femaleMemberCount", in: &container)
        try encodeAny(self.hotValue, forKey: "hotValue", in: &container)
        try encodeAny(self.activityName, forKey: "activityName", in: &container)
        try encodeAny(self.avatars, forKey: "avatars", in: &container)
        try encodeAny(self.recentMemberIds, forKey: "recentMemberIds", in: &container)
        try encodeAny(self.allMembersMuteSwitch, forKey: "allMembersMuteSwitch", in: &container)
        try encodeAny(self.leaderIds, forKey: "leaderIds", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.groupID = try decodeField("groupId", from: container)
        self.name = try decodeField("name", from: container)
        self.photo = try decodeField("photo", from: container)
        self.status = try decodeField("status", from: container)
        self.masterID = try decodeField("masterId", from: container)
        self.memberCount = try decodeField("memberCount", from: container)
        self.userGroupRelation = try decodeField("userGroupRelation", from: container)
        self.joinApplySwitch = try decodeField("joinApplySwitch", from: container)
        self.activityID = try decodeField("activityId", from: container)
        self.category = try decodeField("category", from: container)
        self.publicSwitch = try decodeField("publicSwitch", from: container)
        self.atAllSwitch = try decodeField("atAllSwitch", from: container)
        self.inviteSwitch = try decodeField("inviteSwitch", from: container)
        self.noteName = try decodeField("noteName", from: container)
        self.cityID = try decodeField("cityId", from: container)
        self.tagIds = try decodeField("tagIds", from: container)
        self.description = try decodeField("description", from: container)
        self.femaleMemberCount = try decodeField("femaleMemberCount", from: container)
        self.hotValue = try decodeField("hotValue", from: container)
        self.activityName = try decodeField("activityName", from: container)
        self.avatars = try decodeField("avatars", from: container)
        self.recentMemberIds = try decodeField("recentMemberIds", from: container)
        self.allMembersMuteSwitch = try decodeField("allMembersMuteSwitch", from: container)
        self.leaderIds = try decodeField("leaderIds", from: container)
    }
}


// MARK: - 签到/提升人数开关状态

/// 群签到 / 群 AI / 人数限制 的开关组合
public struct CheckInOrImproveCountsStatus: DynamicCodable {
    public var memberLimitToggle: Bool = false
    public var checkInToggle: Bool = false
    public var groupAiToggle: Bool = false

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.memberLimitToggle, forKey: "memberLimitToggle", in: &container)
        try encodeAny(self.checkInToggle, forKey: "checkInToggle", in: &container)
        try encodeAny(self.groupAiToggle, forKey: "groupAiToggle", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.memberLimitToggle = try decodeField("memberLimitToggle", from: container)
        self.checkInToggle = try decodeField("checkInToggle", from: container)
        self.groupAiToggle = try decodeField("groupAiToggle", from: container)
    }
}


// MARK: - Request：查询签到活动列表

/// 查询签到活动列表请求
/// - 遵循标准 Codable（属性名即 JSON key）
/// - 全部字段可选，作为查询条件灵活组合
public struct GroupCheckinActivityListRequest: Codable {
    public var pageNum: Int?
    public var pageSize: Int?

    public var name: String?
    public var description: String?

    public var bizType: Int?
    public var bizId: String?
    public var bizName: String?

    public var ruleType: Int?
    public var lessThenTime: String?
    public var greaterThenTime: String?

    public var allowRetroactive: Int?
    public var year: Int?
    public var month: Int?

    /// 状态过滤：10 初始、20 未开始、21 进行中、30 终止、40 结束、50 废弃
    public var status: [Int]?

    public init(pageNum: Int?,
                pageSize: Int?,
                name: String? = nil,
                description: String? = nil,
                bizType: Int? = nil,
                bizId: String? = nil,
                bizName: String? = nil,
                ruleType: Int? = nil,
                lessThenTime: String? = nil,
                greaterThenTime: String? = nil,
                allowRetroactive: Int? = nil,
                year: Int? = nil,
                month: Int? = nil,
                status: [Int]? = nil) {
        self.pageNum = pageNum
        self.pageSize = pageSize
        self.name = name
        self.description = description
        self.bizType = bizType
        self.bizId = bizId
        self.bizName = bizName
        self.ruleType = ruleType
        self.lessThenTime = lessThenTime
        self.greaterThenTime = greaterThenTime
        self.allowRetroactive = allowRetroactive
        self.year = year
        self.month = month
        self.status = status
    }
}

/// 业务类型（签到绑定的业务，目前只有群）
public enum BizTypeEnum: Int, Codable {
    case group = 10
}

/// 签到规则类型
public enum RuleTypeEnum: Int, Codable {
    case daily = 10                   // 每天
    case cumulative = 20              // 累计
    case continuous = 30              // 连续
    case dailyWithContinuous = 40     // 每天 + 连续
}

/// 是否允许补签
public enum AllowRetroactiveEnum: Int, Codable {
    case no = 0
    case yes = 1
}

/// 签到活动列表响应
public struct GroupCheckinActivityListResponse: DynamicCodable {
    /// 签到规则分页数据
    public var checkinRules: CheckinRules?

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.checkinRules, forKey: "checkinRules", in: &container)
    }

    /// ⚠️ 硬解：`checkinRules` 可选（无活动时可能缺失），建议容错
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.checkinRules = try decodeField("checkinRules", from: container)
    }
}

/// 签到规则分页
public struct CheckinRules: DynamicCodable {
    public var totalCount: Int?
    public var pageSize: Int?
    public var list: [CheckinRuleItem]?

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.totalCount, forKey: "totalCount", in: &container)
        try encodeAny(self.pageSize, forKey: "pageSize", in: &container)
        try encodeAny(self.list, forKey: "list", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.totalCount = try decodeField("totalCount", from: container)
        self.pageSize = try decodeField("pageSize", from: container)
        self.list = try decodeField("list", from: container)
    }
}

/// 单条签到规则
public struct CheckinRuleItem: DynamicCodable {
    public var id: Int?
    public var name: String?
    public var description: String?
    public var bizType: Int?                // 业务类型
    public var bizId: String?               // 业务 id
    public var ruleType: Int?               // 规则类型
    public var activityDays: Int?           // 活动天数
    public var startTime: String?           // 活动开始时间
    public var endTime: String?             // 活动结束时间
    public var dailyStartTime: String?      // 每日可签到开始时间
    public var dailyEndTime: String?        // 每日可签到结束时间
    public var dailyLimit: Int?             // 每日限制次数
    public var firstComeLimit: Int?         // 先到先得限制
    public var allowRetroactive: Int?       // 是否允许补签 0/1
    public var maxRetroactiveDays: Int?     // 最大补签天数
    public var retroactiveStrategy: String? // 补签策略
    public var status: Int?                 // 状态

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.name, forKey: "name", in: &container)
        try encodeAny(self.description, forKey: "description", in: &container)
        try encodeAny(self.bizType, forKey: "bizType", in: &container)
        try encodeAny(self.bizId, forKey: "bizId", in: &container)
        try encodeAny(self.ruleType, forKey: "ruleType", in: &container)
        try encodeAny(self.activityDays, forKey: "activityDays", in: &container)
        try encodeAny(self.startTime, forKey: "startTime", in: &container)
        try encodeAny(self.endTime, forKey: "endTime", in: &container)
        try encodeAny(self.dailyStartTime, forKey: "dailyStartTime", in: &container)
        try encodeAny(self.dailyEndTime, forKey: "dailyEndTime", in: &container)
        try encodeAny(self.dailyLimit, forKey: "dailyLimit", in: &container)
        try encodeAny(self.allowRetroactive, forKey: "allowRetroactive", in: &container)
        try encodeAny(self.firstComeLimit, forKey: "firstComeLimit", in: &container)
        try encodeAny(self.maxRetroactiveDays, forKey: "maxRetroactiveDays", in: &container)
        try encodeAny(self.retroactiveStrategy, forKey: "retroactiveStrategy", in: &container)
        try encodeAny(self.status, forKey: "status", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.name = try decodeField("name", from: container)
        self.description = try decodeField("description", from: container)
        self.bizType = try decodeField("bizType", from: container)
        self.bizId = try decodeField("bizId", from: container)
        self.ruleType = try decodeField("ruleType", from: container)
        self.activityDays = try decodeField("activityDays", from: container)
        self.startTime = try decodeField("startTime", from: container)
        self.endTime = try decodeField("endTime", from: container)
        self.dailyStartTime = try decodeField("dailyStartTime", from: container)
        self.dailyEndTime = try decodeField("dailyEndTime", from: container)
        self.dailyLimit = try decodeField("dailyLimit", from: container)
        self.allowRetroactive = try decodeField("allowRetroactive", from: container)
        self.firstComeLimit = try decodeField("firstComeLimit", from: container)
        self.maxRetroactiveDays = try decodeField("maxRetroactiveDays", from: container)
        self.retroactiveStrategy = try decodeField("retroactiveStrategy", from: container)
        self.status = try decodeField("status", from: container)
    }
}


// MARK: - Request：查询签到记录

/// 查询签到记录请求（标准 Codable）
public struct GroupCheckinCollectionRecordsRequest: Codable {
    public var userId: Int64
    public var ruleId: Int
    public var checkinType: GroupCheckinType?
    public var isRetroactive: Bool?

    public init(userId: Int64,
                ruleId: Int,
                checkinType: GroupCheckinType? = nil,
                isRetroactive: Bool? = nil) {
        self.userId = userId
        self.ruleId = ruleId
        self.checkinType = checkinType
        self.isRetroactive = isRetroactive
    }
}

/// 查询签到记录响应
public struct GroupCheckinCollectionRecordsResponse: DynamicCodable {
    public var pageExtend: PageExtend?
    public var checkinRecords: [CheckinRecords]?

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.pageExtend, forKey: "pageExtend", in: &container)
        try encodeAny(self.checkinRecords, forKey: "checkinRecords", in: &container)
    }

    /// ⚠️ 硬解：两个字段均可选，建议容错
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.pageExtend = try decodeField("pageExtend", from: container)
        self.checkinRecords = try decodeField("checkinRecords", from: container)
    }
}

/// 分页附加信息（签到奖励/预算/连续天数）
public struct PageExtend: DynamicCodable {
    public var dailyUserLimit: Int?
    public var dailyReward: Int?
    public var continuousReward: Int?
    public var consumeBudget: Double?
    public var remainingBudget: Double?
    public var continuousDays: Int?

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.dailyUserLimit, forKey: "dailyUserLimit", in: &container)
        try encodeAny(self.dailyReward, forKey: "dailyReward", in: &container)
        try encodeAny(self.continuousReward, forKey: "continuousReward", in: &container)
        try encodeAny(self.consumeBudget, forKey: "consumeBudget", in: &container)
        try encodeAny(self.remainingBudget, forKey: "remainingBudget", in: &container)
        try encodeAny(self.continuousDays, forKey: "continuousDays", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.dailyUserLimit = try decodeField("dailyUserLimit", from: container)
        self.dailyReward = try decodeField("dailyReward", from: container)
        self.continuousReward = try decodeField("continuousReward", from: container)
        self.consumeBudget = try decodeField("consumeBudget", from: container)
        self.remainingBudget = try decodeField("remainingBudget", from: container)
        self.continuousDays = try decodeField("continuousDays", from: container)
    }
}

/// 单条签到记录（日历视图用）
public struct CheckinRecords: DynamicCodable {
    public var id: Int64?
    public var calendarDay: String?
    public var isToday: Bool?
    public var checkinStatus: GroupCheckinStatus?
    public var rewardType: GroupRewardType?
    public var rewardQuantity: Int?

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.calendarDay, forKey: "calendarDay", in: &container)
        try encodeAny(self.isToday, forKey: "isToday", in: &container)
        try encodeAny(self.checkinStatus, forKey: "checkinStatus", in: &container)
        try encodeAny(self.rewardType, forKey: "rewardType", in: &container)
        try encodeAny(self.rewardQuantity, forKey: "rewardQuantity", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.calendarDay = try decodeField("calendarDay", from: container)
        self.isToday = try decodeField("isToday", from: container)
        self.checkinStatus = try decodeField("checkinStatus", from: container)
        self.rewardType = try decodeField("rewardType", from: container)
        self.rewardQuantity = try decodeField("rewardQuantity", from: container)
    }
}


// MARK: - 签到相关枚举

/// 签到类型
public enum GroupCheckinType: Int, Codable {
    case normal = 10        // 正常签到
    case taskTrigger = 20   // 任务触发签到
    case auto = 30          // 自动签到
}

/// 奖励类型
public enum GroupRewardType: Int, Codable {
    case gold = 10
    case diamond = 20
    case points = 30
    case coupon = 40
    case item = 50
}

/// 签到状态
public enum GroupCheckinStatus: Int, Codable {
    case unsigned = 0   // 未签到
    case signed = 1     // 已签到
}

/// 接龙类型
public enum DragonType: Int, EnumCodable {
    public static var defaultCase: DragonType = .regular
    case regular = 1    // 普通接龙
}

/// 是否补签
/// - 额外实现 `ExpressibleByBooleanLiteral`，允许直接写 `true/false` 当枚举用
public enum GroupRetroactive: Int, Codable, ExpressibleByBooleanLiteral {
    case no = 0
    case yes = 1

    public init(booleanLiteral value: Bool) {
        self = value ? .yes : .no
    }

    public var boolValue: Bool {
        return self == .yes
    }
}

/// 奖励发放状态
public enum DistributionStatusEnum: Int, Codable {
    case pending = 10
    case success = 20
    case fail = 30
    case rollback = 40
}

/// 触发/消耗类型（金币/钻石/积分）
public enum ActiontriggerType: Int, Codable {
    case gold = 10
    case diamond = 20
    case points = 30
}


// MARK: - Request：签到动作

/// 签到动作请求（标准 Codable + 显式 CodingKeys）
public struct GroupCheckinActionRequest: Codable {
    public let ruleId: Int
    public let checkinType: GroupCheckinType?
    public let isRetroactive: Bool?
    public let retroactiveCost: String?
    public let retroactive: CheckinRetroactive?

    private enum CodingKeys: String, CodingKey {
        case ruleId
        case checkinType
        case isRetroactive
        case retroactiveCost
        case retroactive
    }

    public init(ruleId: Int,
                checkinType: GroupCheckinType? = nil,
                isRetroactive: Bool? = nil,
                retroactiveCost: String? = nil,
                retroactive: CheckinRetroactive? = nil) {
        self.ruleId = ruleId
        self.checkinType = checkinType
        self.isRetroactive = isRetroactive
        self.retroactiveCost = retroactiveCost
        self.retroactive = retroactive
    }
}

/// 补签详情
public struct CheckinRetroactive: DynamicCodable {
    public var targetDate: String?
    public var costType: ActiontriggerType?
    public var costValue: Int?
    public var costDetail: String?

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.targetDate, forKey: "targetDate", in: &container)
        try encodeAny(self.costType, forKey: "costType", in: &container)
        try encodeAny(self.costValue, forKey: "costValue", in: &container)
        try encodeAny(self.costDetail, forKey: "costDetail", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.targetDate = try decodeField("targetDate", from: container)
        self.costType = try decodeField("costType", from: container)
        self.costValue = try decodeField("costValue", from: container)
        self.costDetail = try decodeField("costDetail", from: container)
    }
}

/// 签到动作响应
public struct GroupCheckinActionResponse: DynamicCodable {
    public var checkinRecord: CheckinActionRecord?
    public var checkinRewards: [CheckinActionReward]?

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.checkinRecord, forKey: "checkinRecord", in: &container)
        try encodeAny(self.checkinRewards, forKey: "checkinRewards", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.checkinRecord = try decodeField("checkinRecord", from: container)
        self.checkinRewards = try decodeField("checkinRewards", from: container)
    }
}

/// 签到动作返回的记录
public struct CheckinActionRecord: DynamicCodable {
    public var userId: Int64?
    public var ruleId: Int?
    public var checkinDate: String?
    public var checkinTime: String?
    public var checkinType: GroupCheckinType?
    public var continuousDays: Int?      // 连续签到天数
    public var cumulativeCount: Int?     // 累计签到次数
    public var checkinMessage: String?   // 签到提示信息

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.userId, forKey: "userId", in: &container)
        try encodeAny(self.ruleId, forKey: "ruleId", in: &container)
        try encodeAny(self.checkinDate, forKey: "checkinDate", in: &container)
        try encodeAny(self.checkinTime, forKey: "checkinTime", in: &container)
        try encodeAny(self.checkinType, forKey: "checkinType", in: &container)
        try encodeAny(self.continuousDays, forKey: "continuousDays", in: &container)
        try encodeAny(self.cumulativeCount, forKey: "cumulativeCount", in: &container)
        try encodeAny(self.checkinMessage, forKey: "checkinMessage", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.userId = try decodeField("userId", from: container)
        self.ruleId = try decodeField("ruleId", from: container)
        self.checkinDate = try decodeField("checkinDate", from: container)
        self.checkinTime = try decodeField("checkinTime", from: container)
        self.checkinType = try decodeField("checkinType", from: container)
        self.continuousDays = try decodeField("continuousDays", from: container)
        self.cumulativeCount = try decodeField("cumulativeCount", from: container)
        self.checkinMessage = try decodeField("checkinMessage", from: container)
    }
}

/// 签到奖励项
public struct CheckinActionReward: DynamicCodable {
    public var triggerType: ActiontriggerType?
    public var triggerValue: Int?
    public var rewardType: GroupRewardType?
    public var rewardName: String?
    public var rewardQuantity: Int?
    public var rewardDetail: String?
    public var distributionStatus: DistributionStatusEnum?
    public var distributionTime: String?

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.triggerType, forKey: "triggerType", in: &container)
        try encodeAny(self.triggerValue, forKey: "triggerValue", in: &container)
        try encodeAny(self.rewardType, forKey: "rewardType", in: &container)
        try encodeAny(self.rewardName, forKey: "rewardName", in: &container)
        try encodeAny(self.rewardQuantity, forKey: "rewardQuantity", in: &container)
        try encodeAny(self.rewardDetail, forKey: "rewardDetail", in: &container)
        try encodeAny(self.distributionStatus, forKey: "distributionStatus", in: &container)
        try encodeAny(self.distributionTime, forKey: "distributionTime", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.triggerType = try decodeField("triggerType", from: container)
        self.triggerValue = try decodeField("triggerValue", from: container)
        self.rewardType = try decodeField("rewardType", from: container)
        self.rewardName = try decodeField("rewardName", from: container)
        self.rewardQuantity = try decodeField("rewardQuantity", from: container)
        self.rewardDetail = try decodeField("rewardDetail", from: container)
        self.distributionStatus = try decodeField("distributionStatus", from: container)
        self.distributionTime = try decodeField("distributionTime", from: container)
    }
}


// MARK: - 接龙：创建

/// 创建接龙响应
public struct DragonCreatModel: DynamicCodable {
    public var dragonCreate: DragonCreat?                 // 接龙主体
    public var participantList: [DragonParticipantList]?  // 参与列表

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.dragonCreate, forKey: "dragonCreate", in: &container)
        try encodeAny(self.participantList, forKey: "participantList", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.dragonCreate = try decodeField("dragonCreate", from: container)
        self.participantList = try decodeField("participantList", from: container)
    }
}

/// 接龙主体
public struct DragonCreat: DynamicCodable {
    public var id: Int64?
    public var groupId: String?
    public var dragonType: DragonType?
    public var titleContent: String?
    public var exampleContent: String?
    public var additionalContent: String?
    public var capacityLimit: Int?      // 参与人数限制(0 不限制)
    public var totalLimit: Int?         // 总接龙次数
    public var participantCount: Int?   // 参与人数
    public var createUserId: Int64?     // 发起人
    public var status: Int?
    public var autoClose: Int?          // 是否自动截止
    public var closeTime: String?       // 截止时间
    public var removeRepeat: Bool?      // 是否排重继续创建

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.groupId, forKey: "groupId", in: &container)
        try encodeAny(self.dragonType, forKey: "dragonType", in: &container)
        try encodeAny(self.titleContent, forKey: "titleContent", in: &container)
        try encodeAny(self.exampleContent, forKey: "exampleContent", in: &container)
        try encodeAny(self.additionalContent, forKey: "additionalContent", in: &container)
        try encodeAny(self.capacityLimit, forKey: "capacityLimit", in: &container)
        try encodeAny(self.totalLimit, forKey: "totalLimit", in: &container)
        try encodeAny(self.participantCount, forKey: "participantCount", in: &container)
        try encodeAny(self.createUserId, forKey: "createUserId", in: &container)
        try encodeAny(self.status, forKey: "status", in: &container)
        try encodeAny(self.autoClose, forKey: "autoClose", in: &container)
        try encodeAny(self.closeTime, forKey: "closeTime", in: &container)
        try encodeAny(self.removeRepeat, forKey: "removeRepeat", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.groupId = try decodeField("groupId", from: container)
        self.dragonType = try decodeField("dragonType", from: container)
        self.titleContent = try decodeField("titleContent", from: container)
        self.exampleContent = try decodeField("exampleContent", from: container)
        self.additionalContent = try decodeField("additionalContent", from: container)
        self.capacityLimit = try decodeField("capacityLimit", from: container)
        self.totalLimit = try decodeField("totalLimit", from: container)
        self.participantCount = try decodeField("participantCount", from: container)
        self.createUserId = try decodeField("createUserId", from: container)
        self.status = try decodeField("status", from: container)
        self.autoClose = try decodeField("autoClose", from: container)
        self.closeTime = try decodeField("closeTime", from: container)
        self.removeRepeat = try decodeField("removeRepeat", from: container)
    }
}

/// 接龙参与者
public struct DragonParticipantList: DynamicCodable {
    public var id: Int64?
    public var participantUserId: Int64?
    public var serialNumber: Int?     // 接龙序号
    public var dragonContent: String? // 接龙内容

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.participantUserId, forKey: "participantUserId", in: &container)
        try encodeAny(self.serialNumber, forKey: "serialNumber", in: &container)
        try encodeAny(self.dragonContent, forKey: "dragonContent", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.participantUserId = try decodeField("participantUserId", from: container)
        self.serialNumber = try decodeField("serialNumber", from: container)
        self.dragonContent = try decodeField("dragonContent", from: container)
    }
}


// MARK: - 接龙：参与

/// 参与接龙请求（标准 Codable）
public struct DragonParticipantListReq: Codable {
    public var id: Int64?                                    // 接龙主体 id
    public var removeRepeat: Bool?                           // 是否排重
    public var participantList: [DragonParticipantList]?     // 参与列表（仅当前登录用户）

    public init(id: Int64? = nil,
                removeRepeat: Bool?,
                participantList: [DragonParticipantList]?) {
        self.id = id
        self.removeRepeat = removeRepeat
        self.participantList = participantList
    }
}


// MARK: - 接龙：详情

/// 接龙详情响应
public struct DragonDetails: DynamicCodable {
    public var dragonDetailAll: DragonCreat?                  // 接龙主体
    public var dragonParticipantList: [DragonParticipantList]? // 参与列表

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.dragonDetailAll, forKey: "dragonDetailAll", in: &container)
        try encodeAny(self.dragonParticipantList, forKey: "dragonParticipantList", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.dragonDetailAll = try decodeField("dragonDetailAll", from: container)
        self.dragonParticipantList = try decodeField("dragonParticipantList", from: container)
    }
}
