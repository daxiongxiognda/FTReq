//
//  BlockPost.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/28.
//

import FTTool

// MARK: - 拉黑状态

/// 用户间拉黑关系状态
/// - 遵循 `EnumCodable`：Int 原始值，未知值解码回退到 `defaultCase`(.none)
/// - 语义说明：
///   - none：双方均未拉黑
///   - blocked：我拉黑了对方
///   - beBlocked：对方拉黑了我
///   - bothBlock：双方互相拉黑
public enum TBlockStatusE: Int, EnumCodable {
    public static var defaultCase: TBlockStatusE = .none

    /// 无拉黑关系
    case none = 0
    /// 我拉黑了对方（我主动拉黑）
    case blocked = 1
    /// 对方拉黑了我（我被拉黑）
    case beBlocked = 2
    /// 互相拉黑
    case bothBlock = 3
}


// MARK: - 拉黑操作请求体

/// 拉黑/取消拉黑请求的数据体
/// - 遵循 `DynamicCodable`：手动映射 JSON
/// - 目前仅含"目标拉黑状态"一个字段，即请求要把关系设置成什么状态
///   （例如设置 blocked 表示拉黑，设置 none 表示取消拉黑）
public struct TBlockPostData: DynamicCodable {

    /// 目标拉黑状态
    /// ⚠️ 语义需确认：这是"要设置成的目标状态"还是"当前状态"？
    ///    作为 Post 请求体，通常是"目标状态"，但字段名 blockStatus 未体现"目标"含义，
    ///    建议改为 targetStatus 或在注释中明确
    public var blockStatus: TBlockStatusE = .defaultCase

    public init() {}

    /// 编码：写入 blockStatus
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.blockStatus, forKey: "blockStatus", in: &container)
    }

    /// 解码：读取 blockStatus
    /// ⚠️ 硬解：服务端缺 blockStatus 字段会抛错。
    ///    但作为请求体，一般由客户端构造后发出，不常从服务端解码，
    ///    风险相对低；若该结构也被复用作响应解析，则应容错。
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.blockStatus = try decodeField("blockStatus", from: container)
    }
}
