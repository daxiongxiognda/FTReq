//
//  NetworkError.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/26.
//

// ═══════════════════════════════════════════════════════════════
// MARK: - NetworkError（网络错误统一类型）
// ═══════════════════════════════════════════════════════════════

/// 网络错误统一类型。
///
/// 设计目标：
/// 1. 把所有网络层的错误（网络、超时、解析、服务端、参数等）收敛到一个枚举
/// 2. 每个错误有统一的错误码（errCode）和描述（errDesc）
/// 3. 遵循 LocalizedError，可以直接作为 Error 抛出
///
/// 错误分类：
/// - 客户端错误：noNetwork、networkTimeout、parameterError、invalidURL、cancelError
/// - 服务端错误：serverError
/// - 数据处理错误：noData、decodeError
/// - 鉴权错误：tokenError
/// - 文件/上传错误：fileNotFound、uploadFailed
/// - 底层错误：responseError（包装其他 Error）
/// - 自定义：custom
public enum NetworkError: LocalizedError {

    // MARK: - 错误 case

    /// 无网络（未连接互联网）。
    case noNetwork

    /// 网络请求超时。
    case networkTimeout

    /// 响应无数据（服务端返回空）。
    case noData

    /// 自定义错误（透传消息）。
    case custom(String)

    /// 底层响应错误（包装其他 Error，如 AFError、URLError）。
    case responseError(Error)

    /// 数据解析错误。
    /// - Parameters:
    ///   - Error: 原始解析错误（如 DecodingError）
    ///   - String: 原始响应内容（便于排查）
    case decodeError(Error, String)

    /// 服务端返回的业务错误。
    /// - Parameters:
    ///   - String: 错误消息
    ///   - Int: 业务错误码
    case serverError(String, Int)

    /// 参数错误（请求参数不合法）。
    case parameterError(String)

    /// Token 错误（登录失效、鉴权失败）。
    case tokenError(String)

    /// 请求已取消。
    case cancelError

    /// 文件不存在。
    case fileNotFound

    /// 无效 URL。
    case invalidURL(String)

    /// 上传失败。
    /// - Parameters:
    ///   - String: 错误消息
    ///   - Int: HTTP 状态码或业务码
    case uploadFailed(String, Int)

    // ═══════════════════════════════════════════════════════════
    // MARK: - 错误码
    // ═══════════════════════════════════════════════════════════

    /// 错误码（用于上报、埋点、服务端识别）。
    ///
    /// 编码规则：
    /// - 2000~2099：网络层通用错误
    /// - 2100：文件错误
    /// - 2100+N：上传失败（N 是 HTTP 状态码）
    /// - 其他：服务端返回的业务码
    public var errCode: Int {
        switch self {
        case .noNetwork:
            // 2000：无网络
            return 2000

        case .networkTimeout:
            // 2001：超时
            return 2001

        case .noData:
            // 2002：无数据
            return 2002

        case let .custom(msg):
            // 2003：自定义（msg 不参与错误码，只是占位）
            return 2003

        case let .responseError(err):
            // 2004：底层响应错误
            return 2004

        case let .decodeError(err, msg):
            // 2005：解析错误
            return 2005

        case let .serverError(_, code):
            // 直接透传服务端业务码
            return code

        case let .parameterError(msg):
            // 2007：参数错误
            return 2007

        case let .tokenError(msg):
            // 2008：Token 错误
            return 2008

        case .cancelError:
            // 2009：取消
            return 2009

        case .invalidURL:
            // 2010：无效 URL
            return 2010

        case .fileNotFound:
            // 2100：文件不存在
            return 2100

        case .uploadFailed(_, let code):
            // 2100 + HTTP 状态码：上传失败
            // 如 404 → 2504，500 → 2600
            return 2100 + code
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 错误描述
    // ═══════════════════════════════════════════════════════════

    /// 错误描述（用于日志、UI 提示）。
    public var errDesc: String {
        switch self {
        case .noNetwork:
            // 无网络的友好提示
            return "似乎已断开与互联网的连接"

        case .networkTimeout:
            return "请求超时"

        case .noData:
            return "内容为空"

        // 以下三个 case 都有 String 参数，合并处理
        case .custom(let msg), .parameterError(let msg), .tokenError(let msg):
            return msg

        case .serverError(let msg, let code):
            // 服务端错误：直接用服务端消息
            return msg

        case let .responseError(err):
            // 底层错误：用 localizedDescription
            return err.localizedDescription

        case let .decodeError(err, msg):
            #if DEBUG || ADHOC
            // Debug/AdHoc：显示完整的解析错误 + 原始内容
            // 便于开发期排查
            let emsg = "\(err)\n---\n\(msg)"
            #else
            // Release：只显示错误的 localizedDescription
            // 避免泄露原始内容（可能含敏感信息）
            let emsg = err.localizedDescription
            #endif
            return emsg

        case .cancelError:
            return "请求已取消"

        case .invalidURL(let url):
            // 无效 URL：带上具体 URL
            return "无效链接: \(url)"

        case .fileNotFound:
            return "文件不存在"

        case .uploadFailed(let msg, _):
            // 上传失败：用服务端消息
            return msg
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - LocalizedError
    // ═══════════════════════════════════════════════════════════

    /// 遵循 LocalizedError，`error.localizedDescription` 返回 `errDesc`。
    public var errorDescription: String? {
        return errDesc
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 错误码 → 文案（从 Bundle 读取）
    // ═══════════════════════════════════════════════════════════

    /// 通过错误码匹配本地化文案。
    ///
    /// 用途：服务端返回业务码（如 101006），客户端从 FTReq 模块的
    /// `zh-Hans.lproj` 里读对应的文案。
    ///
    /// - Parameters:
    ///   - code: 错误码
    ///   - noMatchReturnCode: 未匹配时是否把 code 当文本返回
    /// - Returns: 错误文案
    public static func errorMessage(code: Int, noMatchReturnCode: Bool = false) -> String {
        // ① 把 Int 错误码转成字符串（作为 localizedString 的 key）
        let codeStr = "\(code)"

        // ② 默认返回值
        //    如果 noMatchReturnCode = true，未匹配时返回 code 字符串
        //    否则返回空字符串
        var errMsg = noMatchReturnCode ? codeStr : ""

        // ③ 获取 FTReq 模块的 Bundle
        //    Bundle.tt.bundle(bundleName:targetClass:) 是项目的工具方法，
        //    用于定位某个模块（如 FTReq）的资源 Bundle
        let moduleBundle = Bundle.ft.bundle(
            bundleName: "FTReq",
            targetClass: NetworkManager.self
        )

        // ④ 获取 zh-Hans 本地化 Bundle
        if let localizedBundlePath = moduleBundle.path(forResource: "zh-Hans", ofType: "lproj"),
           let localizedBundle = Bundle(path: localizedBundlePath) {

            // ⑤ 用 code 作为 key，从 Localizable.strings 里读文案
            //    localizedString(forKey:value:table:)：
            //    - 第一个参数是 key（这里是 code 字符串）
            //    - 第二个参数是 fallback（nil 表示找不到返回 key 本身）
            //    - 第三个参数是 table（nil 表示 Localizable.strings）
            errMsg = localizedBundle.localizedString(forKey: codeStr, value: nil, table: nil)
        }

        // ⑥ 最终兜底：如果还是空且 noMatchReturnCode = true，返回 code
        if errMsg.isEmpty, noMatchReturnCode {
            return codeStr
        }
        return errMsg
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Error 扩展（把任意 Error 转成 NetworkError）
// ═══════════════════════════════════════════════════════════════

extension Error {

    /// 转成 NetworkError（如果不是则返回 nil）。
    public var asNetWorkError: NetworkError? {
        self as? NetworkError
    }

    /// 错误码。
    ///
    /// - NetworkError：返回具体的 errCode
    /// - 其他 Error：返回 -1
    public var errCode: Int {
        asNetWorkError?.errCode ?? -1
    }

    /// 错误描述。
    ///
    /// - NetworkError：返回 errDesc
    /// - 其他 Error：返回 localizedDescription
    public var errDesc: String {
        asNetWorkError?.errDesc ?? localizedDescription
    }
}
