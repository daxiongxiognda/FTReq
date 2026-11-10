//
//  MessageClap.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/29.
//

import FTTool

// MARK: - 拍一拍请求

/// 拍一拍请求参数（标准 Codable）
/// - 三个字段均可选，按业务场景组合传入：
///   - 拍群成员：clapUserId + conversationId
///   - 拍某条消息：conversationId + messageId
/// - ⚠️ 全可选意味着调用方可能全部传 nil，服务端需有兜底或校验，
///   建议调用前保证至少传 conversationId
public struct TMessageClapPostReq: Encodable {
    /// 被拍的用户 id
    public var clapUserId: Int64?
    /// 会话 id
    public var conversationId: String?
    /// 消息 id（拍某条消息时传）
    public var messageId: String?

    public init(clapUserId: Int64? = nil,
                conversationId: String? = nil,
                messageId: String? = nil) {
        self.clapUserId = clapUserId
        self.conversationId = conversationId
        self.messageId = messageId
    }
}


// MARK: - 消息基础数据

/// 消息基础数据（精简版）
/// - 用于会话列表的最新消息、消息预览等轻量场景
/// - 遵循 `DynamicCodable`：手动映射 JSON，ID 属性 → JSON key 的 Id
public struct TMessageBasicGetData: DynamicCodable {

    /// 消息 id
    public var id = ""

    /// 会话 id
    /// ⚠️ Swift 属性 conversationID，JSON key conversationId（ID→Id）
    public var conversationID = ""

    /// 消息类型
    /// ⚠️ 这里是 Int，而项目里其他消息模型用 TIMMessageContentType 枚举，
    ///   类型不一致，跨模型传递时需要显式转换；建议至少注释"对应哪种枚举"
    public var type = 0

    /// 发送者 uid
    /// ⚠️ 用 String 存储，而其他结构（如 IMChatMsgModel）用 Int64，
    ///   跨模型使用时需注意转换和判空
    public var senderUID = ""

    /// 消息内容（JSON 字符串）
    public var content = ""

    /// 扩展信息（JSON 字符串）
    public var extras = ""

    /// 创建时间戳（秒）
    public var createdAt: Int64 = 0

    /// 更新时间戳（秒）
    public var updatedAt: Int64 = 0

    /// 已读用户 id 列表
    /// ⚠️ 单聊 / 无已读回执场景服务端可能不下发，解码硬解会失败
    public var readUsers = [String]()

    /// 是否阅后即焚
    /// ⚠️ 旧数据或非焚毁消息可能不下发该字段，硬解会失败
    public var burn = false

    public init() {}

    /// 编码：逐字段写入
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.conversationID, forKey: "conversationId", in: &container)
        try encodeAny(self.type, forKey: "type", in: &container)
        try encodeAny(self.senderUID, forKey: "senderUid", in: &container)
        try encodeAny(self.content, forKey: "content", in: &container)
        try encodeAny(self.extras, forKey: "extras", in: &container)
        try encodeAny(self.createdAt, forKey: "createdAt", in: &container)
        try encodeAny(self.updatedAt, forKey: "updatedAt", in: &container)
        try encodeAny(self.readUsers, forKey: "readUsers", in: &container)
        try encodeAny(self.burn, forKey: "burn", in: &container)
    }

    /// 解码：逐字段硬解
    /// ⚠️ 风险：10 个字段全部 `try decodeField` 硬解。
    ///   本结构常作为会话列表的 `latestMessage`，若 `readUsers`（无已读回执时）、
    ///   `extras`（无扩展时）、`burn`（旧消息无此字段）缺失，
    ///   会导致整个会话项解析失败 → 会话列表空白。
    ///   建议这三个字段用 `try?` + 默认值兜底，核心字段保持硬解。
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.conversationID = try decodeField("conversationId", from: container)
        self.type = try decodeField("type", from: container)
        self.senderUID = try decodeField("senderUid", from: container)
        self.content = try decodeField("content", from: container)
        self.extras = try decodeField("extras", from: container)
        self.createdAt = try decodeField("createdAt", from: container)
        self.updatedAt = try decodeField("updatedAt", from: container)
        self.readUsers = try decodeField("readUsers", from: container)
        self.burn = try decodeField("burn", from: container)
    }
}


// MARK: - AI 语音数据

/// AI 消息语音波形数据
/// - 用于播放 AI 语音时绘制波形
public struct AIMessageVoiceDataModel: DynamicCodable {

    /// 消息 id
    public var msgId: String = ""

    /// 时长
    /// ⚠️ 单位未注明（毫秒 / 秒），需与协议确认，避免播放时长计算错误
    public var duration: Int64 = 0

    /// 波形采样数组（每个 Float 一个采样点）
    /// ⚠️ 波形数据通常几十到几百个 Float，硬解时若缺失会抛错；
    ///   大量消息同时解析时，Float 数组的 JSON 解析开销也不可忽略
    public var voiceArray: [Float] = []

    public init() {}

    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.msgId, forKey: "msgId", in: &container)
        try encodeAny(self.duration, forKey: "duration", in: &container)
        try encodeAny(self.voiceArray, forKey: "voiceArray", in: &container)
    }

    /// 解码
    /// ⚠️ `voiceArray` 硬解，服务端未下发波形时会失败，
    ///   建议 `try?` + 空数组兜底（无波形时 UI 可用占位波形）
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.msgId = try decodeField("msgId", from: container)
        self.duration = try decodeField("duration", from: container)
        self.voiceArray = try decodeField("voiceArray", from: container)
    }
}


// MARK: - 聊天高亮资源

/// 聊天高亮外层包装
/// - JSON 结构：{ "chat_highlight": { "resource_data": [ ... ] } }
/// ⚠️ 类型名拼写 Highilght → 应为 Highlight（先加注释，重命名需同步所有引用）
public struct IMMessageChatHighilght: Codable {
    public let chatHighlight: IMMessageResourceData

    enum CodingKeys: String, CodingKey {
        case chatHighlight = "chat_highlight"
    }
}

/// 高亮资源数据
public struct IMMessageResourceData: Codable {
    public let resourceData: [IMMessageBusiness]

    enum CodingKeys: String, CodingKey {
        case resourceData = "resource_data"
    }
}

/// 单条业务资源
/// - 描述一个可被高亮/搜索的业务入口：模块类型、名称、iOS 路由、关键词
public struct IMMessageBusiness: Codable {
    /// 模块类型（业务标识）
    public let moduleType: String
    /// 业务名称
    public let name: String
    /// iOS 跳转路由
    public let iosRoute: String
    /// 关键词列表
    public let keywords: [String]

    /// 关键词 + 路由的组合列表
    /// - 由 `keywords` 与 `iosRoute` 在解码时派生生成，不直接来自 JSON
    public let keywordsList: [IMMessageKeywords]

    public init(from decoder: Swift.Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.moduleType = try container.decode(String.self, forKey: .moduleType)
        self.name = try container.decode(String.self, forKey: .name)
        self.iosRoute = try container.decode(String.self, forKey: .iosRoute)
        self.keywords = try container.decode([String].self, forKey: .keywords)

        // ⚠️ 语义确认点：
        //   这里把每个 keyword 都配上同一个 iosRoute。
        //   - 若协议是"同一业务下的多个搜索词共用一条路由"，这是正确的
        //   - 若协议是"每个关键词有各自的路由"，这里就错了
        //   从字段名 iosRoute（单数）看，更像是"共用"，但建议注释明确。
        let routeTemp = self.iosRoute
        self.keywordsList = keywords.map {
            IMMessageKeywords(text: $0, route: routeTemp)
        }
    }

    // ⚠️ 只实现了 init(from:)，没实现 encode(to:)。
    //   Swift 会为 Codable 合成 encode，但合成的 CodingKeys 只含
    //   moduleType/name/iosRoute/keywords（不含 keywordsList，因为它是派生字段）。
    //   若需要完整往返序列化，需显式实现 encode(to:)；
    //   若只解码不编码，当前写法可接受，但建议加注释说明"仅用于解码"。
}

/// 关键词 + 路由
public struct IMMessageKeywords: Codable {
    public let text: String
    public let route: String
}
