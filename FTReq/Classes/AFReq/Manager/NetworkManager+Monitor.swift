//
//  NetworkManager+Monitor.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/26.
//

import Alamofire

// MARK: - 网络状态监听
public extension NetworkManager {

    // ═══════════════════════════════════════════════════════════
    // MARK: - 是否无网
    // ═══════════════════════════════════════════════════════════

    /// 当前是否无网。
    ///
    /// 逻辑：
    /// - wifi 或 cellular → 有网，返回 false
    /// - 其他（none / unavailable）→ 无网，返回 true
    ///
    /// 用途：请求前快速判断，无网直接返回错误，不发起请求。
    var isNonet: Bool {
        // ① wifi 或 cellular 认为有网
        if networkStatu == .wifi || networkStatu == .cellular {
            return false
        }
        // ② 其他状态（none / unavailable）认为无网
        return true
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 启动网络监听
    // ═══════════════════════════════════════════════════════════

    /// 启动网络状态监听。
    ///
    /// 用 Alamofire 的 `NetworkReachabilityManager` 监听网络变化，
    /// 每次变化时：
    /// 1. 更新 `networkStatu`
    /// 2. 广播给所有 `NetworkEventable` 观察者
    ///
    /// ⚠️ 注意：
    /// - `rechabilityManager` 是**局部变量**，函数结束后会被释放
    /// - 但 Alamofire 的 `startListening` 内部持有强引用，监听不会断
    /// - 这是 Alamofire 的设计，不是 bug
    func startNetworkMonitor() {

        // ① 创建可达性管理器
        let rechabilityManager = NetworkReachabilityManager()

        // ② 开始监听
        //    onUpdatePerforming：每次网络状态变化时回调
        rechabilityManager?.startListening(onUpdatePerforming: { [weak self] status in

            // ③ 弱引用 self，避免循环引用
            guard let strongSelf = self else { return }

            // ④ 先判断是否可达
            if rechabilityManager?.isReachable ?? false {
                // 可达：按具体类型映射
                switch status {
                case .notReachable:
                    // 不可达（理论上进不来，因为上面已经判断了 isReachable）
                    strongSelf.networkStatu = .none
                case .unknown:
                    // 未知状态
                    strongSelf.networkStatu = .unavailable
                case .reachable(.ethernetOrWiFi):
                    // WiFi 或有线
                    strongSelf.networkStatu = .wifi
                case .reachable(.cellular):
                    // 蜂窝网络
                    strongSelf.networkStatu = .cellular
                }
            } else {
                // 不可达：无网
                strongSelf.networkStatu = .none
            }

            // ⑤ 广播给所有观察者
            for index in 0..<strongSelf.networkObservers.count {
                // ⑥ 从弱引用集合里取出观察者
                if let observers = strongSelf.networkObservers.ft.object(at: index) as? NetworkEventable {
                    // ⑦ 回调
                    observers.didReceiveNetworkStatuChangged(statu: strongSelf.networkStatu)
                }
            }
        })
    }
}
