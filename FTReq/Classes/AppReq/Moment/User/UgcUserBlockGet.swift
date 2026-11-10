//
//  UgcUserBlockGet.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/28.
//

import FTTool

// MARK: - UGC 拉黑查询请求

/// 查询 UGC 拉黑信息的请求体
/// - 遵循 `Encodable`（标准 Codable）：属性名直接作为 JSON key，无需手动映射
/// - `blockUserId` 是查询的目标用户 id（即"要查我和谁之间的拉黑关系"）
/// - 注意：标准 Codable 不做 `ID→Id` 转换，输出 key 就是属性名 `blockUserId`，
///   与服务端约定一致；若其他结构里属性写成 `blockUserID`，输出会变成
///   `blockUserID` 导致与服务端不匹配，需保持命名一致
public struct TUgcUserBlockGetReq: Encodable {
    /// 目标用户 id（被查询拉黑关系的对方）
    public var blockUserId: Int64 = 0

    public init(blockUserId: Int64 = 0) {
        self.blockUserId = blockUserId
    }
}


// MARK: - UGC 拉黑查询结果

/// UGC 拉黑查询结果
/// - `offOrOn`：拉黑开关（0 关闭 / 1 开启）
/// - `block`：拉黑详情记录（谁拉黑了谁、记录元信息）
public struct TUgcUserBlockGetData: DynamicCodable {

    /// 拉黑开关
    /// ⚠️ 用 Int 而非 Bool，0/1 语义靠约定；若服务端可能返回其他值需额外处理。
    ///    建议用下方的 `isBlocked` 计算属性做判断，避免调用点写魔法数字。
    public var offOrOn = 0

    /// 拉黑详情
    /// 注意：未拉黑或服务端只返回开关时，该字段可能不下发或为 null，
    /// 解码时需容错（见 decodeMapping）
    public var block = TUgcUserBlockGetUgcUserBlock()

    public init() {}

    /// 是否处于拉黑状态（offOrOn == 1）
    /// 提供给 UI/业务层直接判断，避免到处写 `offOrOn == 1`
    public var isBlocked: Bool {
        return offOrOn == 1
    }

    /// 编码：写入开关与详情
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.offOrOn, forKey: "offOrOn", in: &container)
        try encodeAny(self.block, forKey: "block", in: &container)
    }

    /// 解码：读取开关与详情
    /// ⚠️ 关键容错点：
    ///   `block` 是拉黑详情，"未拉黑"或"只返回开关"时服务端很可能不下发该字段或给 null，
    ///   若用 `try decodeField` 硬解会抛错，导致整个查询结果解析失败。
    ///   因此这里对 `offOrOn` 与 `block` 都做容错：缺失时回退默认值。
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        // 开关容错：缺失视为关闭（0）
        self.offOrOn = (try? decodeField("offOrOn", from: container)) ?? 0
        // 详情容错：缺失时保留默认空结构
        self.block = (try? decodeField("block", from: container)) ?? TUgcUserBlockGetUgcUserBlock()
    }
}


// MARK: - UGC 拉黑详情记录

/// 单条拉黑记录
/// - 描述"谁（userID）拉黑了谁（blockUserID）"
/// - id / createdAt / updatedAt 为记录本身的元信息
public struct TUgcUserBlockGetUgcUserBlock: DynamicCodable {

    /// 记录唯一 id
    public var id: Int64 = 0

    /// 记录创建时间戳（秒）
    public var createdAt: Int64 = 0

    /// 记录更新时间戳（秒）
    public var updatedAt: Int64 = 0

    /// 发起拉黑的用户 id（拉黑动作的发起者）
    public var userID: Int64 = 0

    /// 被拉黑的用户 id（拉黑动作的目标）
    public var blockUserID: Int64 = 0

    public init() {}

    /// 编码：逐字段写入
    /// 注意 Swift 属性 `userID` / `blockUserID` 对应 JSON key `userId` / `blockUserId`，
    /// 即 `ID → Id` 的命名转换，与请求体 `TUgcUserBlockGetReq` 的 `blockUserId` 保持一致
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.id, forKey: "id", in: &container)
        try encodeAny(self.createdAt, forKey: "createdAt", in: &container)
        try encodeAny(self.updatedAt, forKey: "updatedAt", in: &container)
        try encodeAny(self.userID, forKey: "userId", in: &container)
        try encodeAny(self.blockUserID, forKey: "blockUserId", in: &container)
    }

    /// 解码：逐字段读取
    /// ⚠️ 硬解：缺任一字段会抛错。
    ///    作为"详情记录"，服务端下发时字段通常完整；但若该结构也用于
    ///    "开关打开但详情未就绪"的场景，建议对 id/时间戳等做容错
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.id = try decodeField("id", from: container)
        self.createdAt = try decodeField("createdAt", from: container)
        self.updatedAt = try decodeField("updatedAt", from: container)
        self.userID = try decodeField("userId", from: container)
        self.blockUserID = try decodeField("blockUserId", from: container)
    }
}
