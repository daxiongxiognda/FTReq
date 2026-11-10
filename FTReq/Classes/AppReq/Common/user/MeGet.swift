//
//  MeGet.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/28.
//

import FTTool

// MARK: - 用户总数据

/// 用户聚合数据模型（"Me" 接口返回体）
/// - 遵循 `DynamicCodable`：手动映射 JSON 字段
/// - 遵循 `Modelable`：通用模型能力（如 tottJson 等）
/// - 由多个子资源组合而成，每个子资源都可能为空（默认构造的零值对象）
public struct TMeGetData: DynamicCodable {

    /// 用户基础资源（id、昵称、性别、注册信息等）
    public var userResource = TMeGetUserResource()
    /// 用户资料资源（头像、简介、地区、公司等）
    public var userProfileResource = TMeGetUserProfileResource()
    /// 用户账号资源（账号 id、账号类型等）
    public var userAccountResource = TMeGetUserAccountResource()
    /// 用户通用属性资源（邀请人、标签、IM token、公钥）
    public var userCommonPropertyResource = TMeGetUserCommonPropertyResource()
    /// 好友信息资源（好友关系、分组、好友申请数）
    public var userFriendInfoResource = TMeGetUserFriendInfoResource()
    /// 用户设置资源（各类通知开关、隐私开关）
    public var userSettingPropertyResource = TMeGetUserSettingPropertyResource()
    /// 关注资源（关注/粉丝数）
    public var userFollowingResource = TMeGetUserFollowingResource()
    /// AI 角色资源（AI 角色名、形象、语音参数）
    public var aiRoleResource = TMeGetAiRoleResource()
    /// UGC 资源（动态/视频/商品/地皮等计数）
    public var userUgcResource = TMeGetUserUgcResource()
    /// 钱包资源（通宝/通钻/现金及分红）
    public var userWalletPropertyResource = TMeGetUserWalletPropertyResource()
    /// 邀请资源（绑定邀请码）
    public var userInviteResource = TMeGetUserInviteResource()
    /// 拉黑信息资源
    public var userBlockInfoResource = TMeGetUserBlockInfoResource()
    /// UGC 拉黑响应
    public var ugcUserBlockResponse = TMeGetUgcUserBlockResponse()
    /// UGC 限制响应
    public var ugcUserRestrictResponse = TMeGetUgcUserRestrictResponse()
    /// 历史限制响应
    public var hisRestrictResponse = TMeGetHisRestrictResponse()
    /// 用户备注资源（备注名、手机号）
    public var userNoteResource = TMeGetUserNoteResource()
    /// 用户额外资源（实名认证状态等）
    public var userExtraResource = TMeGetUserExtraResource()
    /// Web3 资产
    public var userWeb3Response = TMeGetUserWeb3Response()
    /// 朋友圈资源（动态数）
    public var userFriendCircleResource = TMeGetUserFriendCircleResource()
    /// 用户群资源（展示群数）
    public var userGroupResource = TMeGetUserGroupResource()
    /// AI 分身资源
    public var userAiCloneResource = TMeGetUserAiCloneResource()
    /// VIP 资源
    public var userVipResource = TMeGetUserVipResource()

    // MARK: - has 判定
    // 每个子资源用"关键 id > 0"判断是否有效。
    // ⚠️ 注意：
    //   1. 子资源是值类型且默认构造，未下发时是"零值对象"而非 nil，
    //      因此只能靠 id>0 等业务判据区分"有/无"。
    //   2. 不同子资源的判据字段不一致（id / block.id / restrict.id /
    //      assetList.isEmpty / dynamicCount / showGroupCount / aiUID / userID），
    //      新增子资源时必须同步补 has 逻辑，容易漏。

    public var hasUserResource: Bool { return userResource.id > 0 }
    public var hasUserProfileResource: Bool { return userProfileResource.id > 0 }
    public var hasUserAccountResource: Bool { return userAccountResource.id > 0 }
    public var hasUserCommonPropertyResource: Bool { return userCommonPropertyResource.id > 0 }
    public var hasUserFriendInfoResource: Bool { return userFriendInfoResource.id > 0 }
    public var hasUserSettingPropertyResource: Bool { return userSettingPropertyResource.id > 0 }
    public var hasUserFollowingResource: Bool { return userFollowingResource.id > 0 }
    public var hasAiRoleResource: Bool { return aiRoleResource.id > 0 }
    public var hasUserUgcResource: Bool { return userUgcResource.id > 0 }
    public var hasUserWalletPropertyResource: Bool { return userWalletPropertyResource.id > 0 }
    public var hasUserInviteResource: Bool { return userInviteResource.id > 0 }
    public var hasUserBlockInfoResource: Bool { return userBlockInfoResource.id > 0 }
    /// ⚠️ 用 block.id 判据
    public var hasUgcUserBlockResponse: Bool { return ugcUserBlockResponse.block.id > 0 }
    /// ⚠️ 用 restrict.id 判据
    public var hasUgcUserRestrictResponse: Bool { return ugcUserRestrictResponse.restrict.id > 0 }
    public var hasHisRestrictResponse: Bool { return hisRestrictResponse.restrict.id > 0 }
    public var hasUserNoteResource: Bool { return userNoteResource.id > 0 }
    public var hasUserExtraResource: Bool { return userExtraResource.id > 0 }
    /// ⚠️ 用 assetList 非空判据
    public var hasUserWeb3Response: Bool { return !userWeb3Response.assetList.isEmpty }
    /// ⚠️ 用 dynamicCount > 0 判据
    public var hasUserFriendCircleResource: Bool { return userFriendCircleResource.dynamicCount > 0 }
    /// ⚠️ 用 showGroupCount > 0 判据
    public var hasUserGroupResource: Bool { return userGroupResource.showGroupCount > 0 }
    /// ⚠️ 用 aiUID > 0 判据
    public var hasUserAiCloneResource: Bool { return userAiCloneResource.aiUID > 0 }
    /// ⚠️ 用 userID > 0 判据
    public var hasUserVipResource: Bool { return userVipResource.userID > 0 }

    public init() {}

    // MARK: - 编码

    /// 编码：逐字段写入 container
    /// ⚠️ 22 个子资源全部无条件写出（即使为空值对象），
    ///    上报/缓存时会带大量零值字段，payload 偏大；
    ///    但 decode 是硬解，全写可保证字段齐全，是"以空间换健壮"的取舍。
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.userResource, forKey: "userResource", in: &container)
        try encodeAny(self.userProfileResource, forKey: "userProfileResource", in: &container)
        try encodeAny(self.userAccountResource, forKey: "userAccountResource", in: &container)
        try encodeAny(self.userCommonPropertyResource, forKey: "userCommonPropertyResource", in: &container)
        try encodeAny(self.userFriendInfoResource, forKey: "userFriendInfoResource", in: &container)
        try encodeAny(self.userSettingPropertyResource, forKey: "userSettingPropertyResource", in: &container)
        try encodeAny(self.userFollowingResource, forKey: "userFollowingResource", in: &container)
        try encodeAny(self.aiRoleResource, forKey: "aiRoleResource", in: &container)
        try encodeAny(self.userUgcResource, forKey: "userUgcResource", in: &container)
        try encodeAny(self.userWalletPropertyResource, forKey: "userWalletPropertyResource", in: &container)
        try encodeAny(self.userInviteResource, forKey: "userInviteResource", in: &container)
        try encodeAny(self.userBlockInfoResource, forKey: "userBlockInfoResource", in: &container)
        try encodeAny(self.ugcUserBlockResponse, forKey: "ugcUserBlockResponse", in: &container)
        try encodeAny(self.ugcUserRestrictResponse, forKey: "ugcUserRestrictResponse", in: &container)
        try encodeAny(self.hisRestrictResponse, forKey: "hisRestrictResponse", in: &container)
        try encodeAny(self.userNoteResource, forKey: "userNoteResource", in: &container)
        try encodeAny(self.userExtraResource, forKey: "userExtraResource", in: &container)
        try encodeAny(self.userWeb3Response, forKey: "userWeb3Response", in: &container)
        try encodeAny(self.userFriendCircleResource, forKey: "userFriendCircleResource", in: &container)
        try encodeAny(self.userGroupResource, forKey: "userGroupResource", in: &container)
        try encodeAny(self.userAiCloneResource, forKey: "userAiCloneResource", in: &container)
        try encodeAny(self.userVipResource, forKey: "userVipResource", in: &container)
    }

    // MARK: - 解码

    /// 解码：逐字段硬解
    /// ⚠️ 严重风险：22 个子资源全部 `try decodeField`，
    ///    只要服务端少下发任意一个（或某个子资源内部字段不匹配），
    ///    整个用户数据解析失败 → 用户信息全空。
    ///    用户主数据是高频、关键数据，建议至少对"非核心子资源"做容错：
    ///    - 核心：userResource / userProfileResource / userAccountResource
    ///    - 可选：wallet / web3 / aiRole / vip / 各 restrict 等，
    ///      用 `decodeFieldIfPresent` + 默认值，避免一个可选字段拖垮整体。
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.userResource = try decodeField("userResource", from: container)
        self.userProfileResource = try decodeField("userProfileResource", from: container)
        self.userAccountResource = try decodeField("userAccountResource", from: container)
        self.userCommonPropertyResource = try decodeField("userCommonPropertyResource", from: container)
        self.userFriendInfoResource = try decodeField("userFriendInfoResource", from: container)
        self.userSettingPropertyResource = try decodeField("userSettingPropertyResource", from: container)
        self.userFollowingResource = try decodeField("userFollowingResource", from: container)
        self.aiRoleResource = try decodeField("aiRoleResource", from: container)
        self.userUgcResource = try decodeField("userUgcResource", from: container)
        self.userWalletPropertyResource = try decodeField("userWalletPropertyResource", from: container)
        self.userInviteResource = try decodeField("userInviteResource", from: container)
        self.userBlockInfoResource = try decodeField("userBlockInfoResource", from: container)
        self.ugcUserBlockResponse = try decodeField("ugcUserBlockResponse", from: container)
        self.ugcUserRestrictResponse = try decodeField("ugcUserRestrictResponse", from: container)
        self.hisRestrictResponse = try decodeField("hisRestrictResponse", from: container)
        self.userNoteResource = try decodeField("userNoteResource", from: container)
        self.userExtraResource = try decodeField("userExtraResource", from: container)
        self.userWeb3Response = try decodeField("userWeb3Response", from: container)
        self.userFriendCircleResource = try decodeField("userFriendCircleResource", from: container)
        self.userGroupResource = try decodeField("userGroupResource", from: container)
        self.userAiCloneResource = try decodeField("userAiCloneResource", from: container)
        self.userVipResource = try decodeField("userVipResource", from: container)
    }
}


// MARK: - 用户基础资源

/// 用户基础信息
public struct TMeGetUserResource: DynamicCodable {
    public var id: Int64 = 0
    public var firstName = ""
    public var phoneNumber = ""
    public var nationalPhoneNumber = ""
    public var gender: TGenderGender = .defaultCase
    public var birthday = ""
    public var deletedAt: Int64 = 0
    public var deleted = false
    public var appType: TAppTypeAppType = .defaultCase
    public var loginType: TLoginTypeLoginType = .defaultCase
    public var registerDays: Int64 = 0
    public var imUserID = ""
    public var payPasswordStatus = false
    public var shareLink = ""
    public var uniqueName = ""
    public var aiRole = false
    public var type: TRoleTypeRoleType = .defaultCase
    public var ttID = ""
    public var aiRoleType: TRoleTypeAiRoleType = .defaultCase
    public var aiOwnerID: Int64 = 0
    public var idMap = TMeGetIdMap()
    public var blackListMessage = ""
    public var blackListUserBanSpeak = false
    public var iconUrl: String = ""
    /// 是否为靓号 false:否 true:是
    public var vanityFlag = false

    public init() {}

    /// 编码（25 个字段，JSON key 小驼峰，ID→Id 转换）
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.firstName, forKey: "firstName", in: &container)
        try encodeAny(self.phoneNumber, forKey: "phoneNumber", in: &container)
        try encodeAny(self.nationalPhoneNumber, forKey: "nationalPhoneNumber", in: &container)
        try encodeAny(self.gender, forKey: "gender", in: &container)
        try encodeAny(self.birthday, forKey: "birthday", in: &container)
        try encodeAny(self.deletedAt, forKey: "deletedAt", in: &container)
        try encodeAny(self.deleted, forKey: "deleted", in: &container)
        try encodeAny(self.appType, forKey: "appType", in: &container)
        try encodeAny(self.loginType, forKey: "loginType", in: &container)
        try encodeAny(self.registerDays, forKey: "registerDays", in: &container)
        try encodeAny(self.imUserID, forKey: "imUserId", in: &container)
        try encodeAny(self.payPasswordStatus, forKey: "payPasswordStatus", in: &container)
        try encodeAny(self.shareLink, forKey: "shareLink", in: &container)
        try encodeAny(self.uniqueName, forKey: "uniqueName", in: &container)
        try encodeAny(self.aiRole, forKey: "aiRole", in: &container)
        try encodeAny(self.type, forKey: "type", in: &container)
        try encodeAny(self.ttID, forKey: "ttId", in: &container)
        try encodeAny(self.aiRoleType, forKey: "aiRoleType", in: &container)
        try encodeAny(self.aiOwnerID, forKey: "aiOwnerId", in: &container)
        try encodeAny(self.idMap, forKey: "idMap", in: &container)
        try encodeAny(self.blackListMessage, forKey: "blackListMessage", in: &container)
        try encodeAny(self.blackListUserBanSpeak, forKey: "blackListUserBanSpeak", in: &container)
        try encodeAny(self.iconUrl, forKey: "iconUrl", in: &container)
        try encodeAny(self.vanityFlag, forKey: "vanityFlag", in: &container)
    }

    /// 解码（硬解，缺字段即失败）
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.firstName = try decodeField("firstName", from: container)
        self.phoneNumber = try decodeField("phoneNumber", from: container)
        self.nationalPhoneNumber = try decodeField("nationalPhoneNumber", from: container)
        self.gender = try decodeField("gender", from: container)
        self.birthday = try decodeField("birthday", from: container)
        self.deletedAt = try decodeField("deletedAt", from: container)
        self.deleted = try decodeField("deleted", from: container)
        self.appType = try decodeField("appType", from: container)
        self.loginType = try decodeField("loginType", from: container)
        self.registerDays = try decodeField("registerDays", from: container)
        self.imUserID = try decodeField("imUserId", from: container)
        self.payPasswordStatus = try decodeField("payPasswordStatus", from: container)
        self.shareLink = try decodeField("shareLink", from: container)
        self.uniqueName = try decodeField("uniqueName", from: container)
        self.aiRole = try decodeField("aiRole", from: container)
        self.type = try decodeField("type", from: container)
        self.ttID = try decodeField("ttId", from: container)
        self.aiRoleType = try decodeField("aiRoleType", from: container)
        self.aiOwnerID = try decodeField("aiOwnerId", from: container)
        self.idMap = try decodeField("idMap", from: container)
        self.blackListMessage = try decodeField("blackListMessage", from: container)
        self.blackListUserBanSpeak = try decodeField("blackListUserBanSpeak", from: container)
        self.iconUrl = try decodeField("iconUrl", from: container)
        self.vanityFlag = try decodeField("vanityFlag", from: container)
    }
}


// MARK: - id 映射

/// 通用 id 键值对
public struct TMeGetIdMap: DynamicCodable {
    public var idKey = ""
    public var idValue = ""

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.idKey, forKey: "idKey", in: &container)
        try encodeAny(self.idValue, forKey: "idValue", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.idKey = try decodeField("idKey", from: container)
        self.idValue = try decodeField("idValue", from: container)
    }
}


// MARK: - 用户资料资源

/// 用户资料（头像、地区、简介、公司等）
public struct TMeGetUserProfileResource: DynamicCodable {
    public var id: Int64 = 0
    public var timezone = 0
    public var latitude = 0.0
    public var longitude = 0.0
    public var country = ""
    public var state = ""
    public var city = ""
    public var ip = ""
    public var bio = ""
    public var deviceType: TDeviceTypeDeviceType = .defaultCase
    public var appLang = ""
    public var appVersion = ""
    public var avatarURL = ""
    public var thumbPortraitURL = ""
    public var deviceID = ""
    public var avatarStatus = 0
    public var aliPayAccount = ""
    public var aliPayName = ""
    public var friendCircleBgURL = ""
    public var personalImageURL = ""
    public var personalSign = ""
    public var chatBackgroundImage = ""
    public var phones = [String]()
    public var email = ""
    public var companyName = ""
    public var jobName = ""
    public var companyAddress = ""
    public var companySlogan = ""
    public var inviteCode = ""
    public var clapOneClap = ""
    /// 商业角色类型（可选，未下发为 nil）
    public var businessRoleType: Int?

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.timezone, forKey: "timezone", in: &container)
        try encodeAny(self.latitude, forKey: "latitude", in: &container)
        try encodeAny(self.longitude, forKey: "longitude", in: &container)
        try encodeAny(self.country, forKey: "country", in: &container)
        try encodeAny(self.state, forKey: "state", in: &container)
        try encodeAny(self.city, forKey: "city", in: &container)
        try encodeAny(self.ip, forKey: "ip", in: &container)
        try encodeAny(self.bio, forKey: "bio", in: &container)
        try encodeAny(self.deviceType, forKey: "deviceType", in: &container)
        try encodeAny(self.appLang, forKey: "appLang", in: &container)
        try encodeAny(self.appVersion, forKey: "appVersion", in: &container)
        try encodeAny(self.avatarURL, forKey: "avatarUrl", in: &container)
        try encodeAny(self.thumbPortraitURL, forKey: "thumbPortraitUrl", in: &container)
        try encodeAny(self.deviceID, forKey: "deviceId", in: &container)
        try encodeAny(self.avatarStatus, forKey: "avatarStatus", in: &container)
        try encodeAny(self.aliPayAccount, forKey: "aliPayAccount", in: &container)
        try encodeAny(self.aliPayName, forKey: "aliPayName", in: &container)
        try encodeAny(self.friendCircleBgURL, forKey: "friendCircleBgUrl", in: &container)
        try encodeAny(self.personalImageURL, forKey: "personalImageUrl", in: &container)
        try encodeAny(self.personalSign, forKey: "personalSign", in: &container)
        try encodeAny(self.chatBackgroundImage, forKey: "chatBackgroundImage", in: &container)
        try encodeAny(self.phones, forKey: "phones", in: &container)
        try encodeAny(self.email, forKey: "email", in: &container)
        try encodeAny(self.companyName, forKey: "companyName", in: &container)
        try encodeAny(self.jobName, forKey: "jobName", in: &container)
        try encodeAny(self.companyAddress, forKey: "companyAddress", in: &container)
        try encodeAny(self.companySlogan, forKey: "companySlogan", in: &container)
        try encodeAny(self.inviteCode, forKey: "inviteCode", in: &container)
        try encodeAny(self.clapOneClap, forKey: "clapOneClap", in: &container)
        try encodeAny(self.businessRoleType, forKey: "businessRoleType", in: &container)
    }

    /// ⚠️ businessRoleType 是可选 Int，硬解时若服务端未下发会抛错，
    ///    导致整个资料资源解析失败。建议改为 decodeFieldIfPresent。
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.timezone = try decodeField("timezone", from: container)
        self.latitude = try decodeField("latitude", from: container)
        self.longitude = try decodeField("longitude", from: container)
        self.country = try decodeField("country", from: container)
        self.state = try decodeField("state", from: container)
        self.city = try decodeField("city", from: container)
        self.ip = try decodeField("ip", from: container)
        self.bio = try decodeField("bio", from: container)
        self.deviceType = try decodeField("deviceType", from: container)
        self.appLang = try decodeField("appLang", from: container)
        self.appVersion = try decodeField("appVersion", from: container)
        self.avatarURL = try decodeField("avatarUrl", from: container)
        self.thumbPortraitURL = try decodeField("thumbPortraitUrl", from: container)
        self.deviceID = try decodeField("deviceId", from: container)
        self.avatarStatus = try decodeField("avatarStatus", from: container)
        self.aliPayAccount = try decodeField("aliPayAccount", from: container)
        self.aliPayName = try decodeField("aliPayName", from: container)
        self.friendCircleBgURL = try decodeField("friendCircleBgUrl", from: container)
        self.personalImageURL = try decodeField("personalImageUrl", from: container)
        self.personalSign = try decodeField("personalSign", from: container)
        self.chatBackgroundImage = try decodeField("chatBackgroundImage", from: container)
        self.phones = try decodeField("phones", from: container)
        self.email = try decodeField("email", from: container)
        self.companyName = try decodeField("companyName", from: container)
        self.jobName = try decodeField("jobName", from: container)
        self.companyAddress = try decodeField("companyAddress", from: container)
        self.companySlogan = try decodeField("companySlogan", from: container)
        self.inviteCode = try decodeField("inviteCode", from: container)
        self.clapOneClap = try decodeField("clapOneClap", from: container)
        self.businessRoleType = try decodeField("businessRoleType", from: container)
    }
}


// MARK: - 用户账号资源

/// 用户账号信息
public struct TMeGetUserAccountResource: DynamicCodable {
    public var id: Int64 = 0
    public var accountID = ""
    public var accountType: TAccountTypeAccountType = .defaultCase
    public var gender: TGenderGender = .defaultCase
    public var picture = ""

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.accountID, forKey: "accountId", in: &container)
        try encodeAny(self.accountType, forKey: "accountType", in: &container)
        try encodeAny(self.gender, forKey: "gender", in: &container)
        try encodeAny(self.picture, forKey: "picture", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.accountID = try decodeField("accountId", from: container)
        self.accountType = try decodeField("accountType", from: container)
        self.gender = try decodeField("gender", from: container)
        self.picture = try decodeField("picture", from: container)
    }
}


// MARK: - 用户通用属性资源

/// 通用属性（邀请人、标签、IM token、公钥）
public struct TMeGetUserCommonPropertyResource: DynamicCodable {
    public var id: Int64 = 0
    public var inviterID: Int64 = 0
    public var tagIds = [Int64]()
    public var imUserToken = ""
    public var publicKey = ""

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.inviterID, forKey: "inviterId", in: &container)
        try encodeAny(self.tagIds, forKey: "tagIds", in: &container)
        try encodeAny(self.imUserToken, forKey: "imUserToken", in: &container)
        try encodeAny(self.publicKey, forKey: "publicKey", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.inviterID = try decodeField("inviterId", from: container)
        self.tagIds = try decodeField("tagIds", from: container)
        self.imUserToken = try decodeField("imUserToken", from: container)
        self.publicKey = try decodeField("publicKey", from: container)
    }
}


// MARK: - 好友信息资源

/// 好友关系信息
public struct TMeGetUserFriendInfoResource: DynamicCodable {
    public var id: Int64 = 0
    public var friendUserID: Int64 = 0
    public var groupingID = ""
    public var newFriendApplyNum: Int64 = 0
    public var friendRelationType: TFriendRelationTypeFriendRelationType = .defaultCase
    public var newFriendApplyAvatarURL = [String]()

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.friendUserID, forKey: "friendUserId", in: &container)
        try encodeAny(self.groupingID, forKey: "groupingId", in: &container)
        try encodeAny(self.newFriendApplyNum, forKey: "newFriendApplyNum", in: &container)
        try encodeAny(self.friendRelationType, forKey: "friendRelationType", in: &container)
        try encodeAny(self.newFriendApplyAvatarURL, forKey: "newFriendApplyAvatarUrl", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.friendUserID = try decodeField("friendUserId", from: container)
        self.groupingID = try decodeField("groupingId", from: container)
        self.newFriendApplyNum = try decodeField("newFriendApplyNum", from: container)
        self.friendRelationType = try decodeField("friendRelationType", from: container)
        self.newFriendApplyAvatarURL = try decodeField("newFriendApplyAvatarUrl", from: container)
    }
}


// MARK: - 用户设置资源

/// 用户设置（通知/隐私开关 + 各类业务开关）
public struct TMeGetUserSettingPropertyResource: DynamicCodable {
    public var id: Int64 = 0
    public var likeNotification = false
    public var collectNotification = false
    public var commentNotification = false
    public var followNotification = false
    public var atNotification = false
    public var chatNotification = false
    public var callNotification = false
    public var vibrateNotification = false
    public var messageReadableSeconds: Int64 = 0
    public var chatRingtone: Int64 = 0
    public var voiceCallRingtone: Int64 = 0
    public var collectListOpen = false
    public var likeListOpen = false
    public var followingListOpen = false
    public var followedListOpen = false
    public var searchOpen = false
    public var addFriendOpen = false
    public var reminderSound = false
    public var avatarSize = 0
    public var aiCloneVoiceOpen = false
    public var refuseAddFriendOpen = false
    public var refuseAddGroupOpen = false
    public var joinGroupVerifyOption = 0
    public var homeMemberOpen = false
    public var homelandListOpen = false
    public var shuCangOpen = false
    public var yunDianOpen = false
    public var workOpen = false

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.likeNotification, forKey: "likeNotification", in: &container)
        try encodeAny(self.collectNotification, forKey: "collectNotification", in: &container)
        try encodeAny(self.commentNotification, forKey: "commentNotification", in: &container)
        try encodeAny(self.followNotification, forKey: "followNotification", in: &container)
        try encodeAny(self.atNotification, forKey: "atNotification", in: &container)
        try encodeAny(self.chatNotification, forKey: "chatNotification", in: &container)
        try encodeAny(self.callNotification, forKey: "callNotification", in: &container)
        try encodeAny(self.vibrateNotification, forKey: "vibrateNotification", in: &container)
        try encodeAny(self.messageReadableSeconds, forKey: "messageReadableSeconds", in: &container)
        try encodeAny(self.chatRingtone, forKey: "chatRingtone", in: &container)
        try encodeAny(self.voiceCallRingtone, forKey: "voiceCallRingtone", in: &container)
        try encodeAny(self.collectListOpen, forKey: "collectListOpen", in: &container)
        try encodeAny(self.likeListOpen, forKey: "likeListOpen", in: &container)
        try encodeAny(self.followingListOpen, forKey: "followingListOpen", in: &container)
        try encodeAny(self.followedListOpen, forKey: "followedListOpen", in: &container)
        try encodeAny(self.searchOpen, forKey: "searchOpen", in: &container)
        try encodeAny(self.addFriendOpen, forKey: "addFriendOpen", in: &container)
        try encodeAny(self.reminderSound, forKey: "reminderSound", in: &container)
        try encodeAny(self.avatarSize, forKey: "avatarSize", in: &container)
        try encodeAny(self.aiCloneVoiceOpen, forKey: "aiCloneVoiceOpen", in: &container)
        try encodeAny(self.refuseAddFriendOpen, forKey: "refuseAddFriendOpen", in: &container)
        try encodeAny(self.refuseAddGroupOpen, forKey: "refuseAddGroupOpen", in: &container)
        try encodeAny(self.joinGroupVerifyOption, forKey: "joinGroupVerifyOption", in: &container)
        try encodeAny(self.homeMemberOpen, forKey: "homeMemberOpen", in: &container)
        try encodeAny(self.homelandListOpen, forKey: "homelandListOpen", in: &container)
        try encodeAny(self.shuCangOpen, forKey: "shuCangOpen", in: &container)
        try encodeAny(self.yunDianOpen, forKey: "yunDianOpen", in: &container)
        try encodeAny(self.workOpen, forKey: "workOpen", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.likeNotification = try decodeField("likeNotification", from: container)
        self.collectNotification = try decodeField("collectNotification", from: container)
        self.commentNotification = try decodeField("commentNotification", from: container)
        self.followNotification = try decodeField("followNotification", from: container)
        self.atNotification = try decodeField("atNotification", from: container)
        self.chatNotification = try decodeField("chatNotification", from: container)
        self.callNotification = try decodeField("callNotification", from: container)
        self.vibrateNotification = try decodeField("vibrateNotification", from: container)
        self.messageReadableSeconds = try decodeField("messageReadableSeconds", from: container)
        self.chatRingtone = try decodeField("chatRingtone", from: container)
        self.voiceCallRingtone = try decodeField("voiceCallRingtone", from: container)
        self.collectListOpen = try decodeField("collectListOpen", from: container)
        self.likeListOpen = try decodeField("likeListOpen", from: container)
        self.followingListOpen = try decodeField("followingListOpen", from: container)
        self.followedListOpen = try decodeField("followedListOpen", from: container)
        self.searchOpen = try decodeField("searchOpen", from: container)
        self.addFriendOpen = try decodeField("addFriendOpen", from: container)
        self.reminderSound = try decodeField("reminderSound", from: container)
        self.avatarSize = try decodeField("avatarSize", from: container)
        self.aiCloneVoiceOpen = try decodeField("aiCloneVoiceOpen", from: container)
        self.refuseAddFriendOpen = try decodeField("refuseAddFriendOpen", from: container)
        self.refuseAddGroupOpen = try decodeField("refuseAddGroupOpen", from: container)
        self.joinGroupVerifyOption = try decodeField("joinGroupVerifyOption", from: container)
        self.homeMemberOpen = try decodeField("homeMemberOpen", from: container)
        self.homelandListOpen = try decodeField("homelandListOpen", from: container)
        self.shuCangOpen = try decodeField("shuCangOpen", from: container)
        self.yunDianOpen = try decodeField("yunDianOpen", from: container)
        self.workOpen = try decodeField("workOpen", from: container)
    }
}


// MARK: - 钱包资源

/// 钱包（通宝/通钻/现金 + 分红）
/// ⚠️ 金额全用 Double，需确认协议单位是元还是分
public struct TMeGetUserWalletPropertyResource: DynamicCodable {
    public var id: Int64 = 0
    public var totalDividendCoin = 0.0
    public var totalDividendDiamond = 0.0
    public var totalDividendCash = 0.0
    public var dividendCoin = 0.0
    public var dividendDiamond = 0.0
    public var dividendCash = 0.0
    public var coin = 0.0
    public var diamond = 0.0
    public var cash = 0.0
    public var todayAddDividendCoin = 0.0

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.totalDividendCoin, forKey: "totalDividendCoin", in: &container)
        try encodeAny(self.totalDividendDiamond, forKey: "totalDividendDiamond", in: &container)
        try encodeAny(self.totalDividendCash, forKey: "totalDividendCash", in: &container)
        try encodeAny(self.dividendCoin, forKey: "dividendCoin", in: &container)
        try encodeAny(self.dividendDiamond, forKey: "dividendDiamond", in: &container)
        try encodeAny(self.dividendCash, forKey: "dividendCash", in: &container)
        try encodeAny(self.coin, forKey: "coin", in: &container)
        try encodeAny(self.diamond, forKey: "diamond", in: &container)
        try encodeAny(self.cash, forKey: "cash", in: &container)
        try encodeAny(self.todayAddDividendCoin, forKey: "todayAddDividendCoin", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.totalDividendCoin = try decodeField("totalDividendCoin", from: container)
        self.totalDividendDiamond = try decodeField("totalDividendDiamond", from: container)
        self.totalDividendCash = try decodeField("totalDividendCash", from: container)
        self.dividendCoin = try decodeField("dividendCoin", from: container)
        self.dividendDiamond = try decodeField("dividendDiamond", from: container)
        self.dividendCash = try decodeField("dividendCash", from: container)
        self.coin = try decodeField("coin", from: container)
        self.diamond = try decodeField("diamond", from: container)
        self.cash = try decodeField("cash", from: container)
        self.todayAddDividendCoin = try decodeField("todayAddDividendCoin", from: container)
    }
}


// MARK: - 关注资源

/// 关注/粉丝统计
public struct TMeGetUserFollowingResource: DynamicCodable {
    public var id: Int64 = 0
    public var status: TFollowTypeFollowType = .defaultCase
    public var followingCount: Int = 0
    public var followedCount: Int = 0

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.status, forKey: "status", in: &container)
        try encodeAny(self.followingCount, forKey: "followingCount", in: &container)
        try encodeAny(self.followedCount, forKey: "followedCount", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.status = try decodeField("status", from: container)
        self.followingCount = try decodeField("followingCount", from: container)
        self.followedCount = try decodeField("followedCount", from: container)
    }
}


// MARK: - AI 角色资源

/// AI 角色（形象、语音参数、MBTI 等）
public struct TMeGetAiRoleResource: DynamicCodable {
    public var id: Int64 = 0
    public var roleName = ""
    public var description = ""
    public var gender: TGenderGender = .defaultCase
    public var imageUrls = [String]()
    public var tagIds = [Int64]()
    public var tagList = [String]()
    public var age = 0
    public var backgroundImageURL = ""
    public var mbtiTag = ""
    public var robotID: Int64 = 0
    public var voiceSpeed: Int64 = 0
    public var voiceVolume: Int64 = 0
    public var voiceCode: String = ""
    public var voiceType: String = ""

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.roleName, forKey: "roleName", in: &container)
        try encodeAny(self.description, forKey: "description", in: &container)
        try encodeAny(self.gender, forKey: "gender", in: &container)
        try encodeAny(self.imageUrls, forKey: "imageUrls", in: &container)
        try encodeAny(self.tagIds, forKey: "tagIds", in: &container)
        try encodeAny(self.tagList, forKey: "tagList", in: &container)
        try encodeAny(self.age, forKey: "age", in: &container)
        try encodeAny(self.backgroundImageURL, forKey: "backgroundImageUrl", in: &container)
        try encodeAny(self.mbtiTag, forKey: "mbtiTag", in: &container)
        try encodeAny(self.robotID, forKey: "robotId", in: &container)
        try encodeAny(self.voiceSpeed, forKey: "voiceSpeed", in: &container)
        try encodeAny(self.voiceVolume, forKey: "voiceVolume", in: &container)
        try encodeAny(self.voiceCode, forKey: "voiceCode", in: &container)
        try encodeAny(self.voiceType, forKey: "voiceType", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.roleName = try decodeField("roleName", from: container)
        self.description = try decodeField("description", from: container)
        self.gender = try decodeField("gender", from: container)
        self.imageUrls = try decodeField("imageUrls", from: container)
        self.tagIds = try decodeField("tagIds", from: container)
        self.tagList = try decodeField("tagList", from: container)
        self.age = try decodeField("age", from: container)
        self.backgroundImageURL = try decodeField("backgroundImageUrl", from: container)
        self.mbtiTag = try decodeField("mbtiTag", from: container)
        self.robotID = try decodeField("robotId", from: container)
        self.voiceSpeed = try decodeField("voiceSpeed", from: container)
        self.voiceVolume = try decodeField("voiceVolume", from: container)
        self.voiceCode = try decodeField("voiceCode", from: container)
        self.voiceType = try decodeField("voiceType", from: container)
    }
}


// MARK: - UGC 资源

/// UGC 统计（动态/视频/商品/地皮/经营证等计数）
public struct TMeGetUserUgcResource: DynamicCodable {
    public var id: Int64 = 0
    public var ugcCount = 0
    public var likedCount = 0
    public var videoCount = 0
    public var goodsCount: Int64 = 0
    public var licenseCount: Int64 = 0
    public var landCount: Int64 = 0
    public var likeContentCount: Int64 = 0
    public var collectContentCount: Int64 = 0

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.ugcCount, forKey: "ugcCount", in: &container)
        try encodeAny(self.likedCount, forKey: "likedCount", in: &container)
        try encodeAny(self.videoCount, forKey: "videoCount", in: &container)
        try encodeAny(self.goodsCount, forKey: "goodsCount", in: &container)
        try encodeAny(self.licenseCount, forKey: "licenseCount", in: &container)
        try encodeAny(self.landCount, forKey: "landCount", in: &container)
        try encodeAny(self.likeContentCount, forKey: "likeContentCount", in: &container)
        try encodeAny(self.collectContentCount, forKey: "collectContentCount", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.ugcCount = try decodeField("ugcCount", from: container)
        self.likedCount = try decodeField("likedCount", from: container)
        self.videoCount = try decodeField("videoCount", from: container)
        self.goodsCount = try decodeField("goodsCount", from: container)
        self.licenseCount = try decodeField("licenseCount", from: container)
        self.landCount = try decodeField("landCount", from: container)
        self.likeContentCount = try decodeField("likeContentCount", from: container)
        self.collectContentCount = try decodeField("collectContentCount", from: container)
    }
}


// MARK: - 邀请资源

/// 邀请（绑定邀请码）
public struct TMeGetUserInviteResource: DynamicCodable {
    public var id: Int64 = 0
    public var bandingInviteCode = ""

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.bandingInviteCode, forKey: "bandingInviteCode", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.bandingInviteCode = try decodeField("bandingInviteCode", from: container)
    }
}


// MARK: - 拉黑信息资源

/// 拉黑状态
public struct TMeGetUserBlockInfoResource: DynamicCodable {
    public var id: Int64 = 0
    public var status: TBlockStatusE = .defaultCase

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.status, forKey: "status", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.status = try decodeField("status", from: container)
    }
}


// MARK: - UGC 拉黑响应

/// UGC 拉黑（开关 + 拉黑详情）
public struct TMeGetUgcUserBlockResponse: DynamicCodable {
    public var offOrOn = 0
    public var block = TUgcUserBlockGetUgcUserBlock()

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.offOrOn, forKey: "offOrOn", in: &container)
        try encodeAny(self.block, forKey: "block", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.offOrOn = try decodeField("offOrOn", from: container)
        self.block = try decodeField("block", from: container)
    }
}


// MARK: - UGC 限制响应

/// UGC 限制（开关 + 限制详情）
public struct TMeGetUgcUserRestrictResponse: DynamicCodable {
    public var offOrOn = 0
    public var restrict = TUgcUserRestrictGetUgcUserRestrict()

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.offOrOn, forKey: "offOrOn", in: &container)
        try encodeAny(self.restrict, forKey: "restrict", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.offOrOn = try decodeField("offOrOn", from: container)
        self.restrict = try decodeField("restrict", from: container)
    }
}


// MARK: - 历史限制响应

/// 历史限制(结构与 UGC 限制相同,但为独立类型)
/// ⚠️ 与 TMeGetUgcUserRestrictResponse 字段完全一致,可合并
public struct TMeGetHisRestrictResponse: DynamicCodable {
    public var offOrOn = 0
    public var restrict = TUgcUserRestrictGetUgcUserRestrict()

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.offOrOn, forKey: "offOrOn", in: &container)
        try encodeAny(self.restrict, forKey: "restrict", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.offOrOn = try decodeField("offOrOn", from: container)
        self.restrict = try decodeField("restrict", from: container)
    }
}


// MARK: - 用户备注资源

/// 用户备注（备注名、手机号、关联用户）
public struct TMeGetUserNoteResource: DynamicCodable {
    public var id: Int64 = 0
    public var noteName = ""
    public var phoneNumber = ""
    public var notedUserID: Int64 = 0
    public var phoneNumberList = [String]()
    public var applyResource = ""

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.noteName, forKey: "noteName", in: &container)
        try encodeAny(self.phoneNumber, forKey: "phoneNumber", in: &container)
        try encodeAny(self.notedUserID, forKey: "notedUserId", in: &container)
        try encodeAny(self.phoneNumberList, forKey: "phoneNumberList", in: &container)
        try encodeAny(self.applyResource, forKey: "applyResource", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.noteName = try decodeField("noteName", from: container)
        self.phoneNumber = try decodeField("phoneNumber", from: container)
        self.notedUserID = try decodeField("notedUserId", from: container)
        self.phoneNumberList = try decodeField("phoneNumberList", from: container)
        self.applyResource = try decodeField("applyResource", from: container)
    }
}


// MARK: - 用户额外资源（实名认证）

/// 用户额外信息（实名认证、平台认证状态等）
public struct TMeGetUserExtraResource: DynamicCodable {
    public var id: Int64 = 0
    public var identityVerified = false
    public var code = 0
    public var realNameAuthStatus = false
    /// 平台认证状态码(字符串,01~08),配合 TMeGetPlatformCertStatus 使用
    public var platformCertStatus = ""
    public var hasCertData = ""
    public var certTime = ""
    public var certState = ""
    public var idCardPicState = ""
    public var certStateCode = ""
    /// 客户端人脸认证状态,"0" 表示未完成(见 sdkType 逻辑)
    public var clientFaceAuthState = ""

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.identityVerified, forKey: "identityVerified", in: &container)
        try encodeAny(self.code, forKey: "code", in: &container)
        try encodeAny(self.realNameAuthStatus, forKey: "realNameAuthStatus", in: &container)
        try encodeAny(self.platformCertStatus, forKey: "platformCertStatus", in: &container)
        try encodeAny(self.hasCertData, forKey: "hasCertData", in: &container)
        try encodeAny(self.certTime, forKey: "certTime", in: &container)
        try encodeAny(self.certState, forKey: "certState", in: &container)
        try encodeAny(self.idCardPicState, forKey: "idCardPicState", in: &container)
        try encodeAny(self.certStateCode, forKey: "certStateCode", in: &container)
        try encodeAny(self.clientFaceAuthState, forKey: "clientFaceAuthState", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.identityVerified = try decodeField("identityVerified", from: container)
        self.code = try decodeField("code", from: container)
        self.realNameAuthStatus = try decodeField("realNameAuthStatus", from: container)
        self.platformCertStatus = try decodeField("platformCertStatus", from: container)
        self.hasCertData = try decodeField("hasCertData", from: container)
        self.certTime = try decodeField("certTime", from: container)
        self.certState = try decodeField("certState", from: container)
        self.idCardPicState = try decodeField("idCardPicState", from: container)
        self.certStateCode = try decodeField("certStateCode", from: container)
        self.clientFaceAuthState = try decodeField("clientFaceAuthState", from: container)
    }
}


// MARK: - 平台实名状态

/// 平台实名认证状态（服务端字符串码 → 语义 + 展示 + SDK 场景）
public enum TMeGetPlatformCertStatus: String {
    case reviewing = "01"        // 认证中
    case success = "02"          // 已实名
    case failedInfo = "03"       // 信息认证失败
    case unverified = "04"       // 未实名
    case expired = "05"          // 认证过期
    case failedPicture = "06"    // 图片认证失败
    case disabled = "07"         // 用户禁用
    case unknown = "08"          // 未知

    /// 展示文案
    public var displayText: String {
        switch self {
        case .reviewing:
            return "认证中"
        case .success:
            return "已实名"
        case .failedInfo, .failedPicture:
            return "认证失败"
        case .unverified:
            return "未实名"
        case .expired:
            return "认证过期"
        case .disabled:
            return "用户禁用"
        case .unknown:
            return "认证未知"
        }
    }

    /// 平台实名状态对应的美付宝 SDK 场景；客户端人脸未认证时沿用原人脸识别场景 33。
    /// - Parameter clientFaceAuthState: 客户端人脸认证状态,"0" 表示未完成
    /// - Returns: SDK 场景码;无需认证返回 nil
    public func sdkType(clientFaceAuthState: String) -> String? {
        switch self {
        case .success:
            // 已实名但客户端人脸未完成 → 走 33 场景补人脸
            return clientFaceAuthState == "0" ? "33" : nil
        case .failedInfo, .unverified:
            return "2"
        case .expired, .failedPicture:
            return "35"
        case .reviewing, .disabled, .unknown:
            return nil
        }
    }
}

extension TMeGetUserExtraResource {
    /// 平台实名状态枚举(非法/缺失为 nil)
    public var platformRealNameStatus: TMeGetPlatformCertStatus? {
        return TMeGetPlatformCertStatus(rawValue: platformCertStatus)
    }

    /// 平台实名展示文案:只展示后端明确定义的 01...08,缺失或非法不展示
    public var platformRealNameDisplayText: String {
        return platformRealNameStatus?.displayText ?? ""
    }

    /// 是否"平台实名成功且客户端人脸已完成"
    /// ⚠️ 命名 isPlatformRealNameSuccess 却额外要求 clientFaceAuthState != "0",
    ///    语义是"实名且人脸完成",与名字不完全一致,易误用
    public var isPlatformRealNameSuccess: Bool {
        return platformRealNameStatus == .success && clientFaceAuthState != "0"
    }

    /// 平台实名 SDK 场景码
    public var platformRealNameSDKType: String? {
        return platformRealNameStatus?.sdkType(clientFaceAuthState: clientFaceAuthState)
    }
}


// MARK: - Web3 资产

/// Web3 资产列表
public struct TMeGetUserWeb3Response: DynamicCodable {
    public var assetList = [TMeGetAssetList]()

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.assetList, forKey: "assetList", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.assetList = try decodeField("assetList", from: container)
    }
}


// MARK: - 朋友圈资源

/// 朋友圈统计
public struct TMeGetUserFriendCircleResource: DynamicCodable {
    public var dynamicCount: Int64 = 0

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.dynamicCount, forKey: "dynamicCount", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.dynamicCount = try decodeField("dynamicCount", from: container)
    }
}


// MARK: - 用户群资源

/// 用户群统计
public struct TMeGetUserGroupResource: DynamicCodable {
    public var showGroupCount = 0

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.showGroupCount, forKey: "showGroupCount", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.showGroupCount = try decodeField("showGroupCount", from: container)
    }
}


// MARK: - 资产项

/// Web3 资产单项
public struct TMeGetAssetList: DynamicCodable {
    public var id: Int64 = 0
    public var name = ""

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.name, forKey: "name", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.name = try decodeField("name", from: container)
    }
}


// MARK: - AI 分身资源

/// AI 分身（托管开关、粉丝数、语音参数）
public struct TMeGetUserAiCloneResource: DynamicCodable {
    public var aiUID: Int64 = 0
    public var followerNum: Int64 = 0
    public var aiTrusteeship = false
    public var voiceSpeed: Int64 = 0
    public var voiceVolume: Int64 = 0
    public var voiceCode = ""
    public var voiceType = ""

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.aiUID, forKey: "aiUid", in: &container)
        try encodeAny(self.followerNum, forKey: "followerNum", in: &container)
        try encodeAny(self.aiTrusteeship, forKey: "aiTrusteeship", in: &container)
        try encodeAny(self.voiceSpeed, forKey: "voiceSpeed", in: &container)
        try encodeAny(self.voiceVolume, forKey: "voiceVolume", in: &container)
        try encodeAny(self.voiceCode, forKey: "voiceCode", in: &container)
        try encodeAny(self.voiceType, forKey: "voiceType", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.aiUID = try decodeField("aiUid", from: container)
        self.followerNum = try decodeField("followerNum", from: container)
        self.aiTrusteeship = try decodeField("aiTrusteeship", from: container)
        self.voiceSpeed = try decodeField("voiceSpeed", from: container)
        self.voiceVolume = try decodeField("voiceVolume", from: container)
        self.voiceCode = try decodeField("voiceCode", from: container)
        self.voiceType = try decodeField("voiceType", from: container)
    }
}


// MARK: - VIP 资源

/// VIP 信息
public struct TMeGetUserVipResource: DynamicCodable {
    public var userID: Int64 = 0
    public var vip = false

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.userID, forKey: "userId", in: &container)
        try encodeAny(self.vip, forKey: "vip", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.userID = try decodeField("userId", from: container)
        self.vip = try decodeField("vip", from: container)
    }
}
