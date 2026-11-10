//
//  SocketConversationsPost.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/29.
//

import FTTool

// MARK: - 会话列表响应外层

/// Socket 推送/拉取的会话列表响应
/// - 标准 Codable，字段全可选，便于分页与空列表场景
public struct TSocketConversationsPostRes: Codable {
    /// 是否还有下一页
    public var hasNext: Bool?
    /// 会话数据列表
    public var data: [TSocketConversationsPostData]?
    /// 总数（可能为当前页条数，需确认协议）
    public var count: Int?
    /// 下一页 token（游标分页用）
    public var nextPageToken: String?
    // ⚠️ 未显式声明 init，但结构体是 public，外部无法用 memberwise init 构造
    //    （Swift 会为 public struct 生成 internal 的 memberwise init）。
    //    如果外部需要构造该对象（如测试、本地造数据），需补 public init()。
}

// MARK: - 会话数据项

/// 单个会话的数据（Socket 场景）
/// - 遵循 `DynamicCodable`：手动映射 JSON 字段
/// - Swift 属性大写 ID，JSON key 用 `Id`（ID→Id 转换）
public struct TSocketConversationsPostData: DynamicCodable {

    /// 会话 id（主标识）
    public var conversationID = ""

    /// 会话类型：单聊 / 群聊
    public var type: TConversationTypeE = .defaultCase

    /// 最后已读时间戳（秒）
    public var lastReadAt: Int64 = 0

    /// 最新一条消息
    /// ⚠️ 会话可能没有任何消息（新建会话/消息被清空），此时该字段可能缺失，
    ///    硬解会让整个会话项解析失败
    public var latestMessage = TMessageBasicGetData()

    /// 消息总数
    public var messageCount: Int64 = 0

    /// 群成员数（单聊通常为 0 或 2）
    public var memberCount = 0

    /// 已读人数（群聊已读回执）
    public var readCount: Int64 = 0

    /// 未读消息数
    public var unread: Int64 = 0

    /// 创建时间戳（秒）
    public var createdAt: Int64 = 0

    /// 更新时间戳（秒）
    public var updatedAt: Int64 = 0

    /// 是否为新会话记录
    public var newRecord = false

    /// 消息清空时间戳（清空聊天记录时记录的时间点）
    public var clearMessageAt: Int64 = 0

    /// @ 消息列表
    /// ⚠️ 没有 @ 消息时服务端可能不下发，硬解会让整个会话项解析失败
    public var atMessages = [TSocketConversationsPostAtMessage]()

    public init() {}

    /// 编码：逐字段写入
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.conversationID, forKey: "conversationId", in: &container)
        try encodeAny(self.type, forKey: "type", in: &container)
        try encodeAny(self.lastReadAt, forKey: "lastReadAt", in: &container)
        try encodeAny(self.latestMessage, forKey: "latestMessage", in: &container)
        try encodeAny(self.messageCount, forKey: "messageCount", in: &container)
        try encodeAny(self.memberCount, forKey: "memberCount", in: &container)
        try encodeAny(self.readCount, forKey: "readCount", in: &container)
        try encodeAny(self.unread, forKey: "unread", in: &container)
        try encodeAny(self.createdAt, forKey: "createdAt", in: &container)
        try encodeAny(self.updatedAt, forKey: "updatedAt", in: &container)
        try encodeAny(self.newRecord, forKey: "newRecord", in: &container)
        try encodeAny(self.clearMessageAt, forKey: "clearMessageAt", in: &container)
        try encodeAny(self.atMessages, forKey: "atMessages", in: &container)
    }

    /// 解码：逐字段硬解
    /// ⚠️ 风险：13 个字段全部 `try decodeField` 硬解。会话列表是核心高频数据，
    ///    其中 `latestMessage`（无消息的会话）、`atMessages`（无 @ 消息时）、
    ///    `clearMessageAt`（从未清空过）这些"条件性字段"缺失会让
    ///    **整个会话列表解析失败、会话列表空白**。
    ///    建议对这几项用 `try?` + 默认值兜底，核心字段（conversationID/type/updatedAt 等）硬解。
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.conversationID = try decodeField("conversationId", from: container)
        self.type = try decodeField("type", from: container)
        self.lastReadAt = try decodeField("lastReadAt", from: container)
        self.latestMessage = try decodeField("latestMessage", from: container)
        self.messageCount = try decodeField("messageCount", from: container)
        self.memberCount = try decodeField("memberCount", from: container)
        self.readCount = try decodeField("readCount", from: container)
        self.unread = try decodeField("unread", from: container)
        self.createdAt = try decodeField("createdAt", from: container)
        self.updatedAt = try decodeField("updatedAt", from: container)
        self.newRecord = try decodeField("newRecord", from: container)
        self.clearMessageAt = try decodeField("clearMessageAt", from: container)
        self.atMessages = try decodeField("atMessages", from: container)
    }
}

// MARK: - @ 消息项

/// 会话中的 @ 消息标记
public struct TSocketConversationsPostAtMessage: DynamicCodable {
    /// 被 @ 的消息 id
    public var messageID = ""
    /// @ 发生的时间戳（秒）
    public var time: Int64 = 0

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.messageID, forKey: "messageId", in: &container)
        try encodeAny(self.time, forKey: "time", in: &container)
    }

    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.messageID = try decodeField("messageId", from: container)
        self.time = try decodeField("time", from: container)
    }
}
