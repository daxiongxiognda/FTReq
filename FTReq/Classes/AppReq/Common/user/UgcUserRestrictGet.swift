//
//  UgcUserRestrictGet.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/28.
//

import FTTool

// MARK: - UGC 限制查询请求

/// 查询 UGC 限制信息的请求体
/// - 遵循 `Encodable`（标准 Codable）：属性名直接作为 JSON key
/// - `restrictUserId` 为可选：
///   - 传具体 id：查"我与该用户"的限制关系
///   - 传 nil：可能表示查"当前用户的限制列表/整体限制状态"（需以服务端协议为准）
public struct TUgcUserRestrictGetReq: Encodable {
    /// 目标用户 id（可选）
    public var restrictUserId: Int64?

    public init(restrictUserId: Int64? = nil) {
        self.restrictUserId = restrictUserId
    }
}


// MARK: - UGC 限制查询结果

/// UGC 限制查询结果
/// - `offOrOn`：限制开关（0 关闭 / 1 开启）
/// - `restrict`：限制详情记录
public struct TUgcUserRestrictGetData: DynamicCodable {

    /// 限制开关
    /// ⚠️ 用 Int 而非 Bool，0/1 语义靠约定；
    ///    建议用下方 `isRestricted` 计算属性判断，避免调用点写魔法数字
    public var offOrOn = 0

    /// 限制详情
    /// 注意：无限制关系或服务端只返回开关时，该字段可能不下发或为 null，
    /// 解码时需容错（见 decodeMapping）
    public var restrict = TUgcUserRestrictGetUgcUserRestrict()

    public init() {}

    /// 是否处于限制状态（offOrOn == 1）
    public var isRestricted: Bool {
        return offOrOn == 1
    }

    /// 编码：写入开关与详情
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.offOrOn, forKey: "offOrOn", in: &container)
        try encodeAny(self.restrict, forKey: "restrict", in: &container)
    }

    /// 解码：读取开关与详情
    /// ⚠️ 关键容错点：
    ///   `restrict` 是限制详情，"无限制"或"只返回开关"时服务端很可能不下发该字段或给 null，
    ///   若用 `try decodeField` 硬解会抛错，导致整个查询结果解析失败。
    ///   因此这里对 `offOrOn` 与 `restrict` 都做容错：缺失时回退默认值。
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        // 开关容错：缺失视为关闭（0）
        self.offOrOn = (try? decodeField("offOrOn", from: container)) ?? 0
        // 详情容错：缺失时保留默认空结构
        self.restrict = (try? decodeField("restrict", from: container)) ?? TUgcUserRestrictGetUgcUserRestrict()
    }
}


// MARK: - UGC 限制详情记录

/// 单条 UGC 限制记录
/// - 描述"谁（userID）限制/拉黑了谁（blockUserID）"
/// - ⚠️ 注意：字段名仍沿用 `blockUserID`（而非 restrictUserID），
///   与拉黑结构 `TUgcUserBlockGetUgcUserBlock` 字段完全一致，
///   说明服务端复用了同一张表/同一套字段命名，注释里应说明"限制"语义
public struct TUgcUserRestrictGetUgcUserRestrict: DynamicCodable {

    /// 记录唯一 id
    public var id: Int64 = 0

    /// 记录创建时间戳（秒）
    public var createdAt: Int64 = 0

    /// 记录更新时间戳（秒）
    public var updatedAt: Int64 = 0

    /// 发起限制的用户 id
    public var userID: Int64 = 0

    /// 被限制的用户 id
    /// ⚠️ 字段名是 blockUserID（沿用拉黑命名），语义上是"被限制者"，
    ///   不是"被拉黑者"；阅读代码时勿与 TBlockStatusE 混淆
    public var blockUserID: Int64 = 0

    public init() {}

    /// 编码：逐字段写入
    /// Swift 属性 userID / blockUserID 对应 JSON key userId / blockUserId（ID→Id）
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.createdAt, forKey: "createdAt", in: &container)
        try encodeAny(self.updatedAt, forKey: "updatedAt", in: &container)
        try encodeAny(self.userID, forKey: "userId", in: &container)
        try encodeAny(self.blockUserID, forKey: "blockUserId", in: &container)
    }

    /// 解码：逐字段读取
    /// ⚠️ 硬解：缺任一字段会抛错。
    ///    作为"详情记录"，服务端下发时字段通常完整；若存在
    ///    "开关打开但详情未就绪"的场景，建议对 id/时间戳等做容错
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.createdAt = try decodeField("createdAt", from: container)
        self.updatedAt = try decodeField("updatedAt", from: container)
        self.userID = try decodeField("userId", from: container)
        self.blockUserID = try decodeField("blockUserId", from: container)
    }
}
