//
//  Conversation.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/29.
//

import FTTool

// MARK: - 请求：获取会话最近列表

/// 获取最近会话列表的请求参数（标准 Codable，属性名即 JSON key）
/// - 所有字段可选，用于分页/时间范围过滤
public struct TConversationRecentGetReq: Encodable {
    /// 起始时间戳（大于 0 才生效）
    public var startAt: Int64?
    /// 结束时间戳（大于 0 才生效）
    public var endAt: Int64?
    /// 拉取条数限制
    public var limit: Int?

    public init(startAt: Int64? = nil, endAt: Int64? = nil, limit: Int? = nil) {
        // ⚠️ 只有在传入且 > 0 时才赋值，否则保持 nil（不传该 key）
        if let start = startAt, start > 0 {
            self.startAt = startAt
        }
        if let end = endAt, end > 0 {
            self.endAt = endAt
        }
        self.limit = limit
    }
}

// MARK: - 响应：会话最近列表项

/// 最近会话列表中的单项数据
/// - 遵循 `DynamicCodable`：手动映射 JSON 字段
/// - Swift 属性用大写 ID，JSON key 用 `Id`（ID→Id 转换）
public struct TConversationRecentGetData: DynamicCodable {

    /// 会话 id（主标识）
    public var conversationID = ""

    /// 单聊对方用户 id（群聊时通常为 0）
    public var chatUserID: Int64 = 0

    /// 会话类型：单聊 / 群聊
    public var type: TConversationTypeE = .defaultCase

    /// 会话列表分类：正常 / 置顶 / 通知
    public var listType: TConversationListTypeE = .defaultCase

    /// 好友分组 id（会话归属的分组）
    public var groupingID = ""

    /// 创建时间戳（秒）
    public var createdAt: Int64 = 0

    /// 更新时间戳（秒）
    public var updatedAt: Int64 = 0

    /// 会话状态：正常 / 隐藏 / 删除 / 退出
    public var status: TConversationStatusE = .defaultCase

    /// 是否消息免打扰
    public var mute = false

    /// 定时消息 id（定时消息相关，0 表示无）
    public var timerMessageID: Int64 = 0

    /// 会话密码（私聊加密场景使用）
    /// ⚠️ 密码以明文放在模型里，若该结构会被打日志/上报/缓存到非安全位置，
    ///    存在泄露风险，需确认使用场景是否安全
    public var password = ""

    public init() {}

    /// 编码：逐字段写入
    /// - 注意 `conversationID`/`chatUserID`/`groupingID`/`timerMessageID`
    ///   对应 JSON key 均为 `Id` 结尾（ID→Id）
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.conversationID, forKey: "conversationId", in: &container)
        try encodeAny(self.chatUserID, forKey: "chatUserId", in: &container)
        try encodeAny(self.type, forKey: "type", in: &container)
        try encodeAny(self.listType, forKey: "listType", in: &container)
        try encodeAny(self.groupingID, forKey: "groupingId", in: &container)
        try encodeAny(self.createdAt, forKey: "createdAt", in: &container)
        try encodeAny(self.updatedAt, forKey: "updatedAt", in: &container)
        try encodeAny(self.status, forKey: "status", in: &container)
        try encodeAny(self.mute, forKey: "mute", in: &container)
        try encodeAny(self.timerMessageID, forKey: "timerMessageId", in: &container)
        try encodeAny(self.password, forKey: "password", in: &container)
    }

    /// 解码：逐字段硬解
    /// ⚠️ 风险：11 个字段全部 `try decodeField` 硬解。
    ///    会话列表是高频核心数据，其中 `groupingID`（不属于任何分组时可能不下发）、
    ///    `timerMessageID`（无定时消息时可能不下发）、`password`（非加密会话可能不下发）
    ///    这些"条件性字段"缺失会让**整个会话列表解析失败、列表空白**。
    ///    建议对这些字段用 `try?` + 默认值兜底：
    ///    - groupingID → ""
    ///    - timerMessageID → 0
    ///    - password → ""
    ///    核心字段（conversationID/type/updatedAt 等）保持硬解。
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.conversationID = try decodeField("conversationId", from: container)
        self.chatUserID = try decodeField("chatUserId", from: container)
        self.type = try decodeField("type", from: container)
        self.listType = try decodeField("listType", from: container)
        self.groupingID = try decodeField("groupingId", from: container)
        self.createdAt = try decodeField("createdAt", from: container)
        self.updatedAt = try decodeField("updatedAt", from: container)
        self.status = try decodeField("status", from: container)
        self.mute = try decodeField("mute", from: container)
        self.timerMessageID = try decodeField("timerMessageId", from: container)
        self.password = try decodeField("password", from: container)
    }
}
