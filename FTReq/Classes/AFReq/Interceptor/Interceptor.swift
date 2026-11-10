//
//  Interceptor.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/26.
//

import Alamofire
import CommonCrypto
import FTTool
// ═══════════════════════════════════════════════════════════════
// MARK: - BaseInterceptor（基础拦截器：只处理重试）
// ═══════════════════════════════════════════════════════════════

/// 基础网络请求拦截器。
///
/// 遵循 `RequestInterceptor`：
/// - `adapt`：请求发出前修改请求（如加 header、签名）
/// - `retry`：请求失败后决定是否重试
///
/// 本类只处理重试，`adapt` 是空实现。
/// 子类（如 `TongTongInterceptor`）覆盖 `adapt` 来实现签名。
///
/// `@unchecked Sendable`：
/// - RequestInterceptor 的回调可能在多线程执行
/// - `retryCount` 是可变属性，理论上需要加锁
/// - 用 @unchecked 跳过编译器的 Sendable 检查
open class BaseInterceptor: @unchecked Sendable, RequestInterceptor {

    // MARK: - 属性

    /// 最大重试次数。
    ///
    /// - 0：不重试
    /// - N：最多重试 N 次
    var retryCount: Int

    public init(retryCount: Int) {
        self.retryCount = retryCount
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - adapt（请求发出前修改）
    // ═══════════════════════════════════════════════════════════

    /// 请求发出前修改请求。
    ///
    /// 基类默认不做任何修改，直接返回原请求。
    /// 子类可以覆盖此方法来实现签名、加 header 等。
    ///
    /// - Parameters:
    ///   - urlRequest: 原始请求
    ///   - session: Alamofire Session
    ///   - completion: 回调（返回修改后的请求）
    public func adapt(
        _ urlRequest: URLRequest,
        for session: Alamofire.Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        // 不做任何修改，直接返回原请求
        completion(.success(urlRequest))
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - retry（请求失败后决定是否重试）
    // ═══════════════════════════════════════════════════════════

    /// 请求失败后决定是否重试。
    ///
    /// 逻辑：
    /// 1. `retryCount <= 0`：不重试
    /// 2. 已重试次数 == `retryCount`：不再重试（达到上限）
    /// 3. 未达到上限：记录重试信息，延迟 1 秒重试
    ///
    /// - Parameters:
    ///   - request: 失败的请求
    ///   - session: Alamofire Session
    ///   - error: 失败原因
    ///   - completion: 回调（决定重试策略）
    public func retry(
        _ request: Alamofire.Request,
        for session: Alamofire.Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        // ① 配置了重试次数
        if retryCount > 0 {
            // ② 检查已重试次数是否达到上限
            if let count = NetworkManager.shared.requestsAndRetryCounts[request], count == retryCount {
                // 已达到上限，不再重试
                completion(.doNotRetry)
            } else {
                // ③ 未达到上限：记录重试信息 + 延迟 1 秒重试
                NetworkManager.shared.addRetryInfo(with: request)
                completion(.retryWithDelay(1.0))
            }
        } else {
            // ④ 没配置重试次数，不重试
            completion(.doNotRetry)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - TongTongInterceptor（业务拦截器：重试 + 签名）
// ═══════════════════════════════════════════════════════════════
/**
 
 签名算法：

 HMAC-SHA256：用密钥对消息做哈希，防止篡改
 Base64 编码：签名结果转成可传输的字符串
 密钥 signConst：来自服务端配置（NetworkConfig.signConst），客户端和服务端共享
 
 */
/// 通通业务拦截器。
///
/// 继承 `BaseInterceptor`（复用重试逻辑），覆盖 `adapt` 实现签名。
///
/// 签名流程：
/// 1. 拼接签名内容：body + path + method + deviceId + timestamp
/// 2. 用 HMAC-SHA256 + signConst 生成签名
/// 3. 把 timestamp、tenantAppId、sign 加入请求头
public class TongTongInterceptor: BaseInterceptor, @unchecked Sendable {

    // ═══════════════════════════════════════════════════════════
    // MARK: - adapt（请求发出前加签名）
    // ═══════════════════════════════════════════════════════════

    /// 请求发出前加签名。
    ///
    /// 流程：
    /// 1. 取 deviceId、timestamp、method、body、path
    /// 2. 拼接签名内容
    /// 3. HMAC-SHA256 生成签名
    /// 4. 加 timestamp、tenantAppId、sign 到请求头
    ///
    /// - Parameters:
    ///   - urlRequest: 原始请求
    ///   - session: Alamofire Session
    ///   - completion: 回调（返回加签后的请求）
    public override func adapt(
        _ urlRequest: URLRequest,
        for session: Alamofire.Session,
        completion: @escaping (Result<URLRequest, any Error>) -> Void
    ) {
        // ① 取设备 ID（优先用网络配置里的，兜底用 UIDevice.tt.deviceID）
        let deviceId = NetworkManager.shared.config?.deviceId ?? UIDevice.ft.deviceID

        // ② 当前时间戳（毫秒）
        let timestamp = "\(Int64(Date().timeIntervalSince1970 * 1000))"

        // ③ 请求方法
        let method: Alamofire.HTTPMethod = urlRequest.method ?? .post

        // ④ 取 body 字符串
        var bodyStr = ""
        if method == .get || method == .head {
            // GET/HEAD：body 是 URL 里的 query 参数
            let tranUrl = urlRequest.url?.absoluteString ?? ""
            bodyStr = getGetRequestParamsString(tranUrl)
        } else if let data = urlRequest.httpBody, let json = String(data: data, encoding: .utf8) {
            // POST/PUT：body 是 httpBody
            bodyStr = json
        }

        // ⑤ 取 path
        let path = urlRequest.url?.path ?? ""

        // ⑥ 拼接签名内容
        //    格式：body + path + method + deviceId + timestamp
        let temp = "\(bodyStr)\(path)\(method.rawValue)\(deviceId)\(timestamp)"

        // ⑦ 取租户 appId 和签名密钥
        let tenantAppId = NetworkManager.shared.config?.tenantAppId ?? ""
        let signConst = NetworkManager.shared.config?.signConst ?? ""

        // ⑧ 生成签名
        let sign = generateReqSign(withSecret: signConst, content: temp)

        // ⑨ 把签名相关字段加入请求头
        var request = urlRequest
        request.setValue(timestamp, forHTTPHeaderField: "timestamp")
        request.setValue(tenantAppId, forHTTPHeaderField: "tenantAppId")
        request.setValue(sign, forHTTPHeaderField: "sign")

        // ⑩ 返回加签后的请求
        completion(.success(request))
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 签名生成（HMAC-SHA256）
    // ═══════════════════════════════════════════════════════════

    /// 生成请求签名。
    ///
    /// 算法：HMAC-SHA256
    /// - 密钥：`secret`（signConst）
    /// - 消息：`content`（拼接的签名内容）
    /// - 输出：Base64 编码的签名
    ///
    /// - Parameters:
    ///   - secret: 签名密钥（来自服务端配置）
    ///   - content: 待签名的内容
    /// - Returns: Base64 编码的签名
    func generateReqSign(withSecret secret: String, content: String) -> String {
        // ① 算法：HMAC-SHA256
        let algorithm = CCHmacAlgorithm(kCCHmacAlgSHA256)

        // ② 密钥和消息转 Data
        let keyData = Data(secret.utf8)
        let messageData = Data(content.utf8)

        // ③ 签名结果缓冲区（SHA256 是 32 字节）
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

        // ④ 调用 CCHmac 计算签名
        //    withUnsafeBytes 获取指针，CCHmac 需要原始指针
        keyData.withUnsafeBytes { keyBytes in
            messageData.withUnsafeBytes { messageBytes in
                CCHmac(
                    algorithm,                    // 算法
                    keyBytes.baseAddress,         // 密钥指针
                    keyData.count,                // 密钥长度
                    messageBytes.baseAddress,     // 消息指针
                    messageData.count,            // 消息长度
                    &digest                       // 输出缓冲区
                )
            }
        }

        // ⑤ 签名转 Base64 字符串
        let signature = Data(digest).base64EncodedString()
        return signature
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 工具方法
    // ═══════════════════════════════════════════════════════════

    /// 从 URL 里提取 query 参数部分。
    ///
    /// 如 `https://a.com/api?x=1&y=2` → `"x=1&y=2"`
    ///
    /// - Parameter url: 完整 URL
    /// - Returns: query 字符串；没有 ? 返回空字符串
    func getGetRequestParamsString(_ url: String) -> String {
        // ① 找第一个 "?" 的位置
        if let range = url.range(of: "?") {
            // ② 截取 "?" 后面的子串
            let substring = url[range.upperBound...]
            return String(substring)
        }
        // ③ 没有 "?" 返回空字符串
        return ""
    }
}
