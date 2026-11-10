//
//  RedPacketInfoModel.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/28.
//

import FTTool

// MARK: - 红包状态

/// 红包领取状态
/// - 遵循 `EnumCodable` + `Int`,未知值回退到 `defaultCase`(.notCollected)
public enum TIMRedPacketState: Int, EnumCodable {
    public static var defaultCase: TIMRedPacketState = .notCollected

    /// 未领取
    case notCollected = 0
    /// 已领取(我领了,但红包未抢完)
    case collected = 1
    /// 已领完(红包被抢光)
    case finishCollected = 2
    /// 已过期
    case expired = 3
}

// MARK: - 红包类型

/// 红包玩法类型
public enum TIMRedPacketType: Int, EnumCodable {
    public static var defaultCase: TIMRedPacketType = .singleChatPerson

    /// 单聊个人红包
    case singleChatPerson = 0
    /// 群聊普通红包(均分)
    case groupChatNormal = 1
    /// 群聊拼手气红包(随机)
    case groupChatLuck = 2
}

// MARK: - 红包币种

/// 红包使用的钱包币种
public enum TIMRedPacketCurrencyType: Int, EnumCodable {
    public static var defaultCase: TIMRedPacketCurrencyType = .none

    /// 无/未指定
    case none = 0
    /// 通宝
    case tongbao = 1
    /// 通钻
    case tongzuan = 2
    /// 现金
    case cash = 3
}

// MARK: - 红包数据

/// 红包消息的业务数据(挂在消息 content 里)
/// - 遵循 `DynamicCodable`:手动映射 JSON 字段
/// - JSON key 使用小驼峰(ID→Id),Swift 属性用大写 ID
public struct TIMRedPacketData: DynamicCodable {

    // MARK: 字段

    /// 红包 id
    public var redPacketID: Int64 = 0
    /// 发送者 id
    public var senderID: Int64 = 0
    /// 红包封面标题(如"恭喜发财")
    public var coverTitle = ""
    /// 红包玩法类型
    public var redPacketType: TIMRedPacketType = .defaultCase
    /// 币种
    public var walletAppCurrencyType: TIMRedPacketCurrencyType = .defaultCase
    /// 总金额
    public var totalAmount = 0.0
    /// 总份数
    public var totalPacket: Int64 = 0
    /// 剩余份数
    public var remainingPacket: Int64 = 0
    /// 过期时间戳(秒)
    public var expiry: Int64 = 0
    /// 拼手气持续时长(秒)
    public var scrambleDuration: Int64 = 0
    /// 已抢到金额(当前用户维度)
    public var scrambleAmount = 0.0
    /// 是否是我发的红包
    public var isMe = false
    /// 是否已过期
    /// ⚠️ 与 state(.expired) 语义重叠:过期状态有两处表达,
    ///    可能出现 isExpires=true 但 state 仍为 notCollected 的不一致
    public var isExpires = false
    /// 领取状态
    public var state: TIMRedPacketState = .defaultCase

    public init() {}

    // MARK: - 编码

    /// 编码为 JSON(逐字段写入)
    /// ⚠️ 注意:
    ///   1. 浮点 totalAmount/scrambleAmount 用 encodeAny 写入,
    ///      若服务端约定金额为"分"的整数,这里以 Double 直接写会精度/单位不匹配,
    ///      需确认协议:金额到底是元(Double)还是分(Int64)
    ///   2. 字段顺序与 decodeMapping 完全一致,便于核对,这点写得好
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.redPacketID, forKey: "redPacketId", in: &container)
        try encodeAny(self.senderID, forKey: "senderId", in: &container)
        try encodeAny(self.coverTitle, forKey: "coverTitle", in: &container)
        try encodeAny(self.redPacketType, forKey: "redPacketType", in: &container)
        try encodeAny(self.walletAppCurrencyType, forKey: "walletAppCurrencyType", in: &container)
        try encodeAny(self.totalAmount, forKey: "totalAmount", in: &container)
        try encodeAny(self.totalPacket, forKey: "totalPacket", in: &container)
        try encodeAny(self.remainingPacket, forKey: "remainingPacket", in: &container)
        try encodeAny(self.expiry, forKey: "expiry", in: &container)
        try encodeAny(self.scrambleDuration, forKey: "scrambleDuration", in: &container)
        try encodeAny(self.scrambleAmount, forKey: "scrambleAmount", in: &container)
        try encodeAny(self.isMe, forKey: "isMe", in: &container)
        try encodeAny(self.isExpires, forKey: "isExpires", in: &container)
        try encodeAny(self.state, forKey: "state", in: &container)
    }

    // MARK: - 解码

    /// 从 JSON 解码(逐字段读取)
    /// ⚠️ 问题:
    ///   1. 全部用 `try decodeField` 硬解,服务端缺任一字段(如 isMe/isExpires 这类
    ///      前端派生字段)都会抛错,导致整条红包消息解析失败。
    ///      isMe/isExpires 更像"客户端计算/缓存"字段,服务端未必下发,
    ///      建议这两个用 `decodeFieldIfPresent` + 默认 false。
    ///   2. `redPacketType`/`walletAppCurrencyType`/`state` 依赖 EnumCodable 容错,
    ///      未知枚举值会回退 defaultCase,不会抛错,这点是好的。
    ///   3. 金额若服务端是整数分,decodeField 到 Double 可能类型不匹配抛错,
    ///      需确认协议字段类型。
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.redPacketID = try decodeField("redPacketId", from: container)
        self.senderID = try decodeField("senderId", from: container)
        self.coverTitle = try decodeField("coverTitle", from: container)
        self.redPacketType = try decodeField("redPacketType", from: container)
        self.walletAppCurrencyType = try decodeField("walletAppCurrencyType", from: container)
        self.totalAmount = try decodeField("totalAmount", from: container)
        self.totalPacket = try decodeField("totalPacket", from: container)
        self.remainingPacket = try decodeField("remainingPacket", from: container)
        self.expiry = try decodeField("expiry", from: container)
        self.scrambleDuration = try decodeField("scrambleDuration", from: container)
        self.scrambleAmount = try decodeField("scrambleAmount", from: container)
        self.isMe = try decodeField("isMe", from: container)
        self.isExpires = try decodeField("isExpires", from: container)
        self.state = try decodeField("state", from: container)
    }
}
