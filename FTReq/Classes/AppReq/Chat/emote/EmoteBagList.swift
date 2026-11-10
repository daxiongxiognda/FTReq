//
//  EmoteBagList.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/28.
//

import FTTool

/// 表情包列表中的单个表情包条目
/// - 遵循 `DynamicCodable`：手动映射 JSON 字段
/// - Swift 属性用大写 URL，JSON key 用 `coverUrl`/`backgroundUrl`（URL→Url 转换）
public struct TEmoteBagListEmotebaglist: DynamicCodable {

    /// 表情包唯一 id
    public var id = ""

    /// 表情包名称
    public var name = ""

    /// 表情包描述
    public var description = ""

    /// 封面图 URL
    /// ⚠️ Swift 属性 `coverURL`，JSON key `coverUrl`（URL→Url）
    public var coverURL = ""

    /// 价格
    /// ⚠️ 用 Double 表示金额，需确认协议单位是"元"还是"分"。
    ///    若服务端下发整数分、客户端按 Double 元处理，会出现 100 倍差异；
    ///    反之亦然。金额类字段建议在协议层面明确单位，或用 Int64（分）存储避免浮点精度问题
    public var price = 0.0

    /// 更新时间戳（秒）
    public var updatedAt: Int64 = 0

    /// 创建时间戳（秒）
    public var createdAt: Int64 = 0

    /// 背景图 URL
    public var backgroundURL = ""

    public init() {}

    /// 编码：逐字段写入
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.name, forKey: "name", in: &container)
        try encodeAny(self.description, forKey: "description", in: &container)
        try encodeAny(self.coverURL, forKey: "coverUrl", in: &container)
        try encodeAny(self.price, forKey: "price", in: &container)
        try encodeAny(self.updatedAt, forKey: "updatedAt", in: &container)
        try encodeAny(self.createdAt, forKey: "createdAt", in: &container)
        try encodeAny(self.backgroundURL, forKey: "backgroundUrl", in: &container)
    }

    /// 解码：逐字段硬解
    /// ⚠️ 风险：8 个字段全部 `try decodeField` 硬解，
    ///    其中 `description`、`backgroundURL`、`price` 这类字段服务端可能不下发
    ///    （如免费表情包没有价格、无背景图），任一缺失都会让整个条目解析失败，
    ///    进而导致整个表情包列表解析失败、面板空白。
    ///    建议对这些"可选语义"字段用 `try?` + 默认值兜底：
    ///    - description → ""
    ///    - backgroundURL → ""
    ///    - price → 0.0
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.name = try decodeField("name", from: container)
        self.description = try decodeField("description", from: container)
        self.coverURL = try decodeField("coverUrl", from: container)
        self.price = try decodeField("price", from: container)
        self.updatedAt = try decodeField("updatedAt", from: container)
        self.createdAt = try decodeField("createdAt", from: container)
        self.backgroundURL = try decodeField("backgroundUrl", from: container)
    }
}
