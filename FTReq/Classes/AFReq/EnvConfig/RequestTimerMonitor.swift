//
//  RequestTimerMonitor.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/26.
//

import Alamofire


/// 请求耗时监控器。
///
/// 遵循 Alamofire 的 `EventMonitor` 协议，在请求生命周期回调中打点，
/// 统计每个请求的耗时（纳秒级）。
///
/// 只用于 DEBUG 环境：
/// - 记录耗时用于性能分析、排查慢请求
/// - Release 环境不创建，零开销
///
/// `@unchecked Sendable` 说明：
/// - EventMonitor 的回调可能在多个线程执行
/// - `startTimes` 字典是共享可变状态，理论上需要加锁
/// - 这里用 `@unchecked` 跳过编译器的 Sendable 检查
///   （实际 Alamofire 的 EventMonitor 回调在串行队列执行，安全）
class RequestTimerMonitor: @unchecked Sendable, EventMonitor {

    // MARK: - 内部状态

    /// 请求开始时间记录。
    ///
    /// key: `task.taskIdentifier`（URLSessionTask 的唯一 id）
    /// value: `(request.id, 开始时间戳)`
    ///
    /// 为什么用 taskIdentifier 做 key：
    /// - 每个 URLSessionTask 有唯一 id
    /// - 同一请求的重试、重定向会产生不同的 task，需要区分
    private var startTimes: [Int: (UUID, UInt64)] = [:]

    // ═══════════════════════════════════════════════════════════
    // MARK: - EventMonitor 回调
    // ═══════════════════════════════════════════════════════════

    /// 请求开始（task 被 resume）时回调。
    ///
    /// 记录开始时间，用于后续计算耗时。
    ///
    /// - Parameters:
    ///   - request: Alamofire 的 Request 对象
    ///   - task: 底层的 URLSessionTask
    func request(_ request: Alamofire.Request, didResumeTask task: URLSessionTask) {
        // ① 记录当前时间（纳秒级）
        //    用 DispatchTime.now().uptimeNanoseconds：
        //    - 纳秒精度，适合测量短耗时
        //    - uptimeNanoseconds 是单调递增的，不受系统时间调整影响
        let time = DispatchTime.now().uptimeNanoseconds

        // ② 用 taskIdentifier 作为 key
        let idKey = task.taskIdentifier

        // ③ 记录 (request.id, 开始时间)
        //    request.id 是 Alamofire 为每个 Request 生成的 UUID
        startTimes[idKey] = (request.id, time)
    }

    /// 收到响应（响应头）时回调。
    ///
    /// 计算耗时并回传给 NetworkManager。
    ///
    /// 注意：这里用的是"收到响应头"的时机，不是"响应体接收完成"。
    /// 所以统计的是 TTFB（Time To First Byte），不是完整请求耗时。
    ///
    /// - Parameters:
    ///   - session: URLSession
    ///   - dataTask: 当前 data task
    ///   - response: URL 响应
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) {
        // ① 查找开始时间记录
        //    找不到说明不是我们监控的请求（如其他 Session 的请求），直接返回
        guard let startTimeTurple = startTimes[dataTask.taskIdentifier] else { return }

        // ② 记录当前时间
        let endTime = DispatchTime.now()

        // ③ 取出 request id 和开始时间
        let reqId = startTimeTurple.0
        let startTime = startTimeTurple.1

        // ④ 计算耗时（纳秒）
        //    用 uptimeNanoseconds 保证单调性，不会因系统时间调整导致负数
        let duration = endTime.uptimeNanoseconds - startTime

        // ⑤ 清理记录，避免字典无限增长
        //    用 = nil 而不是 removeValue，语义等价但更短
        startTimes[dataTask.taskIdentifier] = nil

        // ⑥ 回传给 NetworkManager
        //    由 NetworkManager 决定怎么用（记录、上报、打印等）
        NetworkManager.shared.getDurationAndSet(reqId, duration: duration)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 被注释掉的代码
    // ═══════════════════════════════════════════════════════════

    // 请求完成时计算时长
    /*func requestDidFinish(_ request: Alamofire.Request) {
        guard let startTimeTurple = startTimes.first?.value else { return }
        // 记录请求结束时间
        let endTime = DispatchTime.now()
        // 计算请求时长
        let reqId = startTimeTurple.0
        let startTime = startTimeTurple.1
        let duration = endTime.uptimeNanoseconds - startTime
        let secondDuration = Double(duration) / 1000_000_000
        FTLogger.info(message: "********-----\(secondDuration)")
        
    }*/
}
