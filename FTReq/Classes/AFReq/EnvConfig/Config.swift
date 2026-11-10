//
//  Config.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/26.
//


// environmentType: debug = 0; dev = 1; release = 2

/// 当前环境类型（从 UserDefaults 读）。
///
/// 0 = debug（SIT 环境）
/// 1 = dev（DEV 环境）
/// 2 = release（生产环境）
public let envType: Int = {
    let type = UserDefaults.standard.integer(forKey: "environmentType")
    return type
}()

/// 是否是 Debug 环境（environmentType == 0）。
public let useDebug: Bool = {
    return UserDefaults.standard.integer(forKey: "environmentType") == 0
}()


/// 是否是 Dev 环境（environmentType == 1）。
public let useDev: Bool = {
    return UserDefaults.standard.integer(forKey: "environmentType") == 1
}()

/// 是否是 Release 环境（environmentType == 2）。
public let useRelease: Bool = {
    return UserDefaults.standard.integer(forKey: "environmentType") == 2
}()


extension NetworkManager {

    // MARK: - 三段式域名（dev / sit / production）

    /// 中台-用户中心域名。
    ///
    /// 三段式：
    /// - dev: https://dev-user-api.xtt.xyz
    /// - sit: https://sit-user-api.xtt.xyz
    /// - production: https://user-api.xtt.xyz
    public var baseUserUrl: String {
        let dev = "https://dev-user-api.xtt.xyz"
        let debug = "https://sit-user-api.xtt.xyz"
        let production = "https://user-api.xtt.xyz"
#if DEBUG
        // Debug 包：根据 environmentType 三选一
        return useRelease ? production : (useDev ? dev : debug)
#else
        // Release 包：永远生产
        return production
#endif
    }
    
    // 聊模块域名-新
    public var aichatBaseUrl: String {
        let dev = "https://dev-aichat-api.xtt.xyz"
        let debug = "https://sit-aichat-api.xtt.xyz"
        let production = "https://aichat-api.xtt.xyz"
#if DEBUG
        return useRelease ? production : (useDev ? dev : debug)
#else
        return production
#endif
    }
    
    // 中台-公共服务域名
    public var basicBaseUrl: String {
        let dev = "https://dev-basic-api.xtt.xyz"
        let debug = "https://sit-basic-api.xtt.xyz"
        let production = "https://basic-api.xtt.xyz"
#if DEBUG
        return useRelease ? production : (useDev ? dev : debug)
#else
        return production
#endif
    }
}


public extension NetworkManager {

    /// 基础 Web 域名（地图相关）。
    var baseWebUrl: String {
        let productionWebUrl = "https://map.xtt.xyz"
        let debugWebUrl = "https://map-sandbox.xtt.xyz"
#if DEBUG
        return useRelease ? productionWebUrl : debugWebUrl
#else
        return productionWebUrl
#endif
    }

    /// 直播 Web 域名。
    var liveBaseWebUrl: String {
        let productionLiveUrl = "https://live.xtt.xyz"
        let debugLiveUrl = "https://sit-live-service.xtt.xyz"
#if DEBUG
        return useRelease ? productionLiveUrl : debugLiveUrl
#else
        return productionLiveUrl
#endif
    }
}

/// 网络配置（请求头、签名、租户等）。
public struct NetworkConfig: Codable {

    // MARK: - 请求头字段

    public var appType: String          // app 类型（iOS = "1"）
    public var deviceId: String         // 设备 id（UUID）
    public var version: String          // app 版本号
    public var device: String           // 设备类型（iOS = "1"）
    public var lang: String             // 语言（"zh"）
    public var loginType: String        // 登录类型（"1"）
    public var userAgent: String        // User-Agent
    public var adcode: String           // 地区码

    // MARK: - 鉴权字段

    public var refreshToken: String     // 刷新 token
    public var authorization: String    // 登录 token

    // MARK: - 签名字段

    public var signConst: String = ""   // 签名常量
    public var tenantAppId: String = "" // 租户 app id

    /// CodingKeys：JSON key 和属性名的映射。
    ///
    /// 注意：部分 key 带连字符（app-type）或大写（Authorization），
    /// 需要用 CodingKeys 映射到标准的 Swift 属性名。
    enum CodingKeys: String, CodingKey {
        case appType = "app-type"
        case deviceId = "device-id"
        case version
        case device
        case lang
        case loginType = "login-type"
        case refreshToken
        case authorization = "Authorization"
        case userAgent = "User-Agent"
        case signConst
        case tenantAppId
        case adcode
    }

    /// 自定义编码（目前和默认行为一致，可能是历史遗留）。
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(appType, forKey: .appType)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(version, forKey: .version)
        try container.encode(device, forKey: .device)
        try container.encode(lang, forKey: .lang)
        try container.encode(loginType, forKey: .loginType)
        try container.encode(userAgent, forKey: .userAgent)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encode(authorization, forKey: .authorization)
        try container.encode(signConst, forKey: .signConst)
        try container.encode(tenantAppId, forKey: .tenantAppId)
        try container.encode(adcode, forKey: .adcode)
    }

    // MARK: - 请求头

    /// 构建请求头。
    ///
    /// 固定头 + deviceinfo（设备信息编码后的字符串）。
    public var headers: [String: String]? {
        var headers = [
            "Accept": "application/json",
            "Cache-Control": "private, no-store, no-cache, must-revalidate",
            "sign-version": "2.0",
            "app-type": appType,
            "device-id": deviceId,
            "version": version,
            "device": device,
            "lang": lang,
            "login-type": loginType,
            "User-Agent": userAgent,
            "Authorization": authorization,
            "adcode": adcode
        ]
        // 设备信息（加密后）
        if let deviceinfo = DeviceInfoHeader.makeEncodedValue(config: self, networkStatu: NetworkManager.shared.networkStatu) {
            headers["deviceinfo"] = deviceinfo
        }
        return headers
    }

    // MARK: - 工厂方法

    /// 创建网络配置实例。
    ///
    /// - Parameters:
    ///   - token: 登录 token
    ///   - refreshToken: 刷新 token
    ///   - adcode: 地区码
    public static func getInstance(token: String, refreshToken: String, adcode: String) -> NetworkConfig {
        var config = NetworkConfig(
            appType: NetworkConfig.appType,
            deviceId: UIDevice.ft.deviceID,
            version: Bundle.ft.appVersionNumber,
            device: "1",                                    // iOS
            lang: NetworkConfig.currentLanguageCode,        // "zh"
            loginType: NetworkConfig.loginType,             // "1"
            userAgent: NetworkConfig.userAgent,
            adcode: adcode,
            refreshToken: refreshToken,
            authorization: token
        )
        // 签名
        config.signConst = NetworkConfig.tempSignConst
        config.tenantAppId = NetworkConfig.tempTenantAppId
        return config
    }

    // MARK: - 静态常量

    static var currentLanguageCode: String { "zh" }
    static var loginType: String { "1" }
    static var appType: String { "1" }

    static var userAgent: String {
        return "TongTong/iOS \(Bundle.ft.appVersionNumber) \(Bundle.ft.appBuildNumber)"
    }

    /// 签名常量（Debug / Release 不同）。
    static var tempSignConst: String {
        var value = ""
#if DEBUG
        value = useRelease
            ? "kLmPoUiYtReWqAsDfGhJkLzXcVbNmQwEr"   // Release（从 Debug 包切到生产）
            : "KxVmGcBjWpLdRfNzQsHyTgAaSeXrCvBn"   // SIT/DEV
#else
        value = "kLmPoUiYtReWqAsDfGhJkLzXcVbNmQwEr"   // 生产
#endif
        return value
    }

    /// 租户 app id（Debug = 666666，Release = 999999）。
    static var tempTenantAppId: String {
        var value = ""
#if DEBUG
        value = "666666"
#else
        value = "999999"
#endif
        return value
    }
}
