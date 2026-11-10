//
//  GroupRequest.swift
//  Pods
//
//  Created by 熊坤鹏 on 2026/10/29.
//

import FTTool
import FTReq
import Alamofire

/// 群相关接口的请求构造器
/// - 把 `GroupApi` 枚举映射为具体的 HTTP 请求（baseURL / method / path / parameters）
/// - 遵循 `ApiConvertable`，由网络层统一发起请求
public struct GroupRequest: ApiConvertable {

    /// 具体接口枚举（决定 URL、方法、参数）
    public var apiType: GroupApi

    /// HUD 配置（loading/错误提示），默认错误提示为空串（不弹提示）
    public var hudConfig: HUDConfig?

    public init(apiType: GroupApi, hudConfig: HUDConfig? = HUDConfig(err: "")) {
        self.apiType = apiType
        self.hudConfig = hudConfig
    }

    // MARK: - 业务码校验

    /// 校验服务端返回的业务 code
    /// - Parameter code: 服务端返回的业务码
    /// - Returns: 校验结果（成功 / 需刷新 token / 失败）
    ///
    /// ⚠️ 严重问题：注释与代码矛盾
    ///   注释写"101005：今日已签到不弹toast"，但代码里：
    ///   - 102520107 被视为成功（注释没提它是什么）
    ///   - 101005 被视为 refreshToken（需要刷新 token）
    ///   这会导致"今日已签到"时错误地触发刷新 token。
    ///   必须与服务端确认码值后统一，并修正注释。
    public func validateServerCodeResult(code: Int) -> ServerCodeValidateResult {
        // ⚠️ 102520107 的真实含义未知（疑为"今日已签到"），101005 的真实含义也需确认
        if code == 0 || code == 200 || code == 102520107 {
            return .successed
        } else if code == 101005 {
            return .refreshToken
        }
        return .failed
    }

    // MARK: - 基础地址

    /// 根据接口选择不同的服务基地址
    /// - groupShareLink：走 basic 服务
    /// - joinLandGroup：走 roam 服务
    /// - 其余：走 aichat 服务
    ///
    /// ⚠️ 可读性问题：中间一大串 case 共用 aichatBaseUrl，
    ///    新增接口若忘加进这个列表，switch 不穷尽会编译报错（这点是好的），
    ///    但列表过长难以阅读，建议按业务分组加注释
    public var baseURL: String {
        switch apiType {
            // aichat 服务：群聊主接口都走这里
        case .v2Group:
            return NetworkManager.shared.aichatBaseUrl
        }
    }

    // MARK: - HTTP 方法

    /// 根据接口选择 HTTP 方法
    ///
    /// ⚠️ 风险：default 兜底为 .post
    ///    新增接口若本应是 GET/PUT/DELETE 却忘加进前面列表，
    ///    会静默变成 POST，运行时才发现 405/404，建议去掉 default 强制穷尽
    public var method: Alamofire.HTTPMethod {
        switch apiType {
        // GET：查询类接口
        case .v2Group:
            return .get
        // POST：其余（创建/操作类）
        default:
            return .post
        }
    }

    // MARK: - 请求路径

    /// 根据接口拼接请求路径
    ///
    /// ⚠️ 问题汇总：
    ///   1. groupApplicationsCount 把 query 参数 `?id=` 直接拼进 path，
    ///      若 groupId 含特殊字符未编码会破坏 URL，建议改用 parameters 传 query
    ///   2. path 中的 `\(groupId)`、`\(id)` 均未做 URL 编码
    ///   3. groupingStick 的 id 同时出现在 path 和 parameters，可能冲突
    public var path: String {
        switch apiType {
        case .v2Group:
            return "/chat/v2/group"
        }
    }

    // MARK: - 请求参数

    /// 根据接口组装请求参数
    /// - Returns: 字典/模型/nil（nil 表示无参数）
    ///
    /// ⚠️ 严重风险：default 兜底返回 nil
    ///    新增接口若忘在 parameters 里处理，会静默传 nil，
    ///    对需要参数的接口就是漏参，运行时才报错。
    ///    建议去掉 default，让编译器强制穷尽所有 case。
    public var parameters: Any? {
        switch apiType {
       
        case let .v2Group(ids, fields):
            // ⚠️ ids 拼成逗号串，需确认服务端要数组还是逗号串
            let idsSeparated = ids.map { String($0) }.joined(separator: ",")
            return ["ids": idsSeparated, "fields": fields]

        // ⚠️ default 兜底返回 nil：新增接口忘处理会静默漏参
        default:
            return nil
        }
    }
}
