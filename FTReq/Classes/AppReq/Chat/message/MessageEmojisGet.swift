//
//  MessageEmojisGet.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/28.
//

import FTTool


// MARK: - 表情包列表数据（响应）

/// 表情包/收藏表情列表数据
/// - 遵循 `DynamicCodable`：手动映射 JSON 字段（JSON key 与 Swift 属性基本同名）
/// - 包含一个表情列表 + 版本号 + 首尾标记
public struct TMessageEmojisGetData: DynamicCodable {

    /// 表情（收藏表情/表情包）列表
    public var collectList = [TMessageEmojisGetEmojisListItem]()

    /// 列表版本号
    /// - 用于增量同步/判断是否需要刷新，服务端版本变化时客户端应重新拉取
    public var collectVersion = 0

    /// 列表首标识（第一条表情的 key）
    public var collectFirst = ""

    /// 列表尾标识（最后一条表情的 key）
    public var collectLast = ""

    public init() {}

    /// 编码：逐字段写入
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.collectList, forKey: "collectList", in: &container)
        try encodeAny(self.collectVersion, forKey: "collectVersion", in: &container)
        try encodeAny(self.collectFirst, forKey: "collectFirst", in: &container)
        try encodeAny(self.collectLast, forKey: "collectLast", in: &container)
    }

    /// 解码：逐字段硬解
    /// ⚠️ 风险：4 个字段全部 `try decodeField` 硬解。
    ///    如果服务端在"无表情/空列表"场景不下发 collectFirst/collectLast（或不下发 collectVersion），
    ///    整个表情列表解析就会失败，导致表情面板空白。
    ///    建议对 collectVersion/collectFirst/collectLast 这类"辅助标记"字段容错：
    ///    `(try? decodeField(...)) ?? 默认值`，collectList 也可缺省为空数组。
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.collectList = try decodeField("collectList", from: container)
        self.collectVersion = try decodeField("collectVersion", from: container)
        self.collectFirst = try decodeField("collectFirst", from: container)
        self.collectLast = try decodeField("collectLast", from: container)
    }
}


// MARK: - 表情单项

/// 单个表情/表情包条目
/// - emojisKey 是表情的唯一标识
/// - url / cdnURL 是原图与 CDN 地址
/// - preEmojisKey / nextEmojisKey 用于列表内前后导航
/// - emoteBagID 关联所属表情包
public struct TMessageEmojisGetEmojisListItem: DynamicCodable {

    /// 表情唯一 key（主标识）
    public var emojisKey = ""

    /// 表情原始 URL
    public var url = ""

    /// 表情 CDN URL（优先用这个，加载更快）
    /// ⚠️ Swift 属性是 `cdnURL`，JSON key 是 `cdnUrl`（ID→Id 转换），
    ///    编码/解码时已做对应，OK；注意别在别处误写成 "cdnURL"
    public var cdnURL = ""

    /// 表情名称
    public var name = ""

    /// 上一个表情的 key（用于面板内导航/预加载）
    public var preEmojisKey = ""

    /// 下一个表情的 key
    public var nextEmojisKey = ""

    /// 扩展信息（JSON 字符串或业务自定义内容，具体格式由协议约定）
    /// ⚠️ 这里用 String 承载，若服务端下发的是对象/数组，
    ///    需要额外解析，不能直接当普通字符串用
    public var extra = ""

    /// 所属表情包 id
    /// ⚠️ Swift 属性 `emoteBagID`，JSON key `emoteBagId`（ID→Id）
    public var emoteBagID = ""

    public init() {}

    /// 编码：逐字段写入
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.emojisKey, forKey: "emojisKey", in: &container)
        try encodeAny(self.url, forKey: "url", in: &container)
        try encodeAny(self.cdnURL, forKey: "cdnUrl", in: &container)
        try encodeAny(self.name, forKey: "name", in: &container)
        try encodeAny(self.preEmojisKey, forKey: "preEmojisKey", in: &container)
        try encodeAny(self.nextEmojisKey, forKey: "nextEmojisKey", in: &container)
        try encodeAny(self.extra, forKey: "extra", in: &container)
        try encodeAny(self.emoteBagID, forKey: "emoteBagId", in: &container)
    }

    /// 解码：逐字段硬解
    /// ⚠️ 风险：8 个字段全部硬解，且都是非可选 String（默认空串）。
    ///    表情条目里 `preEmojisKey`/`nextEmojisKey`（首尾项没有前/后）、`extra`
    ///    这些字段服务端很可能不下发，硬解会导致**整个表情列表解析失败**。
    ///    建议这几个字段用 `try?` + 空串兜底，保证单个字段缺失不影响整体。
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.emojisKey = try decodeField("emojisKey", from: container)
        self.url = try decodeField("url", from: container)
        self.cdnURL = try decodeField("cdnUrl", from: container)
        self.name = try decodeField("name", from: container)
        self.preEmojisKey = try decodeField("preEmojisKey", from: container)
        self.nextEmojisKey = try decodeField("nextEmojisKey", from: container)
        self.extra = try decodeField("extra", from: container)
        self.emoteBagID = try decodeField("emoteBagId", from: container)
    }
}
