//
//  ParameterEncoder.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/26.
//

import Alamofire

// ═══════════════════════════════════════════════════════════════
// MARK: - DataBodyEncoder（直接传 Data 的参数编码器）
// ═══════════════════════════════════════════════════════════════

/// 自定义参数编码器：直接把 `Data` 设置到 HTTP Body。
///
/// 用途：
/// - 上传二进制数据（protobuf、图片、文件）
/// - 某些接口要求 `Content-Type: application/octet-stream`
///
/// 为什么需要：
/// - Alamofire 内置的 `JSONParameterEncoder` / `URLEncodedFormParameterEncoder`
///   都是把参数编码成 JSON / URL query，无法直接传 `Data`
/// - 需要自定义 `ParameterEncoder` 实现
///
/// 使用场景（结合 `ApiConvertable.encoder`）：
/// ```swift
/// var encoder: ParameterEncoder {
///     if let _ = parameters as? Data {
///         return DataBodyEncoder()   // 参数是 Data，用这个
///     }
///     // ...
/// }
/// ```
public struct DataBodyEncoder: ParameterEncoder {

    /// Content-Type 请求头。
    ///
    /// - 默认 `application/octet-stream`：通用二进制
    /// - 也可以是 `application/x-protobuf`（protobuf 数据）
    /// - 或 `image/jpeg`、`application/pdf` 等
    let contentType: String

    /// 初始化。
    ///
    /// - Parameter contentType: Content-Type 请求头，默认 `application/octet-stream`
    public init(contentType: String = "application/octet-stream") {
        self.contentType = contentType
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - ParameterEncoder 协议实现
    // ═══════════════════════════════════════════════════════════

    /// 编码参数到请求。
    ///
    /// 逻辑：
    /// 1. 检查参数是否 `Data`，不是则抛错
    /// 2. 直接设置 `request.httpBody = data`
    /// 3. 设置 `Content-Type`
    ///
    /// - Parameters:
    ///   - parameters: 参数（必须是 `Data`）
    ///   - request: 原始请求
    /// - Returns: 修改后的请求
    /// - Throws: 参数不是 `Data` 时抛 `AFError`
    public func encode<Parameters: Encodable>(
        _ parameters: Parameters,
        into request: URLRequest
    ) throws -> URLRequest {

        // ① 检查参数类型：必须是 Data
        guard let data = parameters as? Data else {
            throw AFError.parameterEncodingFailed(
                reason: .customEncodingFailed(
                    error: NetworkError.custom("参数必须是 Data 类型")
                )
            )
        }

        // ② 直接设置 httpBody
        var request = request
        request.httpBody = data

        // ③ 设置 Content-Type 请求头
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        return request
    }
}
