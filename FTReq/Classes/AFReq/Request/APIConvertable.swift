//
//  APIConvertable.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/26.
//

import Alamofire
import FTTool
import FTKv


// ═══════════════════════════════════════════════════════════════
// MARK: - 鉴权类型
// ═══════════════════════════════════════════════════════════════

/// 鉴权类型。
public enum AuthenticateType {
    /// 不鉴权（如登录、注册、公开接口）。
    case none
    /// 需要 Token 鉴权（大部分业务接口）。
    case token
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 服务端返回码校验结果
// ═══════════════════════════════════════════════════════════════

/// 服务端返回码的校验结果。
public enum ServerCodeValidateResult {
    /// 成功。
    case successed
    /// 需要刷新 Token（如 code = 101005）。
    case refreshToken
    /// 失败。
    case failed
}

// ═══════════════════════════════════════════════════════════════
// MARK: - ApiConvertable（接口配置协议）
// ═══════════════════════════════════════════════════════════════

/// 接口配置协议。
///
/// 每个接口（请求对象）实现这个协议，声明：
/// - 域名、路径、方法
/// - 参数、请求头、编码器
/// - 鉴权方式、重试次数、超时
/// - HUD 配置、日志配置
/// - 服务端返回码校验
///
/// 协议提供了大量默认实现，接口只需覆盖差异部分。
///
/// 遵循 `Sendable`：要求接口对象可以跨线程安全传递。
/// 遵循 `HUDConfigurable`：提供 HUD 显示/隐藏能力。
public protocol ApiConvertable: Sendable, HUDConfigurable {

    // ═══════════════════════════════════════════════════════════
    // MARK: - 必须实现（或使用默认值）
    // ═══════════════════════════════════════════════════════════

    /// 主机、域名。
    var domain: String { get }

    /// 接口超时时间（秒）。
    var timeout: TimeInterval { get }

    /// 失败重试次数（默认 0）。
    var defaultRetryCount: Int { get }

    /// 基础域名（如 "https://user-api.xtt.xyz"）。
    var baseURL: String { get }

    /// 鉴权类型（none / token）。
    var authentication: AuthenticateType { get }

    /// HTTP 方法（GET / POST 等）。
    var method: Alamofire.HTTPMethod { get }

    /// 拦截器（token 刷新、签名等）。
    var authInterceptor: BaseInterceptor? { get }

    /// 接口路径（如 "/api/v1/user"）。
    var path: String { get }

    /// 完整请求 URL（baseURL + path）。
    var requestUrlString: String { get }

    /// 请求参数（支持 Encodable、[String: Any]、[Any]）。
    var parameters: Any? { get }

    /// 默认请求头（含网络配置、位置信息）。
    var defaultHeaders: [String: String]? { get }

    /// 分页大小。
    var pageSize: Int { get }

    /// 最终请求头（合并默认头和自定义头）。
    var headers: [String: String] { get }

    /// 参数编码器。
    var encoder: ParameterEncoder { get }

    /// 是否使用全局 Cookie。
    var useGlobalCookie: Bool { get }

    /// 自定义 Cookie。
    var cookies: [String: String]? { get }

    /// 是否需要输出日志。
    var needLog: Bool { get }

    /// 校验服务端返回码。
    func validateServerCodeResult(code: Int) -> ServerCodeValidateResult

    /// 请求结果回调（用于统一处理 toast、跳转等）。
    func requestResult(error: NetworkError?, message: String)
}

// ═══════════════════════════════════════════════════════════════
// MARK: - ApiConvertable 默认实现
// ═══════════════════════════════════════════════════════════════

public extension ApiConvertable {

    // ───────── 基础配置 ─────────

    /// 默认超时 20 秒。
    var timeout: TimeInterval { return 20 }

    /// 默认不重试。
    var defaultRetryCount: Int { return 0 }

    /// 默认不使用全局 Cookie。
    var useGlobalCookie: Bool { return false }

    /// 默认无自定义 Cookie。
    var cookies: [String: String]? { return nil }

    /// 默认无域名（由 baseURL 提供完整域名）。
    var domain: String { return "" }

    /// 默认 POST。
    var method: Alamofire.HTTPMethod { return .post }

    /// 默认请求头：JSON 格式。
    var headers: [String: String] {
        return [
            "Content-Type": "application/json;charset=utf-8",
            "Accept": "application/json"
        ]
    }

    // ───────── 编码器选择 ─────────

    /// 根据参数类型和方法自动选择编码器。
    ///
    /// 逻辑：
    /// - 参数是 Data → DataBodyEncoder（直接传二进制）
    /// - GET/HEAD → URL 编码
    /// - 其他 → JSON 编码
    var encoder: ParameterEncoder {
        // ① 参数是 Data，用 DataBodyEncoder（如上传二进制）
        if let _ = parameters as? Data {
            return DataBodyEncoder()
        }

        // ② GET/HEAD 用 URL 编码
        switch method {
        case .get, .head:
            return Alamofire.URLEncodedFormParameterEncoder.default
        default:
            // ③ 其他用 JSON 编码
            return Alamofire.JSONParameterEncoder.default
        }
    }

    // ───────── 拦截器 ─────────

    /// 默认拦截器：TongTongInterceptor（token 刷新、签名）。
    var authInterceptor: BaseInterceptor? {
        return TongTongInterceptor(retryCount: defaultRetryCount)
    }

    // ───────── 分页 ─────────

    /// 默认分页大小 20。
    var pageSize: Int { return 20 }

    // ───────── URL ─────────

    /// 默认空 baseURL（接口必须覆盖）。
    var baseURL: String { return "" }

    /// 默认需要 Token 鉴权。
    var authentication: AuthenticateType { return .token }

    /// 默认空 path（接口必须覆盖）。
    var path: String { return "" }

    /// 默认需要日志。
    var needLog: Bool { return true }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 服务端返回码校验
    // ═══════════════════════════════════════════════════════════

    /// 默认校验逻辑。
    ///
    /// - 0 或 200 → 成功
    /// - 101005 → 需要刷新 Token
    /// - 其他 → 失败
    func validateServerCodeResult(code: Int) -> ServerCodeValidateResult {
        if code == 0 || code == 200 {
            return .successed
        } else if code == 101005 {
            return .refreshToken
        }
        return .failed
    }

    /// CMS 返回码校验（"Y" 表示成功）。
    func validateServerWithCMSCodeResult(isSuccess: String) -> ServerCodeValidateResult {
        if isSuccess == "Y" {
            return .successed
        }
        return .failed
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - URL 拼接
    // ═══════════════════════════════════════════════════════════

    /// 完整 URL = baseURL + path。
    var requestUrlString: String {
        return baseURL + path
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 参数（默认 nil，接口覆盖）
    // ═══════════════════════════════════════════════════════════

    /// 默认无参数。
    var parameters: Any? {
        get { return nil }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 默认请求头（含网络配置 + 位置信息）
    // ═══════════════════════════════════════════════════════════

    /// 默认请求头。
    ///
    /// 组成：
    /// 1. `NetworkManager.config?.headers`：网络配置的请求头（app-type、device-id、version、token 等）
    /// 2. `lonlat`：用户位置（从 KV 读，格式 "经度,纬度"）
    var defaultHeaders: [String: String]? {
        get {
            // ① 取网络配置的请求头
            var dict = NetworkManager.shared.config?.headers ?? [:]

            // ② 如果 KV 里有用户位置，加入 lonlat
            if let location = FTKv.shared.value([String: String].self, forKey: FTKey.general("userLocation_location")) {
                if let lon = location["lon"], let lat = location["lat"] {
                    let lonlat = "\(lon),\(lat)"
                    dict["lonlat"] = lonlat
                }
            }
            return dict
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - HUD 配置
    // ═══════════════════════════════════════════════════════════

    /// HUD 配置。
    ///
    /// - nil（默认）：不展示任何 HUD（loading、成功、失败都不展示）
    /// - 空 HUDConfig：展示服务端返回的文案
    /// - 非空 HUDConfig：展示配置的 loading / suc / err 文案
    var hudConfig: HUDConfig? {
        get { return nil }
    }

    /// 显示 HUD（转调 NetworkManager.uimanager）。
    func showHUD(type: RequestHUDType) {
        NetworkManager.shared.uimanager?.showHUD(type: type)
    }

    /// 隐藏 HUD。
    func hideHUD(success: Bool) {
        NetworkManager.shared.uimanager?.hideHUD()
    }

    /// 请求结果回调（默认空，接口可覆盖）。
    func requestResult(error: NetworkError?, message: String) {}

    // ═══════════════════════════════════════════════════════════
    // MARK: - 日志（失败）
    // ═══════════════════════════════════════════════════════════

    /// 请求失败日志。
    ///
    /// 只在 DEBUG 环境输出，包含：
    /// - 响应时长
    /// - 请求 URL、状态码、方法、参数、请求头、响应头、响应数据
    /// - 错误描述
    ///
    /// - Parameters:
    ///   - reqUUID: 请求 id（用于取耗时）
    ///   - statuCode: HTTP 状态码
    ///   - method: 请求方法
    ///   - resData: 响应数据
    ///   - error: 网络错误
    ///   - reqHeaders: 请求头
    ///   - resHeaders: 响应头
    ///   - file/method/line: 调用位置（编译期注入）
    // swiftlint:disable:next function_parameter_count
    func resFailedLog(
        reqUUID: UUID,
        statuCode: Int,
        method: String,
        resData: Data?,
        error: NetworkError?,
        reqHeaders: [String: Any]?,
        resHeaders: [AnyHashable: Any]?,
        file: StaticString,
        function: StaticString,
        line: UInt
    ) {
        // ① 不需要日志直接返回
        if !needLog { return }

#if DEBUG
        // ② 取请求耗时（纳秒 → 秒）
        let duration = NetworkManager.shared.getDurationAndSet(reqUUID, duration: nil)
        let durationInSeconds = Double(duration) / 1_000_000_000

        // ③ 响应数据转字符串
        var resStr = ""
        if let tempData = resData, let str = String(data: tempData, encoding: .utf8) {
            resStr = str
        }

        // ④ 组装日志
        var log = "响应时长：\(durationInSeconds)s"
        log.append("\n❌请求url：\(requestUrlString)")
        log.append("\n❌状态码 : \(statuCode)")
        log.append("\n❌请求方式 : \(method)")
        log.append("\n❌请求参数 : \(paramPrettyString)")
        log.append("\n❌请求头 : \(reqHeaders?.prettyString ?? "")")
        log.append("\n❌响应头 : \(resHeaders?.prettyString ?? "")")
        log.append("\n❌响应数据：\(resStr)")
        log.append("\n❌错误描述：\(error?.errDesc ?? "")")

        // ⑤ 三段式输出（边框便于日志定位）
        FTLogger.error(message: "┌─────响应 失败———————————————", file: file, method: function, line: line)
        FTLogger.error(message: log, file: file, method: function, line: line)
        FTLogger.error(message: "└—————响应 结束——————————————\n\n", file: file, method: function, line: line)
#endif
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 日志（成功）
    // ═══════════════════════════════════════════════════════════

    /// 请求成功日志（结构同失败日志，用 ✅ 标识）。
    // swiftlint:disable:next function_parameter_count
    func resSuccessLog(
        reqUUID: UUID,
        statuCode: Int,
        method: String,
        resData: Data?,
        reqHeaders: [String: Any]?,
        resHeaders: [AnyHashable: Any]?,
        duration: UInt64 = 0,
        file: StaticString,
        function: StaticString,
        line: UInt
    ) {
        // ① 不需要日志直接返回
        if !needLog { return }

#if DEBUG
        // ② 取请求耗时（注意：duration 参数被同名的 let 覆盖了）
        let duration = NetworkManager.shared.getDurationAndSet(reqUUID, duration: nil)
        let durationInSeconds = Double(duration) / 1_000_000_000

        // ③ 响应数据转字符串
        var resStr = ""
        if let tempData = resData, let str = String(data: tempData, encoding: .utf8) {
            resStr = str
        }

        // ④ 组装日志
        var log = "响应时长：\(durationInSeconds)s"
        log.append("\n✅请求url：\(requestUrlString)")
        log.append("\n✅状态码 : \(statuCode)")
        log.append("\n✅请求方式 : \(method)")
        log.append("\n✅请求参数 : \(paramPrettyString)")
        log.append("\n✅请求头 : \(reqHeaders?.prettyString ?? "")")
        log.append("\n✅响应头 : \(resHeaders?.prettyString ?? "")")
        log.append("\n✅响应数据：\(resStr)")

        // ⑤ 三段式输出
        FTLogger.success(message: "┌─────响应 成功———————————————", file: file, method: function, line: line)
        FTLogger.success(message: log, file: file, method: function, line: line)
        FTLogger.success(message: "└—————响应 结束——————————————\n\n", file: file, method: function, line: line)
#endif
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 参数美化输出
    // ═══════════════════════════════════════════════════════════

    /// 参数美化字符串（用于日志）。
    ///
    /// - Encodable 参数：用 `prettyString` 格式化成 JSON
    /// - 其他参数：用 `AnyEncodable` 包装后再格式化
    /// - 无参数：返回空字符串
    var paramPrettyString: String {
        if let tempParam = parameters as? Encodable {
            return tempParam.prettyString
        } else if let tempParam = parameters {
            let encodableParam = AnyEncodable(tempParam)
            return encodableParam?.prettyString ?? ""
        } else {
            return ""
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - DownloadConvertable（下载接口配置协议）
// ═══════════════════════════════════════════════════════════════

/// 下载接口配置协议（继承 ApiConvertable）。
public protocol DownloadConvertable: ApiConvertable {

    /// 下载目录。
    var downloadDir: URL? { get }

    /// 下载文件名。
    var filename: String? { get }
}
