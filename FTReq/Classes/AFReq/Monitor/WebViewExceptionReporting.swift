//
//  WebViewExceptionReporting.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/26.
//

import Foundation

/// WebView 失败的阶段枚举。
///
/// 用 `String` 做原始值，上报时直接转字符串，便于 CLS 检索。
public enum WebViewFailureStage: String, Sendable {
    /// 临时导航阶段（还没收到响应，如 DNS 失败、连接超时）
    case provisionalNavigation = "provisional_navigation"
    /// 导航阶段（已收到响应但导航失败）
    case navigation
    /// HTTP 状态码错误（4xx / 5xx）
    case httpStatus = "http_status"
    /// WebContent 进程崩溃
    case contentProcess = "content_process"
    /// JS 执行失败
    case javaScriptExecution = "javascript_execution"
}

/// WebView 异常统一上报入口。
///
/// 设计要点：
/// 1. URL 会在 CLS 封装层移除账号信息、query 和 fragment（隐私保护）
/// 2. 正常取消跳转、WebKit 策略切换**不上报**（降噪）
public enum WebViewExceptionReporter {

    // MARK: - 导航失败

    /// 上报导航失败（网络错误、加载失败等）。
    ///
    /// - Parameters:
    ///   - stage: 失败阶段
    ///   - url: 失败 URL（可能从 error.userInfo 里取到更准确的 URL）
    ///   - error: 原始错误
    public static func reportNavigationFailure(
        stage: WebViewFailureStage,
        url: String?,
        error: Error
    ) {
        let nsError = error as NSError

        // ① 忽略正常取消和 WebKit 策略切换
        guard !isIgnoredNavigationError(nsError) else { return }

        // ② 优先用 error 里携带的失败 URL（比传入的 url 更准确）
        let failureURL = (nsError.userInfo[NSURLErrorFailingURLStringErrorKey] as? String) ?? url

        // ③ 组装上报数据
        var data = baseData(stage: stage, url: failureURL)
        data["error_domain"] = nsError.domain
        data["error_code"] = String(nsError.code)
        data["error_message"] = nsError.localizedDescription

        // ④ 上报
        report(message: "webview_navigation_failed", model: failureURL, data: data)
    }

    // MARK: - HTTP 状态码错误

    /// 上报 HTTP 状态码错误（4xx / 5xx）。
    ///
    /// - Parameters:
    ///   - statusCode: HTTP 状态码
    ///   - url: 请求 URL
    public static func reportHTTPStatus(_ statusCode: Int, url: String?) {
        // ① 只上报 400~599，2xx/3xx 不算错误
        guard (400...599).contains(statusCode) else { return }

        var data = baseData(stage: .httpStatus, url: url)
        data["http_status"] = String(statusCode)

        report(message: "webview_http_status_error", model: url, data: data)
    }

    // MARK: - WebContent 进程崩溃

    /// 上报 WebContent 进程终止（WebView 崩溃）。
    ///
    /// - Parameter url: 崩溃时的 URL
    public static func reportContentProcessTermination(url: String?) {
        report(
            message: "webview_content_process_terminated",
            model: url,
            data: baseData(stage: .contentProcess, url: url)
        )
    }

    // MARK: - JS 执行失败

    /// 上报 JS 执行失败。
    ///
    /// - Parameters:
    ///   - action: 执行的动作（如 "callHandler"、"evaluateScript"）
    ///   - url: 当前页面 URL
    ///   - error: JS 错误
    public static func reportJavaScriptFailure(
        action: String,
        url: String?,
        error: Error
    ) {
        let nsError = error as NSError

        var data = baseData(stage: .javaScriptExecution, url: url)
        data["action"] = action   // 附加动作名，便于区分是哪类 JS 调用失败
        data["error_domain"] = nsError.domain
        data["error_code"] = String(nsError.code)
        data["error_message"] = nsError.localizedDescription

        report(message: "webview_javascript_execution_failed", model: url, data: data)
    }

    // MARK: - 统一上报

    /// 统一上报入口。
    ///
    /// 固定 `tag = "WEBVIEW"`，`type = .business`。
    private static func report(
        message: String,
        model: String?,
        data: [String: String]
    ) {
        // 具体上报入口
    }

    // MARK: - 基础数据

    /// 构建基础上报数据（stage + url）。
    ///
    /// URL 为空时不加 `url` 字段，避免上报空值。
    private static func baseData(
        stage: WebViewFailureStage,
        url: String?
    ) -> [String: String] {
        var data = ["stage": stage.rawValue]
        if let url, !url.isEmpty {
            data["url"] = url
        }
        return data
    }

    // MARK: - 错误忽略判断

    /// 判断是否是应该忽略的导航错误（降噪）。
    ///
    /// 两类忽略：
    /// 1. `NSURLErrorCancelled`：正常取消跳转（用户点返回、页面重定向等）
    /// 2. WebKit 的 102 错误：WebKit 策略切换（如从 HTTPS 降级到 HTTP）
    ///
    /// 这两类不是真正的错误，上报会污染监控数据。
    private static func isIgnoredNavigationError(_ error: NSError) -> Bool {
        // ① NSURLErrorCancelled（正常取消）
        if error.domain == NSURLErrorDomain,
           error.code == NSURLErrorCancelled {
            return true
        }

        // ② WebKit 策略切换（102）
        let webKitDomains = ["WKErrorDomain", "WebKitErrorDomain"]
        return webKitDomains.contains(error.domain) && error.code == 102
    }
}
