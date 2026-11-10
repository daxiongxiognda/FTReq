//
//  MessageCheckConversationPost.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/28.
//
import FTTool


public struct TMessageCheckConversationPostReq: DynamicCodable {
    /// 消息内容类型,默认 .defaultCase
    public var type: TIMMessageContentType = .defaultCase
    /// 文本内容
    public var content = ""
    /// 媒体 URL(图片/语音/视频地址)
    public var mediaURL = ""
    /// @ 的用户 id 列表(数值型)
    public var atIds = [Int64]()
    /// 发送者 id
    public var senderID: Int64 = 0
    /// 消息 id
    public var messageID = ""
    /// @ 的 IM 用户 id 列表(字符串型)
    /// ⚠️ 与 atIds 语义重叠:一个 Int64 一个 String,
    ///    两者关系/优先级不清晰,易出现只填一个导致 @ 失效
    public var atImUserIds = [String]()
    /// 扩展字段(任意 JSON)
    /// ⚠️ [String: Any] 无法直接 Codable,靠 encodeAny/decodeAny 处理
    public var ext = [String: Any]()

    public init() {}

    /// 编码:逐字段写入 container
    /// ⚠️ 注意:
    ///   1. ext 最先写,其余字段后写;若 ext 里也含 "type"/"content" 等 key,
    ///      后续同 key 写入会覆盖,ext 中的同名字段被吞掉
    ///   2. 字段顺序与 decodeMapping 不一致(encode 把 ext 放首位,decode 放末位),
    ///      虽然 JSON 编解码不依赖顺序,但维护时易看漏
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.ext, forKey: "ext", in: &container)
        try encodeAny(self.type, forKey: "type", in: &container)
        try encodeAny(self.content, forKey: "content", in: &container)
        try encodeAny(self.mediaURL, forKey: "mediaUrl", in: &container)
        try encodeAny(self.atIds, forKey: "atIds", in: &container)
        try encodeAny(self.senderID, forKey: "senderId", in: &container)
        try encodeAny(self.messageID, forKey: "messageId", in: &container)
        try encodeAny(self.atImUserIds, forKey: "atImUserIds", in: &container)
    }

    /// 解码:逐字段读取
    /// ⚠️ 问题:
    ///   1. 用 `try decodeField(...)` 直接赋值,若服务端缺字段或类型不符会抛错,
    ///      整个消息解析失败;对"部分字段可选"的消息协议不够健壮,
    ///      建议对非关键字段用 `decodeFieldIfPresent` + 默认值
    ///   2. decode 里 ext 在最后,且 ext 解码若失败同样抛错,
    ///      一个非法扩展字段会让整条消息解析失败
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.type = try decodeField("type", from: container)
        self.content = try decodeField("content", from: container)
        self.mediaURL = try decodeField("mediaUrl", from: container)
        self.atIds = try decodeField("atIds", from: container)
        self.senderID = try decodeField("senderId", from: container)
        self.messageID = try decodeField("messageId", from: container)
        self.atImUserIds = try decodeField("atImUserIds", from: container)
        self.ext = try decodeField("ext", from: container)
    }
}

// MARK: - 消息检查请求数据

/// 消息检查请求的完整数据
/// - 包含会话 id、被检查的消息、检查结果
/// - 遵循 `DynamicCodable`：手动映射 JSON
public struct TMessageCheckConversationPostData: DynamicCodable {

    /// 会话 id
    public var conversationID = ""

    /// 被检查的消息（复用消息检查请求结构作为内容载体）
    public var message = TMessageCheckConversationPostReq()

    /// 检查结果：成功 / 命中敏感词 / 审核中
    public var checkResult: TCheckResultCheckResult = .defaultCase

    public init() {}

    /// 编码：逐字段写入
    /// - conversationID 属性大写 ID，JSON key 为 conversationId（ID→Id）
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.conversationID, forKey: "conversationId", in: &container)
        try encodeAny(self.message, forKey: "message", in: &container)
        try encodeAny(self.checkResult, forKey: "checkResult", in: &container)
    }

    /// 解码：逐字段硬解
    /// ⚠️ 风险：3 个字段全部 `try decodeField` 硬解。
    ///    - `message` 是嵌套的 DynamicCodable，其内部任一字段缺失会连带失败
    ///    - `checkResult` 是枚举，依赖 EnumCodable 容错，未知值回退 defaultCase，不会抛错
    ///    如果该结构用于**解析服务端响应**，建议对 `message` 和 `checkResult` 做容错；
    ///    如果仅用于**构造请求**（客户端发出），硬解风险较低，但建议注释说明用途
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.conversationID = try decodeField("conversationId", from: container)
        self.message = try decodeField("message", from: container)
        self.checkResult = try decodeField("checkResult", from: container)
    }
}


// MARK: - 消息完成请求

/// 消息发送完成（落库/上报）的请求数据
/// - 描述一条已发送消息的完整信息
/// - 遵循 `DynamicCodable`：手动映射 JSON
public struct TMessageFinishConversationPostReq: DynamicCodable {

    /// 消息内容类型
    public var type: TIMMessageContentType = .defaultCase

    /// 消息内容
    public var content = ""

    /// 媒体 URL（图片/语音/视频地址）
    /// ⚠️ 属性 `mediaURL` 大写 URL，JSON key `mediaUrl`（URL→Url）
    public var mediaURL = ""

    /// @ 的用户 id 列表
    public var atIds = [Int64]()

    /// 发送者 id
    public var senderID: Int64 = 0

    /// 消息 id
    public var messageID = ""

    /// 创建时间戳（秒）
    public var createdAt: Int64 = 0

    /// 扩展字段（任意 JSON）
    /// ⚠️ `[String: Any]` 无法直接 Codable，靠 encodeAny 处理；
    ///    若 ext 里含与顶层同名的 key（如 "type"/"content"），
    ///    编码时会与顶层字段冲突（取决于编码顺序，后写的覆盖先写的）
    public var ext: [String: Any] = [String: Any]()

    public init() {}

    /// 编码：逐字段写入
    /// ⚠️ 注意：ext 放在最后写，若 ext 里有 "type"/"content"/"mediaUrl" 等 key，
    ///    会**覆盖**前面写入的顶层字段。如果 ext 是纯扩展、不应覆盖主字段，
    ///    建议先写 ext 再写主字段，或对 ext 做 key 过滤
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.type, forKey: "type", in: &container)
        try encodeAny(self.content, forKey: "content", in: &container)
        try encodeAny(self.mediaURL, forKey: "mediaUrl", in: &container)
        try encodeAny(self.atIds, forKey: "atIds", in: &container)
        try encodeAny(self.senderID, forKey: "senderId", in: &container)
        try encodeAny(self.messageID, forKey: "messageId", in: &container)
        try encodeAny(self.createdAt, forKey: "createdAt", in: &container)
        try encodeAny(self.ext, forKey: "ext", in: &container)
    }

    /// 解码：逐字段硬解
    /// ⚠️ 风险：8 个字段全部 `try decodeField` 硬解。
    ///    - `atIds`（无 @ 时可能不下发）
    ///    - `ext`（无扩展时可能不下发）
    ///    - `createdAt`（部分场景可能不下发）
    ///    任一缺失会让整个消息解析失败。如果该结构也用于解析服务端响应，建议这三个容错。
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.type = try decodeField("type", from: container)
        self.content = try decodeField("content", from: container)
        self.mediaURL = try decodeField("mediaUrl", from: container)
        self.atIds = try decodeField("atIds", from: container)
        self.senderID = try decodeField("senderId", from: container)
        self.messageID = try decodeField("messageId", from: container)
        self.createdAt = try decodeField("createdAt", from: container)
        self.ext = try decodeField("ext", from: container)
    }
}
