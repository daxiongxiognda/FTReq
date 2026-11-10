//
//  MomentVideoDownloadRemove.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/29.
//

import FTTool

// MARK: - 动态视频下载删除请求

/// 删除/移除动态视频下载记录的请求
/// - 标准 Codable，属性名即 JSON key
/// - ids 可选：传具体 id 列表表示删除这些记录；nil 的语义需确认（删除全部？不操作？）
public struct TMomentVideoDownloadRemoveReq: Encodable {
    /// 要删除的视频下载记录 id 列表
    public var ids: [Int64]?

    public init(ids: [Int64]? = nil) {
        self.ids = ids
    }
}

// MARK: - 系统字典：活动分类

/// 系统字典项（活动分类场景）
/// - 遵循 `DynamicCodable`：手动映射 JSON 字段
/// - 典型字典表结构：dictCode 区分字典类型，dictValue 是值，dictLabel 是展示文案
public struct TSysDictListActivityCategoryGetData: DynamicCodable {

    /// 记录 id
    public var id: Int64 = 0

    /// 字典编码（区分不同字典/分类）
    public var dictCode: Int64 = 0

    /// 排序值（越小越靠前，具体规则需确认）
    public var dictSort: Int64 = 0

    /// 字典标签（展示文案）
    public var dictLabel = ""

    /// 字典值（业务实际使用的值）
    public var dictValue = ""

    /// 图标 URL
    /// ⚠️ Swift 属性 icoURL，JSON key icoUrl（URL→Url）
    public var icoURL = ""

    /// 默认图片 URL
    public var defaultImage = ""

    /// 是否默认项
    /// ⚠️ 类型是 String 而不是 Bool/Int：服务端可能返回 "1"/"0"、"true"/"false" 等，
    ///    使用方需要自己判断，容易写错。若协议固定是 "0"/"1"，建议抽成计算属性
    public var isDefault = ""

    public init() {}

    /// 编码：逐字段写入
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.dictCode, forKey: "dictCode", in: &container)
        try encodeAny(self.dictSort, forKey: "dictSort", in: &container)
        try encodeAny(self.dictLabel, forKey: "dictLabel", in: &container)
        try encodeAny(self.dictValue, forKey: "dictValue", in: &container)
        try encodeAny(self.icoURL, forKey: "icoUrl", in: &container)
        try encodeAny(self.defaultImage, forKey: "defaultImage", in: &container)
        try encodeAny(self.isDefault, forKey: "isDefault", in: &container)
    }

    /// 解码：逐字段硬解
    /// ⚠️ 风险：8 个字段全部 `try decodeField` 硬解。
    ///    字典项里 `icoURL`、`defaultImage`、`isDefault` 这些"可选展示字段"
    ///    服务端可能不下发（如纯文字分类没有图标），任一缺失会让整条字典解析失败，
    ///    进而导致分类列表空白。
    ///    建议这几个字段用 `try?` + 默认值兜底。
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.dictCode = try decodeField("dictCode", from: container)
        self.dictSort = try decodeField("dictSort", from: container)
        self.dictLabel = try decodeField("dictLabel", from: container)
        self.dictValue = try decodeField("dictValue", from: container)
        self.icoURL = try decodeField("icoUrl", from: container)
        self.defaultImage = try decodeField("defaultImage", from: container)
        self.isDefault = try decodeField("isDefault", from: container)
    }
}
