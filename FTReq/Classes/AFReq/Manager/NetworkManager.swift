//
//  NetworkManager.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/26.
//

import Alamofire
import FTTool

/// 网络层核心入口（单例）。
///
/// 职责：
/// 1. 管理 Alamofire Session（全局唯一）
/// 2. 管理网络配置（token、adcode 等）
/// 3. 网络状态监听
/// 4. Token 刷新与请求重试
/// 5. UI 提示（HUD）
/// 6. 上传队列
/// 7. 异常上报
public class NetworkManager {

    // MARK: - 单例

    /// 全局单例。
    public static let shared = NetworkManager()

    // MARK: - 并发与锁

    /// 数据回调的并发队列（qos = utility，低优先级）。
    ///
    /// 用途：解析响应数据时在后台执行，不阻塞主线程。
    let dataQueue = DispatchQueue(label: "cn.xtt.xyz.dataQueue", qos: .utility, attributes: .concurrent)

    /// Cookie 标识（可能是某些请求需要带 cookie）。
    let kCookieIdentifier: String = "kCookieIdentifier"

    /// 通用锁。
    var lock = NSLock()

    // MARK: - 异常上报

    /// 异常上报器的锁。
    let networkExceptionReporterLock = NSLock()

    /// 网络异常上报器（可插拔）。
    ///
    /// 由业务层通过 `addNetworkExceptionReporter` 注入。
    var networkExceptionReporter: NetworkExceptionReporting?

    /// 上报响应体的最大字节数（4KB）。
    ///
    /// 防止响应体过大导致上报数据爆炸。
    var networkExceptionMaximumResponseBodyBytes = 4 * 1024

    // MARK: - 网络配置

    /// 网络配置（token、refreshToken、adcode）。
    ///
    /// `private(set)` 表示外部只能读，不能直接赋值（通过 `setConfig` / `updateConfig` 修改）。
    public private(set) var config: NetworkConfig?

    // MARK: - Alamofire Session

    /// Alamofire 会话（懒加载）。
    ///
    /// DEBUG 环境：带 `RequestTimerMonitor`，监控每个请求的耗时。
    /// Release 环境：不带监控，减少开销。
    public lazy var session: Alamofire.Session = {
        let configuration = URLSessionConfiguration.default
#if DEBUG
        let monitor = RequestTimerMonitor()
        return Alamofire.Session(configuration: configuration, eventMonitors: [monitor])
#else
        return Alamofire.Session(configuration: configuration)
#endif
    }()

    // MARK: - 请求计时

    /// 请求开始时间（UUID → 纳秒时间戳）。
    ///
    /// 用于计算每个请求的耗时。
    var startTimes: [UUID: UInt64] = [:]

    // MARK: - 网络状态

    /// 当前网络状态（none / wifi / cellular 等）。
    public var networkStatu: NetworkStatu = .none

    /// 网络状态观察者（弱引用，避免循环引用）。
    internal var networkObservers = NSPointerArray.weakObjects()

    /// 添加网络状态观察者。
    public func addNetworkObserver(_ observer: NetworkEventable) {
        networkObservers.ft.addObject(observer)
    }

    /// 清理已释放的观察者（`compact` 移除 nil）。
    public func clearNetworkObservers() {
        networkObservers.compact()
    }

    // MARK: - Token 刷新

    /// Token 刷新器（可插拔）。
    public private(set) var tokenRefresher: TokenRefreshable?

    /// 注册 token 刷新器。
    public func addTokenRefresher(_ refresher: TokenRefreshable) {
        self.tokenRefresher = refresher
    }

    /// 是否正在刷新 token。
    ///
    /// 用途：刷新期间到来的请求先入队，刷新完成后重放。
    var isRefreshingToken = false

    /// 重试队列。
    ///
    /// token 刷新期间，需要重试的请求暂存这里，刷新完成后逐个执行。
    var retryQueue = [VoidClosure]()

    // MARK: - UI 管理

    /// HUD 管理器（弱引用，避免循环引用）。
    public private(set) weak var uimanager: HUDCompatible?

    /// 配置 HUD 管理器（业务层注入）。
    public func configUIManager(with manager: HUDCompatible) {
        self.uimanager = manager
    }

    // MARK: - 重试

    /// 请求 → 已重试次数。
    ///
    /// 用于限制每个请求的最大重试次数。
    public var requestsAndRetryCounts: [Alamofire.Request: Int] = [:]

    // MARK: - 上传队列

    /// 上传专用队列（限制并发 3）。
    ///
    /// 为什么独立队列：
    /// - 上传耗时长，不应该和普通请求抢线程
    /// - 限制并发，避免同时上传太多文件
    lazy var uploadQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.name = "network.upload.queue"
        operationQueue.maxConcurrentOperationCount = 3
        return operationQueue
    }()

    // MARK: - 初始化

    /// 私有初始化。
    ///
    /// 1. 初始化基础配置
    /// 2. 开启网络监听
    private init() {
        setConfig()
        startNetworkMonitor()
    }
}

// MARK: - 配置管理

extension NetworkManager {

    /// 设置网络配置。
    ///
    /// - Parameters:
    ///   - token: 登录 token
    ///   - refreshToken: 刷新 token
    ///   - adcode: 地区码
    public func setConfig(token: String? = nil, refreshToken: String? = nil, adcode: String? = nil) {
        let netConfig = NetworkConfig.getInstance(
            token: token ?? "",
            refreshToken: refreshToken ?? "",
            adcode: adcode ?? ""
        )
        self.config = netConfig
    }

    /// 局部更新配置（目前只支持 adcode）。
    ///
    /// - Parameter values: KeyPath → 新值
    public func updateConfig(with values: [PartialKeyPath<NetworkConfig>: Any]) {
        guard var newConfig = self.config else {
            return
        }

        for (keyPath, value) in values {
            switch keyPath {
            case \.adcode where value is String:
                newConfig.adcode = value as! String
            default:
                break   // 其他字段暂不支持更新
            }
        }

        self.config = newConfig
    }
}
