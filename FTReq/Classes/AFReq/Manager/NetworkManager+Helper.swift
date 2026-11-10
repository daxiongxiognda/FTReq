//
//  NetworkManager+Helper.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/26.
//

import Alamofire
import FTTool

// ═══════════════════════════════════════════════════════════════
// MARK: - 请求池，重试
// ═══════════════════════════════════════════════════════════════

extension NetworkManager {

    /// 记录请求重试次数（+1）。
    ///
    /// 流程：
    /// - 第一次调用：记录为 0（表示"即将第 1 次重试"）
    /// - 后续调用：次数 +1
    ///
    /// - Parameter request: Alamofire 的 Request
    func addRetryInfo(with request: Alamofire.Request) {
        // ① 加锁保护 requestsAndRetryCounts
        lock.lock()
        defer { lock.unlock() }

        // ② 已有记录 → 次数 +1；没有 → 初始化为 0
        if let count = requestsAndRetryCounts[request] {
            requestsAndRetryCounts[request] = count + 1
            FTLogger.info(message: "添加重试====\(request.id.uuidString)：第\(count + 1)次")
        } else {
            requestsAndRetryCounts[request] = 0
        }
    }

    /// 移除请求的重试记录。
    ///
    /// 请求完成（成功/失败/取消）时调用，清理记录避免泄漏。
    ///
    /// - Parameter request: Alamofire 的 Request
    func deleteRetryInfo(with request: Alamofire.Request) {
        // ① 加锁
        lock.lock()
        defer { lock.unlock() }

        FTLogger.info(message: "删除重试====\(request.id)")

        // ② 存在才移除
        if requestsAndRetryCounts[request] != nil {
            requestsAndRetryCounts.removeValue(forKey: request)
        }
    }

    /// 读取/设置请求耗时。
    ///
    /// 双用途：
    /// - 传 `duration`（非 nil）：**写入**耗时（RequestTimerMonitor 调用）
    /// - 传 `nil`：**读取并清除**耗时（业务方调用）
    ///
    /// - Parameters:
    ///   - uuid: 请求 id
    ///   - duration: 耗时（纳秒）；nil 表示读取
    /// - Returns: 耗时（纳秒）
    @discardableResult
    func getDurationAndSet(_ uuid: UUID, duration: UInt64?) -> UInt64 {
        // ① 加锁
        lock.lock()
        defer { lock.unlock() }

        if let dur = duration {
            // ② 写入模式：记录耗时
            startTimes[uuid] = dur
            return dur
        } else {
            // ③ 读取模式：读出并清除
            let dur = startTimes[uuid] ?? 0
            startTimes.removeValue(forKey: uuid)
            return dur
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 取消、暂停、恢复
// ═══════════════════════════════════════════════════════════════

extension NetworkManager {

    /// 暂停下载请求。
    ///
    /// 只对 `DownloadRequest` 有效（`DataRequest` 不支持暂停）。
    ///
    /// - Parameter requestId: 请求 id（UUID 字符串）
    public func suspendDownload(requestId: String) {
        // ① 遍历请求池，找匹配的 DownloadRequest
        if let request = requestsAndRetryCounts.keys.first(where: { $0.id.uuidString == requestId }),
           request is DownloadRequest {
            request.suspend()
        }
    }

    /// 恢复下载请求。
    ///
    /// - Parameter requestId: 请求 id（UUID 字符串）
    public func resumeDownload(requestId: String) {
        if let request = requestsAndRetryCounts.keys.first(where: { $0.id.uuidString == requestId }),
           request is DownloadRequest {
            request.resume()
        }
    }

    /// 取消请求（不限于下载）。
    ///
    /// - Parameter requestId: 请求 id（UUID 字符串）
    public func cancelRequest(requestId: String) {
        if let request = requestsAndRetryCounts.keys.first(where: { $0.id.uuidString == requestId }) {
            request.cancel()
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Cookie 处理
// ═══════════════════════════════════════════════════════════════

extension NetworkManager {

    /// 组装 Cookie 字符串（用于 Cookie header）。
    ///
    /// 流程：
    /// 1. 取请求自带的 Cookie
    /// 2. 如果需要全局 Cookie，合并 HTTPCookieStorage 里的（自定义优先）
    /// 3. 按 RFC 6265 字符集编码
    /// 4. 拼接成 `name=value; Domain=...; Path=...; Secure` 格式
    ///
    /// - Parameter apiConvertable: 请求对象
    /// - Returns: Cookie 字符串（用于 Cookie header）
    func getCookies(apiConvertable: ApiConvertable) -> String {

        // ① 解析 URL
        let url = URL(string: apiConvertable.requestUrlString)

        // ② 取请求自带的 Cookie
        var cookies = apiConvertable.cookies ?? [:]

        // ③ 如果需要全局 Cookie，从 HTTPCookieStorage 读取
        if apiConvertable.useGlobalCookie, let tempUrl = url,
           let globalCookies = HTTPCookieStorage.shared.cookies(for: tempUrl), !globalCookies.isEmpty {

            // 全局 Cookie 转字典
            let globalCookieDict = globalCookies.reduce(into: [String: String]()) { $0[$1.name] = $1.value }

            // 合并：自定义 Cookie 优先（覆盖全局）
            // $1 表示冲突时用新值（cookies），即自定义优先
            cookies = globalCookieDict.merging(cookies) { $1 }
        }

        // ④ 没有 Cookie 返回空
        if cookies.isEmpty { return "" }

        // ⑤ 动态生成作用域和安全标记
        let isHTTPS = url?.scheme?.lowercased() == "https"
        let host = url?.host ?? ""
        var path = url?.path ?? ""
        if path.isEmpty { path = "/" }

        // ⑥ RFC 6265 允许的 Cookie 字符集
        //    排除控制字符、空格、分隔符（如 , ; 等）
        var rfc6265Allowed = CharacterSet()
        rfc6265Allowed.insert(charactersIn: "!#$%&'()*+-./0123456789:<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[]^_`abcdefghijklmnopqrstuvwxyz{|}~")

        // ⑦ 编码并拼接每个 Cookie
        let cookieItems = cookies.map { name, value -> String in
            // 编码 name 和 value
            let encodedName = name.addingPercentEncoding(withAllowedCharacters: rfc6265Allowed) ?? name
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: rfc6265Allowed) ?? value

            var cookieString = "\(encodedName)=\(encodedValue)"

            // 模拟作用域和安全属性
            // ⚠️ 注意：注释说"仅供服务端参考，客户端实际不解析"是错的，
            //    服务端会解析 Domain / Path / Secure 决定 Cookie 是否生效
            if !host.isEmpty { cookieString += "; Domain=\(host)" }
            cookieString += "; Path=\(path)"
            if isHTTPS { cookieString += "; Secure" }

            return cookieString
        }

        // ⑧ 多个 Cookie 用 "; " 拼接
        return cookieItems.joined(separator: "; ")
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - UI（HUD / 登出）
// ═══════════════════════════════════════════════════════════════

extension NetworkManager {

    /// 检查并显示 HUD。
    ///
    /// 逻辑：
    /// - 传了 type：直接显示指定类型
    /// - 没传 type：用 hudConfig.loading 显示 loading
    ///
    /// 切主线程：HUD 是 UI 操作，必须主线程。
    ///
    /// - Parameters:
    ///   - apiConvertable: 请求对象
    ///   - type: 指定 HUD 类型（可选）
    func checkShowHUD(apiConvertable: ApiConvertable, type: RequestHUDType? = nil) {
        // ① 切主线程
        DispatchQueue.main.async {
            if let tempType = type {
                // ② 指定类型，直接显示
                apiConvertable.showHUD(type: tempType)
            } else if let title = apiConvertable.hudConfig?.loading {
                // ③ 用配置的 loading 文案
                apiConvertable.showHUD(type: .loading(title))
            }
        }
    }

    /// 检查并隐藏 HUD，显示结果提示。
    ///
    /// 提示优先级：
    /// 1. 配置了非空文案 → 显示配置的
    /// 2. 配置了空串 → 显示服务端消息（msg）
    /// 3. 配置为 nil → 不显示
    ///
    /// - Parameters:
    ///   - apiConvertable: 请求对象
    ///   - err: 网络错误（nil 表示成功）
    ///   - msg: 服务端返回的消息
    ///   - tipLevel: 提示级别（toast / alert）
    ///   - completion: 完成后回调
    func checkHideHUD(
        apiConvertable: ApiConvertable,
        err: NetworkError? = nil,
        msg: String = "",
        tipLevel: TipLevel = .toast,
        completion: VoidClosure? = nil
    ) {
        DispatchQueue.main.async {
            // ① 隐藏 loading
            if let _ = apiConvertable.hudConfig?.loading {
                apiConvertable.hideHUD(success: err == nil)
            }

            // ② 显示结果提示
            if let tempErr = err {
                // ───────── 失败场景 ─────────
                if let errMsg = apiConvertable.hudConfig?.err {
                    if !errMsg.isEmpty {
                        // 配置了非空错误文案 → 显示配置的
                        let type: RequestHUDType = tipLevel == .alert ? .alert(errMsg) : .err(errMsg)
                        self.checkShowHUD(apiConvertable: apiConvertable, type: type)
                    } else if !msg.isEmpty {
                        // 配置了空串 → 显示服务端消息
                        let type: RequestHUDType = tipLevel == .alert ? .alert(msg) : .err(msg)
                        self.checkShowHUD(apiConvertable: apiConvertable, type: type)
                    }
                }
            } else {
                // ───────── 成功场景 ─────────
                if let sucMsg = apiConvertable.hudConfig?.suc {
                    if !sucMsg.isEmpty {
                        // 配置了非空成功文案 → 显示配置的
                        let type: RequestHUDType = tipLevel == .alert ? .alert(sucMsg) : .suc(sucMsg)
                        self.checkShowHUD(apiConvertable: apiConvertable, type: type)
                    } else if !msg.isEmpty {
                        // 配置了空串 → 显示服务端消息
                        let type: RequestHUDType = tipLevel == .alert ? .alert(msg) : .suc(msg)
                        self.checkShowHUD(apiConvertable: apiConvertable, type: type)
                    }
                }
            }

            // ③ 通知请求结果（业务层可覆盖，用于跳转、刷新等）
            apiConvertable.requestResult(error: err, message: msg)

            // ④ 完成回调
            completion?()
        }
    }

    /// 检查是否需要登出（token 失效）。
    ///
    /// 只处理 4 种业务码：
    /// - 101004：账号被禁用
    /// - 101006：登录失效（异地登录）
    /// - 101007：账号被删除
    /// - 101011：已退出登录
    ///
    /// - Parameters:
    ///   - statusCode: HTTP 状态码（⚠️ 当前没用）
    ///   - serviceCode: 业务码
    ///   - msg: 服务端消息
    /// - Returns: 是否需要登出
    @discardableResult
    func checkLogout(statusCode: Int, serviceCode: Int, msg: String = "") -> Bool {
        // ① 只处理 4 种业务码
        guard serviceCode == 101004 || serviceCode == 101006 || serviceCode == 101007 || serviceCode == 101011 else {
            return false
        }

        // ② 切主线程发通知
        DispatchQueue.main.async {
            // ③ 优先用服务端消息，没有则从 Bundle 读文案
            let desc = msg.isEmpty ? NetworkError.errorMessage(code: serviceCode) : msg

            // ④ 发通知，业务层监听后处理登出
            NotificationCenter.default.post(
                name: FTReqNotifiName.didForbidden.name,
                object: self,
                userInfo: ["code": serviceCode, "desc": desc]
            )
        }
        return true
    }
}
