//
//  GroupMembersGet.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/29.
//

import FTTool

// MARK: - 请求：获取群成员

/// 获取群成员的请求参数（标准 Codable）
/// - 三个字段全可选，但注意 `init()` 是无参的，外部只能先创建再逐字段赋值
public struct TGroupMembersGetReq: Encodable {
    /// 群 id
    public var groupId: String?
    /// 页码
    public var page: Int64?
    /// 每页条数
    public var size: Int64?

    public init() {}
}

// MARK: - 响应：群成员数据

/// 群成员数据
/// - 遵循 `DynamicCodable`：手动映射 JSON，ID 属性 → JSON key 的 Id
public struct TGroupMembersGetData: DynamicCodable {

    /// 成员用户 id
    public var userID: Int64 = 0

    /// 成员身份：群主 / 管理员 / 普通成员
    public var identity: TGroupMemberTypeGroupMemberType = .defaultCase

    /// 所属群 id
    public var groupID = ""

    /// 我在该群的备注名（群昵称）
    public var noteName = ""

    /// 入群时间戳（秒）
    public var createdAt: Int64 = 0

    /// 更新时间戳（秒）
    public var updatedAt: Int64 = 0

    /// 成员头像 URL
    /// ⚠️ Swift 属性 avatarURL，JSON key avatarUrl（URL→Url）
    public var avatarURL = ""

    /// 成员昵称
    public var firstName = ""

    /// 我对该成员的备注名
    public var remarkName = ""

    /// 成员的完整用户数据（嵌套 TMeGetData）
    /// ⚠️ 这是一个较大的嵌套结构（22 个子资源），群成员列表里每条都带一份，
    ///    数据量会很大；且 TMeGetData 内部解码是硬解，任一子资源缺失
    ///    会让整个成员解析失败。建议确认服务端是否真的每条都返回完整用户数据，
    ///    否则应精简为只返回必要字段
    public var meGetData = TMeGetData()

    public init() {}

    /// 编码：逐字段写入
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.userID, forKey: "userId", in: &container)
        try encodeAny(self.identity, forKey: "identity", in: &container)
        try encodeAny(self.groupID, forKey: "groupId", in: &container)
        try encodeAny(self.noteName, forKey: "noteName", in: &container)
        try encodeAny(self.createdAt, forKey: "createdAt", in: &container)
        try encodeAny(self.updatedAt, forKey: "updatedAt", in: &container)
        try encodeAny(self.avatarURL, forKey: "avatarUrl", in: &container)
        try encodeAny(self.firstName, forKey: "firstName", in: &container)
        try encodeAny(self.remarkName, forKey: "remarkName", in: &container)
        try encodeAny(self.meGetData, forKey: "meGetData", in: &container)
    }

    /// 解码：逐字段硬解
    /// ⚠️ 风险：10 个字段全部 `try decodeField` 硬解。
    ///    群成员列表是高频数据，其中 `noteName`（未设群昵称时）、`remarkName`（未设备注时）、
    ///    `meGetData`（服务端可能不下发完整用户数据时）缺失会让
    ///    **整个群成员列表解析失败、列表空白**。
    ///    建议这三个字段用 `try?` + 默认值兜底。
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.userID = try decodeField("userId", from: container)
        self.identity = try decodeField("identity", from: container)
        self.groupID = try decodeField("groupId", from: container)
        self.noteName = try decodeField("noteName", from: container)
        self.createdAt = try decodeField("createdAt", from: container)
        self.updatedAt = try decodeField("updatedAt", from: container)
        self.avatarURL = try decodeField("avatarUrl", from: container)
        self.firstName = try decodeField("firstName", from: container)
        self.remarkName = try decodeField("remarkName", from: container)
        self.meGetData = try decodeField("meGetData", from: container)
    }
}
