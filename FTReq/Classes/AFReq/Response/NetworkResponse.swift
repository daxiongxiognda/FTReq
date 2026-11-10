//
//  NetworkResponse.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/27.
//

import FTTool

// ═══════════════════════════════════════════════════════════════
// MARK: - ResNil（空数据占位）
// ═══════════════════════════════════════════════════════════════

/// 空数据占位类型。
///
/// 用途：
/// - 接口返回 `data` 为空时，用 `ResNil` 作为泛型参数
/// - 如 `ResponseData<ResNil>` 表示"只关心 code/msg，不关心 data"
///
/// 对比直接用 `Void`：
/// - `Void` 不遵循 `Codable`，无法作为 `ResponseData<T: Codable>` 的泛型参数
/// - `ResNil` 是空 struct，遵循 `Codable`，完美解决
public struct ResNil: Codable {
    public init() { }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - TipLevel（提示级别）
// ═══════════════════════════════════════════════════════════════

/// 提示级别（服务端返回，决定客户端怎么提示）。
///
/// 遵循 `EnumCodable`（你之前看的枚举容错协议）：
/// - 解码失败时回退到 `defaultCase`（`.toast`）
/// - 支持 Int ↔ String 兼容转换
public enum TipLevel: Int, EnumCodable {

    /// 解码失败时的默认值。
    public static var defaultCase: TipLevel = .toast

    /// Toast 轻提示（不打断用户）。
    case toast = 0

    /// Alert 弹窗（需要用户确认）。
    case alert = 1
}

// ═══════════════════════════════════════════════════════════════
// MARK: - ResponseData（通用响应模型）
// ═══════════════════════════════════════════════════════════════

/// 通用响应模型。
///
/// 适配服务端返回的 JSON 结构：
/// ```json
/// {
///     "code": 0,
///     "msg": "success",
///     "codeLevel": 0,
///     "data": { ... },
///     "total": 100,
///     "position": 1729999999123,
///     "pageScore": 1
/// }
/// ```
///
/// 泛型 `T` 是 `data` 字段的类型（如 `User`、`[Order]`、`ResNil`）。
public struct ResponseData<T: Codable>: Codable {

    // ═══════════════════════════════════════════════════════════
    // MARK: - 业务字段
    // ═══════════════════════════════════════════════════════════

    /// 业务状态码（0 或 200 表示成功）。
    public var code: Int = 0

    /// 业务消息（如 "success"、"登录失效"）。
    public var msg: String = ""

    /// 提示级别（toast / alert）。
    public var tipLevel: TipLevel = .toast

    /// 业务数据（泛型）。
    public var model: T?

    // ═══════════════════════════════════════════════════════════
    // MARK: - 分页兼容字段（旧数据格式）
    // ═══════════════════════════════════════════════════════════

    /// 总条数（分页用）。
    public var total: Int = 0

    /// 分页游标（时间戳，用于"加载更多"）。
    public var position: Int64 = 0

    /// 分页评分（服务端排序用）。
    public var pageScore: Int = 0

    /// 分页评分的字符串形式（兼容某些接口）。
    public var pageScoreString: String = ""

    public init() {}

    // ═══════════════════════════════════════════════════════════
    // MARK: - CodingKeys（JSON key 映射）
    // ═══════════════════════════════════════════════════════════

    /// JSON key 和 Swift 属性名的映射。
    ///
    /// 关键映射：
    /// - `model` ↔ `"data"`（服务端叫 `data`，客户端叫 `model`）
    /// - `tipLevel` ↔ `"codeLevel"`（服务端叫 `codeLevel`，客户端叫 `tipLevel`）
    /// - `msg` 和 `message` 都兼容（`msg` 优先，`msg` 为空时用 `message`）
    enum CodingKeys: String, CodingKey {
        case code
        case message      // 兼容旧字段
        case msg
        case codeLevel    // 服务端叫 codeLevel
        case total
        case position
        case pageScore
        case model = "data"   // 服务端叫 data，客户端叫 model
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 编码（Encodable）
    // ═══════════════════════════════════════════════════════════

    /// 自定义编码。
    ///
    /// 只编码核心字段（code、msg、model、codeLevel），
    /// 分页字段（total / position / pageScore）不编码——它们只用于接收。
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(msg, forKey: .msg)
        try container.encode(model, forKey: .model)
        try container.encode(tipLevel, forKey: .codeLevel)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 解码（Decodable）
    // ═══════════════════════════════════════════════════════════

    /// 自定义解码（容错）。
    ///
    /// 容错策略：
    /// - `code` 缺失 → 默认 1（表示失败）
    /// - `msg` 缺失 → 默认 ""
    /// - `tipLevel` 缺失 → 默认 `.toast`
    /// - `model` 缺失/解析失败 → nil（不报错）
    /// - 分页字段缺失 → 默认 0
    /// - `msg` 为空时，尝试用 `message` 字段（兼容旧格式）
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // ① 核心字段（容错：缺失用默认值）
        code = (try? container.decode(Int.self, forKey: .code)) ?? 1
        msg = (try? container.decode(String.self, forKey: .msg)) ?? ""
        tipLevel = (try? container.decode(TipLevel.self, forKey: .codeLevel)) ?? .toast
        model = try? container.decode(T.self, forKey: .model)

        // ② 分页字段（容错）
        total = (try? container.decode(Int.self, forKey: .total)) ?? 0
        position = (try? container.decode(Int64.self, forKey: .position)) ?? 0
        pageScore = (try? container.decode(Int.self, forKey: .pageScore)) ?? 0
        pageScoreString = (try? container.decode(String.self, forKey: .pageScore)) ?? ""

        // ③ 兼容旧格式：msg 为空时用 message
        if msg.isEmpty, let message = try? container.decode(String.self, forKey: .message) {
            msg = message
        }
    }
}

/* ═══════════════════════════════════════════════════════════════
   被注释掉的旧版实现（DynamicCodable 版本）
   ═══════════════════════════════════════════════════════════════ */

// ═══════════════════════════════════════════════════════════════
// MARK: - NetworkResponse（网络响应封装）
// ═══════════════════════════════════════════════════════════════

/// 网络响应封装（类似 Alamofire 的 `AFDataResponse`，但更轻量）。
///
/// 包含：
/// - `statusCode`：HTTP 状态码
/// - `data`：响应体（Data）
/// - `request`：原始请求
/// - `response`：原始 HTTPURLResponse
public final class NetworkResponse: CustomDebugStringConvertible, Equatable {

    /// HTTP 状态码。
    public let statusCode: Int

    /// 响应数据。
    public let data: Data

    /// 原始请求（可能为 nil）。
    public let request: URLRequest?

    /// 原始 HTTP 响应（可能为 nil）。
    public let response: HTTPURLResponse?

    public init(
        statusCode: Int,
        data: Data,
        request: URLRequest? = nil,
        response: HTTPURLResponse? = nil
    ) {
        self.statusCode = statusCode
        self.data = data
        self.request = request
        self.response = response
    }

    /// 文本描述（用于日志）。
    public var description: String {
        return "Status Code: \(statusCode), Data Length: \(data.count)"
    }

    /// 调试描述（同 description）。
    public var debugDescription: String {
        return description
    }

    /// 相等判断（只比 statusCode、data、response）。
    public static func == (lhs: NetworkResponse, rhs: NetworkResponse) -> Bool {
        return lhs.statusCode == rhs.statusCode
            && lhs.data == rhs.data
            && lhs.response == rhs.response
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - NetworkResponse 扩展（过滤 / 映射）
// ═══════════════════════════════════════════════════════════════

public extension NetworkResponse {

    // ───────── 状态码过滤 ─────────

    /// 过滤指定范围的状态码，不在范围内抛错。
    func filter<R: RangeExpression>(statusCodes: R) throws -> NetworkResponse where R.Bound == Int {
        guard statusCodes.contains(statusCode) else {
            throw NetworkError.serverError("响应异常啦~", statusCode)
        }
        return self
    }

    /// 过滤指定状态码。
    func filter(statusCode: Int) throws -> NetworkResponse {
        return try filter(statusCodes: statusCode...statusCode)
    }

    /// 只接受成功状态码（200~299）。
    func filterSuccessfulStatusCodes() throws -> NetworkResponse {
        return try filter(statusCodes: 200...299)
    }

    /// 只接受成功 + 重定向状态码（200~399）。
    func filterSuccessfulStatusAndRedirectCodes() throws -> NetworkResponse {
        return try filter(statusCodes: 200...399)
    }

    // ───────── 映射 ─────────

    /// 响应数据映射为图片。
    func mapImage() throws -> NETImage {
        guard let image = NETImage(data: data) else {
            throw NetworkError.custom("图片映射失败")
        }
        return image
    }

    /// 响应数据映射为 JSON 对象。
    ///
    /// - Parameter failsOnEmptyData: 数据为空时是否失败
    func mapJSON(failsOnEmptyData: Bool = true) throws -> Any {
        do {
            return try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        } catch {
            if data.count < 1 && !failsOnEmptyData {
                return NSNull()
            }
            throw NetworkError.custom("响应数据解码为JSON对象失败")
        }
    }

    /// 响应数据映射为字符串。
    ///
    /// - Parameter keyPath: JSON 里取字符串的路径（如 "user.name"）
    func mapString(atKeyPath keyPath: String? = nil) throws -> String {
        if let keyPath = keyPath {
            // ① 从 JSON 里按 keyPath 取值
            guard let jsonDictionary = try mapJSON() as? NSDictionary,
                  let string = jsonDictionary.value(forKeyPath: keyPath) as? String else {
                throw NetworkError.custom("json数据编码字符串失败")
            }
            return string
        } else {
            // ② 直接把 Data 转字符串
            guard let string = String(data: data, encoding: .utf8) else {
                throw NetworkError.custom("json数据编码字符串失败")
            }
            return string
        }
    }

    /// 响应数据映射为 Decodable 模型。
    ///
    /// - Parameters:
    ///   - type: 目标模型类型
    ///   - keyPath: 从 JSON 的哪个路径取模型（如 "data.user"）
    ///   - decoder: JSON 解码器
    ///   - failsOnEmptyData: 数据为空时是否失败
    func map<D: Decodable>(
        _ type: D.Type,
        atKeyPath keyPath: String? = nil,
        using decoder: JSONDecoder = JSONDecoder(),
        failsOnEmptyData: Bool = true
    ) throws -> D {

        // ① 序列化闭包：JSON 对象 → Data
        let serializeToData: (Any) throws -> Data? = { jsonObject in
            guard JSONSerialization.isValidJSONObject(jsonObject) else {
                return nil
            }
            do {
                return try JSONSerialization.data(withJSONObject: jsonObject)
            } catch {
                throw NetworkError.custom("json 序列化失败")
            }
        }

        let jsonData: Data

        // ② 有 keyPath 时，从 JSON 里按路径取值
        keyPathCheck: if let keyPath = keyPath {
            guard let jsonObject = (try mapJSON(failsOnEmptyData: failsOnEmptyData) as? NSDictionary)?
                .value(forKeyPath: keyPath) else {
                if failsOnEmptyData {
                    throw NetworkError.custom("json 数据为空")
                } else {
                    jsonData = data
                    break keyPathCheck
                }
            }

            if let data = try serializeToData(jsonObject) {
                jsonData = data
            } else {
                // ③ 非 JSON 对象（如 String、Int），包一层 `{"value": ...}` 再解码
                let wrappedJsonObject = ["value": jsonObject]
                let wrappedJsonData: Data
                if let data = try serializeToData(wrappedJsonObject) {
                    wrappedJsonData = data
                } else {
                    throw NetworkError.custom("json 序列化失败")
                }
                do {
                    return try decoder.decode(DecodableWrapper<D>.self, from: wrappedJsonData).value
                } catch let error {
                    let dataStr = String(data: data, encoding: .utf8)
                    let desc = "JSON Decode error: \(dataStr ?? "data编码字符串失败")"
                    throw NetworkError.decodeError(error, desc)
                }
            }
        } else {
            // ④ 无 keyPath：直接用整个 data
            jsonData = data
        }

        // ⑤ 解码
        do {
            // 空数据兜底：尝试解成 `{}` 或 `[{}]`
            if jsonData.count < 1 && !failsOnEmptyData {
                if let emptyJSONObjectData = "{}".data(using: .utf8),
                   let emptyDecodableValue = try? decoder.decode(D.self, from: emptyJSONObjectData) {
                    return emptyDecodableValue
                } else if let emptyJSONArrayData = "[{}]".data(using: .utf8),
                          let emptyDecodableValue = try? decoder.decode(D.self, from: emptyJSONArrayData) {
                    return emptyDecodableValue
                }
            }
            return try decoder.decode(D.self, from: jsonData)
        } catch let error {
            let dataStr = String(data: data, encoding: .utf8)
            let desc = "JSON Decode error: \(dataStr ?? "data编码字符串失败")"
            throw NetworkError.decodeError(error, desc)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - DecodableWrapper（包装非对象类型）
// ═══════════════════════════════════════════════════════════════

/// 包装非对象类型（如 String、Int），用于 `map(atKeyPath:)` 解码。
private struct DecodableWrapper<T: Decodable>: Decodable {
    let value: T
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 跨平台图片类型
// ═══════════════════════════════════════════════════════════════

#if canImport(UIKit)
    import UIKit.UIImage
    public typealias ImageType = UIImage
#elseif canImport(AppKit)
    import AppKit.NSImage
    public typealias ImageType = NSImage
#endif

/// 跨平台图片类型别名（iOS = UIImage，macOS = NSImage）。
public typealias NETImage = ImageType
