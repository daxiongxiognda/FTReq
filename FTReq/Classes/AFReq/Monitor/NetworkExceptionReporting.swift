//
//  NetworkExceptionReporting.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/26.
//

import Foundation
import Alamofire

/// 一条脱敏后的网络异常事件。
///
/// 注意：请求头、Cookie、query 参数、请求体都被刻意排除——
/// 这些字段可能包含敏感信息，上报前必须过滤。
public struct NetworkExceptionEvent {

    /// 事件时间戳（毫秒）
    public let timestampMilliseconds: Int64

    /// 请求 id（UUID 字符串）
    public let requestID: String

    /// 请求类型（发起请求的类名，如 "ChatRequest"）
    public let requestType: String

    /// HTTP 方法（GET / POST / PUT 等）
    public let method: String

    /// 脱敏后的 URL（去掉 query、fragment、user、password）
    public let url: String

    /// HTTP 状态码（-1 表示没拿到响应）
    public let statusCode: Int

    /// 业务码（服务端返回的业务错误码，可选）
    public let serviceCode: Int?

    /// 失败类型（no_network / timeout / decode / business / transport / cancelled / client / http_status）
    public let failureKind: String

    /// 错误码
    public let errorCode: Int

    /// 错误信息（限长 1024 字符）
    public let errorMessage: String

    /// 请求耗时（毫秒）
    public let durationMilliseconds: Int64

    /// 链路 trace id（从响应头取）
    public let traceID: String?

    /// 脱敏后的响应体（限长，含大响应体降级）
    public let responseBody: String?

    /// URLSession 采集的链路指标。
    /// 只读系统指标，不会触发额外请求或 DNS 解析。
    public let networkMetrics: [String: String]
}

/// 网络异常上报协议。
///
/// 让 FTReq 可以上报异常，但不耦合具体实现（腾讯云 CLS / 其他云 / 测试 mock）。
/// 上报在 FTReq 的响应队列上调用。
public protocol NetworkExceptionReporting: AnyObject {
    func report(_ event: NetworkExceptionEvent)
}


