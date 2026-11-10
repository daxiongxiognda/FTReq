//
//  VerifyEnter.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/30.
//

import FTTool

// MARK: - 请求：手机验证码登录

/// 手机验证码登录/注册的请求参数（标准 Codable）
/// - 三个字段全可选，按场景组合：手机号+验证码登录，或手机号+短信类型发验证码
public struct TVerifyEnterRequestReq: Encodable {
    /// 手机号信息（区号+号码）
    public var phone: TPhoneMessagePhoneMessage?
    /// 短信验证码
    public var code: String?
    /// 短信验证类型（登录/注册/绑定等，具体取值由协议约定）
    public var smsVerifyType: String?

    public init(phone: TPhoneMessagePhoneMessage? = nil,
                code: String? = nil,
                smsVerifyType: String? = nil) {
        self.phone = phone
        self.code = code
        self.smsVerifyType = smsVerifyType
    }
}

// MARK: - 响应：登录结果

/// 手机验证码登录的响应数据
/// - 遵循 `DynamicCodable`：手动映射 JSON，userID 属性 → JSON key 的 userId
public struct TVerifyEnterRequestData: DynamicCodable {

    /// 用户 id
    public var userID: Int64 = 0

    /// 访问 token（后续请求的鉴权凭证）
    public var token = ""

    /// 刷新 token（access token 过期时用它换新 token）
    public var refreshToken = ""

    /// 手机号
    public var phoneNumber = ""

    /// 邀请码是否已验证
    public var invitationCodeVerified = false

    /// 是否为新注册用户
    public var register = false

    /// 是否为游客
    public var guest = false

    /// 是否新创建（与 register 语义需区分，见下方说明）
    /// ⚠️ `register` 和 `newCreate` 语义容易混：
    ///   register 通常表示"本次是注册流程"，newCreate 可能表示"账号是新建的"，
    ///   两者可能同时为 true，也可能一个为 true 一个为 false，需以协议为准
    public var newCreate = false

    public init() {}

    /// 编码：逐字段写入
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.userID, forKey: "userId", in: &container)
        try encodeAny(self.token, forKey: "token", in: &container)
        try encodeAny(self.refreshToken, forKey: "refreshToken", in: &container)
        try encodeAny(self.phoneNumber, forKey: "phoneNumber", in: &container)
        try encodeAny(self.invitationCodeVerified, forKey: "invitationCodeVerified", in: &container)
        try encodeAny(self.register, forKey: "register", in: &container)
        try encodeAny(self.guest, forKey: "guest", in: &container)
        try encodeAny(self.newCreate, forKey: "newCreate", in: &container)
    }

    /// 解码：逐字段硬解
    /// ⚠️ 风险：8 个字段全部 `try decodeField` 硬解。
    ///    这是登录的核心响应，其中 `invitationCodeVerified`、`register`、`guest`、`newCreate`
    ///    这些"流程标记"字段，服务端在部分场景（如老用户直接登录）可能不下发，
    ///    任一缺失会让整个登录结果解析失败 → 登录流程中断。
    ///    建议这几个字段用 `try?` + 默认 false 兜底；
    ///    而 `userID`、`token` 这类核心字段应保持硬解（缺失即登录无效）。
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.userID = try decodeField("userId", from: container)
        self.token = try decodeField("token", from: container)
        self.refreshToken = try decodeField("refreshToken", from: container)
        self.phoneNumber = try decodeField("phoneNumber", from: container)
        self.invitationCodeVerified = try decodeField("invitationCodeVerified", from: container)
        self.register = try decodeField("register", from: container)
        self.guest = try decodeField("guest", from: container)
        self.newCreate = try decodeField("newCreate", from: container)
    }
}
