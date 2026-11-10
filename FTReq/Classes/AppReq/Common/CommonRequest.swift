//
//  CommonRequest.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/29.
//

import FTTool
import FTReq
import Alamofire

/// 通用接口的请求构造器
/// - 把 `CommonApi` 枚举映射为具体 HTTP 请求
/// - 遵循 `ApiConvertable`，由网络层统一发起请求
public struct CommonRequest: ApiConvertable {

    /// 具体接口枚举
    public var apiType: CommonApi

    /// HUD 配置（loading/错误提示），默认错误提示为空串（不弹提示）
    public var hudConfig: HUDConfig?

    public init(apiType: CommonApi, hudConfig: HUDConfig? = HUDConfig(err: "")) {
        self.apiType = apiType
        self.hudConfig = hudConfig
    }

    // MARK: - 基础地址

    /// 根据接口选择服务基地址
    public var baseURL: String {
        switch apiType {
        case .sysDictList:
            return NetworkManager.shared.basicBaseUrl
        case .refreshToken:
            return NetworkManager.shared.baseUserUrl
        }
    }

    // MARK: - HTTP 方法

    /// 根据接口选择 HTTP 方法
    ///
    /// ⚠️ 风险：default 兜底为 .post
    ///    新增接口若本应是 GET/PUT/DELETE 却忘加进前面 case，
    ///    会静默变成 POST，运行时才发现 405/404。
    ///    建议去掉 default，让编译器强制穷尽。
    public var method: Alamofire.HTTPMethod {
        switch apiType {
        case .sysDictList:
            return .get
        default:
            return .post
        }
    }

    // MARK: - 鉴权

    /// 鉴权类型
    /// - .token：需要携带用户 token（默认）
    /// - .none：无需鉴权（如登录、验证码等）
    ///
    /// ⚠️ 当前所有接口都返回 .token，注释掉的 .none 分支说明曾有"无需鉴权"的接口，
    ///    若后续新增登录/验证码类接口，记得在这里补 .none 分支
    public var authentication: AuthenticateType {
        switch apiType {
        // 以下为"无需 token"的接口示例（已注释）：
        // case .verifyCodeRequest:
        //     return .none
        default:
            return .token
        }
    }

    // MARK: - 日志

    /// 是否需要记录网络日志
    /// - 默认 true，所有接口都记录
    /// - 特殊接口（如日志开关查询本身）可返回 false，避免日志自我循环
    public var needLog: Bool {
        // 避免日志开关接口本身参与普通网络日志输出（已注释）：
        // if case .appLogSwitchQuery = apiType {
        //     return false
        // }
        return true
    }

    // MARK: - 路径

    /// 请求路径（直接复用 CommonApi 的 reqPath）
    public var path: String {
        return apiType.reqPath
    }

    // MARK: - 参数

    /// 根据接口组装请求参数
    ///
    /// ⚠️ 风险：default 兜底返回 nil
    ///    新增接口若忘在 parameters 里处理，会静默传 nil，
    ///    对需要参数的接口就是漏参。建议去掉 default，强制穷尽。
    public var parameters: Any? {
        switch apiType {
        case .sysDictList(let keywords):
            return ["keywords": keywords]
        case .refreshToken(let refreshToken):
            return ["refreshToken": refreshToken]
        default:
            return nil
        }
    }
}
