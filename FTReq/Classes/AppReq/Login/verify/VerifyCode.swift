//
//  VerifyCode.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/30.
//

import FTTool

// MARK: - 手机号信息

/// 手机号信息（标准 Codable）
/// - 属性为可选，init 参数为非可选且默认空串
/// - 注意：默认构造时字段为 ""（非 nil），编码时会输出空字符串 key
public struct TPhoneMessagePhoneMessage: Encodable {
    /// 完整号码（可能含区号）
    public var number: String?
    /// 国家区号（如 "+86"）
    public var countryPrefix: String?
    /// 国内号码（不含区号）
    public var nationalNumber: String?

    public init(number: String = "", countryPrefix: String = "", nationalNumber: String = "") {
        self.number = number
        self.countryPrefix = countryPrefix
        self.nationalNumber = nationalNumber
    }
}

// MARK: - 强制更新数据

/// 强制更新接口返回的版本信息
/// - 遵循 `DynamicCodable`：手动映射 JSON，appStoreURL 属性 → JSON key 的 appStoreUrl
public struct TForceUpdateGetData: DynamicCodable {
    /// App Store 下载地址
    public var appStoreURL = ""
    /// 允许的最低版本（低于此版本必须更新）
    public var allowLowestVersion = ""
    /// 更新提示文案
    public var description = ""
    /// 是否强制更新（0/1，具体语义以协议为准）
    public var forceUpdate = 0
    /// 最新版本号（如 "1.2.3"）
    public var version = ""
    /// 弹窗展示样式（取值含义以协议为准）
    public var displayStyle = 0

    public init() {}

    /// 编码：逐字段写入
    public func encodeMapping(with container: inout KeyedEncodingContainer<JSONCodingKeys>) throws {
        try encodeAny(self.appStoreURL, forKey: "appStoreUrl", in: &container)
        try encodeAny(self.allowLowestVersion, forKey: "allowLowestVersion", in: &container)
        try encodeAny(self.description, forKey: "description", in: &container)
        try encodeAny(self.forceUpdate, forKey: "forceUpdate", in: &container)
        try encodeAny(self.version, forKey: "version", in: &container)
        try encodeAny(self.displayStyle, forKey: "displayStyle", in: &container)
    }

    /// 解码：逐字段硬解
    /// - 注意：服务端任一字段缺失都会导致解析失败，使用方需保证协议完整
    public mutating func decodeMapping(with container: KeyedDecodingContainer<JSONCodingKeys>) throws {
        self.appStoreURL = try decodeField("appStoreUrl", from: container)
        self.allowLowestVersion = try decodeField("allowLowestVersion", from: container)
        self.description = try decodeField("description", from: container)
        self.forceUpdate = try decodeField("forceUpdate", from: container)
        self.version = try decodeField("version", from: container)
        self.displayStyle = try decodeField("displayStyle", from: container)
    }
}
