//
//  GroupInfo.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/28.
//

import FTTool

// MARK: - 群地块分片状态

/// 群地块分片状态
public enum TGroupInfoLandShardStatus: Int, EnumCodable {
    public static var defaultCase: TGroupInfoLandShardStatus = .pending
    case pending = 0        // 待处理
    case inProgress = 1     // 进行中
    case completed = 2      // 已完成
    case cancelled = 3      // 已取消
    case profit = 4         // 已产生收益
}

// MARK: - 群类型

/// 群类型（普通群 / 地图群 / 活动群 / NFT 群 / 商机群 / 连接群 / 合约群 / 城市探索群 / 行业群）
/// ⚠️ 数值不连续（0~7，然后跳到 15），中间值被其他协议占用，不可重排
public enum TGroupInfoGroupType: Int, EnumCodable {
    public static var defaultCase: TGroupInfoGroupType = .normal
    case normal = 0
    case map = 1
    case activity = 2
    case nft = 3
    case businessOpportunity = 4
    case connection = 5
    case contract = 6
    case cityExplorer = 7
    case industryGroup = 15 // 行业群
}

// MARK: - 特殊群类型

/// 特殊群类型（群中群 / 群加群）
public enum TGroupInfoSpecialGroupType: Int, EnumCodable {
    public static var defaultCase: TGroupInfoSpecialGroupType = .notSpecial
    case notSpecial = 0
    case groupAddGroup = 1   // 群加群
    case groupInGroup = 2    // 群中群
}


// MARK: - 群信息总结构

/// 群信息聚合结构（由多个子资源组合）
/// - 每个子资源都是独立 DynamicCodable，默认构造为"零值对象"
/// - selected 是前端选择态，不是服务端数据
public struct TGroupInfoData: DynamicCodable {

    /// 群基础资源（名称/头像/群主/类型/限制等）
    public var groupResource = TGroupInfoGroupResource()
    /// 群通用资源（人数/各种开关/群类型/限制分钟数）
    public var commonResource = TGroupInfoCommonResource()
    /// 群活动资源
    public var activityResource = TGroupInfoActivityResource()
    /// 当前用户在群里的成员信息
    public var memberInfoResource = TGroupInfoMemberInfoResource()
    /// 当前用户与群的关系
    public var userGroupRelationResource = TGroupInfoUserGroupRelationResource()
    /// 群计数资源（热度等）
    public var groupCounterResource = TGroupInfoGroupCounterResource()
    /// 是否被选中（前端状态，服务端未必下发）
    public var selected = false
    /// 群地块资源
    public var groupLandResource = TGroupInfoGroupLandResource()

    public init() {}

    /// 编码：逐子资源写入
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.groupResource, forKey: "groupResource", in: &container)
        try encodeAny(self.commonResource, forKey: "commonResource", in: &container)
        try encodeAny(self.activityResource, forKey: "activityResource", in: &container)
        try encodeAny(self.memberInfoResource, forKey: "memberInfoResource", in: &container)
        try encodeAny(self.userGroupRelationResource, forKey: "userGroupRelationResource", in: &container)
        try encodeAny(self.groupCounterResource, forKey: "groupCounterResource", in: &container)
        try encodeAny(self.selected, forKey: "selected", in: &container)
        try encodeAny(self.groupLandResource, forKey: "groupLandResource", in: &container)
    }

    /// 解码：逐子资源硬解
    /// ⚠️ 严重风险：8 个子资源全部 `try decodeField`，服务端少下发任一（尤其
    ///    activityResource / groupLandResource / groupCounterResource 这类"非每个群都有"的资源）
    ///    就会让整个群信息解析失败、群详情全空。
    ///    建议：核心（groupResource / commonResource / memberInfoResource /
    ///    userGroupRelationResource）硬解，其余可选资源用 `decodeFieldIfPresent` + 默认值。
    ///    另外 `selected` 是前端状态，服务端很可能不下发，必须容错（缺省 false）。
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.groupResource = try decodeField("groupResource", from: container)
        self.commonResource = try decodeField("commonResource", from: container)
        self.activityResource = try decodeField("activityResource", from: container)
        self.memberInfoResource = try decodeField("memberInfoResource", from: container)
        self.userGroupRelationResource = try decodeField("userGroupRelationResource", from: container)
        self.groupCounterResource = try decodeField("groupCounterResource", from: container)
        // ⚠️ selected 为前端字段，建议改为 (try? decodeField) ?? false
        self.selected = try decodeField("selected", from: container)
        self.groupLandResource = try decodeField("groupLandResource", from: container)
    }
}


// MARK: - 群地块资源

/// 群关联的地块信息
public struct TGroupInfoGroupLandResource: DynamicCodable {
    public var groupID = ""
    public var landID: Int64 = 0
    public var landName = ""
    public var shardStatus: TGroupInfoLandShardStatus = .defaultCase

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.groupID, forKey: "groupId", in: &container)
        try encodeAny(self.landID, forKey: "landId", in: &container)
        try encodeAny(self.landName, forKey: "landName", in: &container)
        try encodeAny(self.shardStatus, forKey: "shardStatus", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.groupID = try decodeField("groupId", from: container)
        self.landID = try decodeField("landId", from: container)
        self.landName = try decodeField("landName", from: container)
        self.shardStatus = try decodeField("shardStatus", from: container)
    }
}


// MARK: - 群基础资源

/// 群基础信息
public struct TGroupInfoGroupResource: DynamicCodable {
    public var groupID = ""
    public var parentGroupId = ""

    /// 私有存储的群名称
    /// - 之所以包一层 _name，是为了让 `name` 与 `displayName` 共享同一份存储：
    ///   `name` 读写原值，`displayName` 读时优先返回群备注名
    private var _name = ""
    public var name: String {
        get { return _name }
        set { _name = newValue }
    }

    /// 展示用名称：有群备注(groupNoteName)时优先用备注，否则用原群名
    /// ⚠️ setter 写的是 `_name` 而不是 `groupNoteName`，
    ///    即"设置 displayName 会改群名"，语义易误导；建议去掉 setter 或改为只读
    public var displayName: String {
        get {
            if !groupNoteName.isEmpty {
                return groupNoteName
            }
            return _name
        }
        set {
            _name = newValue
        }
    }

    public var photo = ""
    public var groupNoteName: String = ""
    public var status: TGroupGetGroupStatus = .defaultCase
    public var masterID: Int64 = 0
    public var cityID: Int64 = 0
    public var tagIds = [Int64]()
    public var tags = [String]()
    public var description = ""
    public var createdAt: Int64 = 0
    public var updatedAt: Int64 = 0
    public var groupInGroup = false
    public var blackListMessage = ""
    public var blackListGroupBanSpeak = false
    public var adBackgroundImg = ""
    public var innerGroupIds = [String]()
    public var showGroupAddGroup = false
    public var specialGroupType: TGroupInfoSpecialGroupType = .defaultCase
    public var groupIcon: String = ""
    public var groupIdentity: String = ""
    /// 群功能限制（群中群 / 群加群 是否允许）
    public var functionLimit = GroupFunctionLimit()

    public init() {}

    /// 编码（注意 name 写的是 _name，不是 displayName）
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.groupID, forKey: "groupId", in: &container)
        try encodeAny(self.parentGroupId, forKey: "parentGroupId", in: &container)
        try encodeAny(self._name, forKey: "name", in: &container)
        try encodeAny(self.groupNoteName, forKey: "groupNoteName", in: &container)
        try encodeAny(self.photo, forKey: "photo", in: &container)
        try encodeAny(self.status, forKey: "status", in: &container)
        try encodeAny(self.masterID, forKey: "masterId", in: &container)
        try encodeAny(self.cityID, forKey: "cityId", in: &container)
        try encodeAny(self.tagIds, forKey: "tagIds", in: &container)
        try encodeAny(self.tags, forKey: "tags", in: &container)
        try encodeAny(self.description, forKey: "description", in: &container)
        try encodeAny(self.createdAt, forKey: "createdAt", in: &container)
        try encodeAny(self.updatedAt, forKey: "updatedAt", in: &container)
        try encodeAny(self.groupInGroup, forKey: "groupInGroup", in: &container)
        try encodeAny(self.blackListMessage, forKey: "blackListMessage", in: &container)
        try encodeAny(self.blackListGroupBanSpeak, forKey: "blackListGroupBanSpeak", in: &container)
        try encodeAny(self.adBackgroundImg, forKey: "adBackgroundImg", in: &container)
        try encodeAny(self.innerGroupIds, forKey: "innerGroupIds", in: &container)
        try encodeAny(self.showGroupAddGroup, forKey: "showGroupAddGroup", in: &container)
        try encodeAny(self.specialGroupType, forKey: "specialGroupType", in: &container)
        try encodeAny(self.groupIcon, forKey: "groupIcon", in: &container)
        try encodeAny(self.groupIdentity, forKey: "groupIdentity", in: &container)
        try encodeAny(self.functionLimit, forKey: "functionLimit", in: &container)
    }

    /// 解码（硬解，缺字段即失败）
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.groupID = try decodeField("groupId", from: container)
        self.parentGroupId = try decodeField("parentGroupId", from: container)
        self._name = try decodeField("name", from: container)
        self.groupNoteName = try decodeField("groupNoteName", from: container)
        self.photo = try decodeField("photo", from: container)
        self.status = try decodeField("status", from: container)
        self.masterID = try decodeField("masterId", from: container)
        self.cityID = try decodeField("cityId", from: container)
        self.tagIds = try decodeField("tagIds", from: container)
        self.tags = try decodeField("tags", from: container)
        self.description = try decodeField("description", from: container)
        self.createdAt = try decodeField("createdAt", from: container)
        self.updatedAt = try decodeField("updatedAt", from: container)
        self.groupInGroup = try decodeField("groupInGroup", from: container)
        self.blackListMessage = try decodeField("blackListMessage", from: container)
        self.blackListGroupBanSpeak = try decodeField("blackListGroupBanSpeak", from: container)
        self.adBackgroundImg = try decodeField("adBackgroundImg", from: container)
        self.innerGroupIds = try decodeField("innerGroupIds", from: container)
        self.showGroupAddGroup = try decodeField("showGroupAddGroup", from: container)
        self.specialGroupType = try decodeField("specialGroupType", from: container)
        self.groupIcon = try decodeField("groupIcon", from: container)
        self.groupIdentity = try decodeField("groupIdentity", from: container)
        self.functionLimit = try decodeField("functionLimit", from: container)
    }
}


// MARK: - 群通用资源

/// 群通用配置（人数 / 各类开关 / 群类型 / 限制）
/// ⚠️ 开关字段极多且分属不同枚举类型，阅读/扩展时需逐个核对
public struct TGroupInfoCommonResource: DynamicCodable {
    public var groupID = ""
    public var memberCount = 0
    public var femaleMemberCount = 0
    public var joinApplySwitch: TGroupGetJoinApplySwitchType = .defaultCase
    public var publicSwitch: TGroupSwitchPutPublicSwitchType = .defaultCase
    public var atAllSwitch: TGroupSwitchPutSwitchType = .defaultCase
    public var inviteSwitch: TGroupSwitchPutSwitchType = .defaultCase
    /// 关联信息版本（[String: Any] 动态字典，靠 encodeAny 处理）
    public var relatedInfoVersion = [String: Any]()
    public var allMembersMuteSwitch: TGroupSwitchPutAllMembersMuteSwitchType = .defaultCase
    public var leaderIds = [Int64]()
    public var prohibitAddFriendSwitchType: TGroupSwitchPutProhibitAddFriendSwitchType = .defaultCase
    public var historyMessageCount: TGroupSwitchPutHistoryMessageCountType = .defaultCase
    public var prohibitSendLinkSwitch: TGroupSwitchPutProhibitType = .defaultCase
    public var prohibitSendQRCodeSwitch: TGroupSwitchPutProhibitType = .defaultCase
    public var prohibitModifyNameSwitchType: TGroupSwitchPutProhibitType = .defaultCase
    public var typeID = ""
    public var groupType: TGroupInfoGroupType = .defaultCase
    public var adBannerSwitch: TGroupSwitchPutAdBannerSwitchType = .defaultCase
    public var bannerBackgroundUrl: String = ""
    public var backgroundSwitch: TGroupSwitchPutAdBannerSwitchType = .defaultCase
    public var managementBusinessSwitch: TGroupSwitchType = .defaultCase
    public var aiAssistantEnabled = false
    public var limitMinutes: Int = 0

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.groupID, forKey: "groupId", in: &container)
        try encodeAny(self.memberCount, forKey: "memberCount", in: &container)
        try encodeAny(self.femaleMemberCount, forKey: "femaleMemberCount", in: &container)
        try encodeAny(self.joinApplySwitch, forKey: "joinApplySwitch", in: &container)
        try encodeAny(self.publicSwitch, forKey: "publicSwitch", in: &container)
        try encodeAny(self.atAllSwitch, forKey: "atAllSwitch", in: &container)
        try encodeAny(self.inviteSwitch, forKey: "inviteSwitch", in: &container)
        try encodeAny(self.relatedInfoVersion, forKey: "relatedInfoVersion", in: &container)
        try encodeAny(self.allMembersMuteSwitch, forKey: "allMembersMuteSwitch", in: &container)
        try encodeAny(self.leaderIds, forKey: "leaderIds", in: &container)
        try encodeAny(self.prohibitAddFriendSwitchType, forKey: "prohibitAddFriendSwitchType", in: &container)
        try encodeAny(self.historyMessageCount, forKey: "historyMessageCount", in: &container)
        try encodeAny(self.prohibitSendLinkSwitch, forKey: "prohibitSendLinkSwitch", in: &container)
        try encodeAny(self.prohibitSendQRCodeSwitch, forKey: "prohibitSendQRCodeSwitch", in: &container)
        try encodeAny(self.prohibitModifyNameSwitchType, forKey: "prohibitModifyNameSwitchType", in: &container)
        try encodeAny(self.typeID, forKey: "typeId", in: &container)
        try encodeAny(self.groupType, forKey: "groupType", in: &container)
        try encodeAny(self.adBannerSwitch, forKey: "adBannerSwitch", in: &container)
        try encodeAny(self.bannerBackgroundUrl, forKey: "bannerBackgroundUrl", in: &container)
        try encodeAny(self.backgroundSwitch, forKey: "backgroundSwitch", in: &container)
        try encodeAny(self.managementBusinessSwitch, forKey: "managementBusinessSwitch", in: &container)
        try encodeAny(self.aiAssistantEnabled, forKey: "aiAssistantEnabled", in: &container)
        try encodeAny(self.limitMinutes, forKey: "limitMinutes", in: &container)
    }

    /// 解码（硬解）
    /// ⚠️ `relatedInfoVersion` 是 [String: Any]，服务端缺省或结构不符会抛错，
    ///    建议对该字段容错（缺省空字典）
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.groupID = try decodeField("groupId", from: container)
        self.memberCount = try decodeField("memberCount", from: container)
        self.femaleMemberCount = try decodeField("femaleMemberCount", from: container)
        self.joinApplySwitch = try decodeField("joinApplySwitch", from: container)
        self.publicSwitch = try decodeField("publicSwitch", from: container)
        self.atAllSwitch = try decodeField("atAllSwitch", from: container)
        self.inviteSwitch = try decodeField("inviteSwitch", from: container)
        self.relatedInfoVersion = try decodeField("relatedInfoVersion", from: container)
        self.allMembersMuteSwitch = try decodeField("allMembersMuteSwitch", from: container)
        self.leaderIds = try decodeField("leaderIds", from: container)
        self.prohibitAddFriendSwitchType = try decodeField("prohibitAddFriendSwitchType", from: container)
        self.historyMessageCount = try decodeField("historyMessageCount", from: container)
        self.prohibitSendLinkSwitch = try decodeField("prohibitSendLinkSwitch", from: container)
        self.prohibitSendQRCodeSwitch = try decodeField("prohibitSendQRCodeSwitch", from: container)
        self.prohibitModifyNameSwitchType = try decodeField("prohibitModifyNameSwitchType", from: container)
        self.typeID = try decodeField("typeId", from: container)
        self.groupType = try decodeField("groupType", from: container)
        self.adBannerSwitch = try decodeField("adBannerSwitch", from: container)
        self.bannerBackgroundUrl = try decodeField("bannerBackgroundUrl", from: container)
        self.backgroundSwitch = try decodeField("backgroundSwitch", from: container)
        self.managementBusinessSwitch = try decodeField("managementBusinessSwitch", from: container)
        self.aiAssistantEnabled = try decodeField("aiAssistantEnabled", from: container)
        self.limitMinutes = try decodeField("limitMinutes", from: container)
    }
}


// MARK: - 群活动资源

/// 群关联活动
public struct TGroupInfoActivityResource: DynamicCodable {
    public var groupID = ""
    public var activityID: Int64 = 0
    public var activityName = ""
    public var category = ""
    public var activitySize = 0
    public var state = ""

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.groupID, forKey: "groupId", in: &container)
        try encodeAny(self.activityID, forKey: "activityId", in: &container)
        try encodeAny(self.activityName, forKey: "activityName", in: &container)
        try encodeAny(self.category, forKey: "category", in: &container)
        try encodeAny(self.activitySize, forKey: "activitySize", in: &container)
        try encodeAny(self.state, forKey: "state", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.groupID = try decodeField("groupId", from: container)
        self.activityID = try decodeField("activityId", from: container)
        self.activityName = try decodeField("activityName", from: container)
        self.category = try decodeField("category", from: container)
        self.activitySize = try decodeField("activitySize", from: container)
        self.state = try decodeField("state", from: container)
    }
}


// MARK: - 群成员信息

/// 当前用户在群内的成员信息
public struct TGroupInfoMemberInfoResource: DynamicCodable {
    public var groupID = ""
    public var userID: Int64 = 0
    public var noteName = ""
    public var identity: TGroupMemberTypeGroupMemberType = .defaultCase
    public var recentMemberIds = [Int64]()

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.groupID, forKey: "groupId", in: &container)
        try encodeAny(self.userID, forKey: "userId", in: &container)
        try encodeAny(self.noteName, forKey: "noteName", in: &container)
        try encodeAny(self.identity, forKey: "identity", in: &container)
        try encodeAny(self.recentMemberIds, forKey: "recentMemberIds", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.groupID = try decodeField("groupId", from: container)
        self.userID = try decodeField("userId", from: container)
        self.noteName = try decodeField("noteName", from: container)
        self.identity = try decodeField("identity", from: container)
        self.recentMemberIds = try decodeField("recentMemberIds", from: container)
    }
}


// MARK: - 用户与群关系

/// 当前用户与群的关系
public struct TGroupInfoUserGroupRelationResource: DynamicCodable {
    public var groupID = ""
    public var userGroupRelation: TGroupGetUserGroupRelationType = .defaultCase

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.groupID, forKey: "groupId", in: &container)
        try encodeAny(self.userGroupRelation, forKey: "userGroupRelation", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.groupID = try decodeField("groupId", from: container)
        self.userGroupRelation = try decodeField("userGroupRelation", from: container)
    }
}


// MARK: - 群计数资源

/// 群热度等计数
public struct TGroupInfoGroupCounterResource: DynamicCodable {
    public var groupID = ""
    public var hotValue: Int64 = 0

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.groupID, forKey: "groupId", in: &container)
        try encodeAny(self.hotValue, forKey: "hotValue", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.groupID = try decodeField("groupId", from: container)
        self.hotValue = try decodeField("hotValue", from: container)
    }
}


// MARK: - 分组消息列表类型

/// 分组内消息列表的分类
public enum TGroupingInfoMessageListType: Int, EnumCodable {
    public static var defaultCase: TGroupingInfoMessageListType = .unknown
    case unknown = 0
    case normal = 1
    case stick = 2
    case notification = 3
}

// MARK: - 分组信息

/// 好友分组信息（分组名/密码/人数等）
public struct TGroupingInfoMessageGroupingInfoMessage: DynamicCodable {
    public var id = ""
    public var name = ""
    public var password = ""
    public var updatedAt: Int64 = 0
    public var createdAt: Int64 = 0
    public var listType: TGroupingInfoMessageListType = .defaultCase
    public var personTotal: Int64 = 0

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.name, forKey: "name", in: &container)
        try encodeAny(self.password, forKey: "password", in: &container)
        try encodeAny(self.updatedAt, forKey: "updatedAt", in: &container)
        try encodeAny(self.createdAt, forKey: "createdAt", in: &container)
        try encodeAny(self.listType, forKey: "listType", in: &container)
        try encodeAny(self.personTotal, forKey: "personTotal", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.name = try decodeField("name", from: container)
        self.password = try decodeField("password", from: container)
        self.updatedAt = try decodeField("updatedAt", from: container)
        self.createdAt = try decodeField("createdAt", from: container)
        self.listType = try decodeField("listType", from: container)
        self.personTotal = try decodeField("personTotal", from: container)
    }
}


// MARK: - 群功能限制

/// 群功能限制开关（群中群 / 群加群）
/// - 用 Int64 而非 Bool：0 禁止 / 1 允许，默认均为允许(1)
public struct GroupFunctionLimit: DynamicCodable {
    /// 群中群功能：0 禁止 / 1 允许
    public var innerGroup: Int64 = 1
    /// 群加群功能：0 禁止 / 1 允许
    public var mergeGroup: Int64 = 1

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.innerGroup, forKey: "innerGroup", in: &container)
        try encodeAny(self.mergeGroup, forKey: "mergeGroup", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.innerGroup = try decodeField("innerGroup", from: container)
        self.mergeGroup = try decodeField("mergeGroup", from: container)
    }
}
