//
//  TaskOperation.swift
//  FTTool
//
//  Created by 熊坤鹏 on 2026/10/27.
//

import FTTool

// 自定义 Operation，支持暂停、恢复、取消、重试和进度回调
// 说明：继承自 AsyncOperation（异步 Operation 基类），通过覆写 main() 实现异步逻辑
open class TaskOperation: AsyncOperation {

    // 当前已经重试的次数（每次任务抛错后 +1）
    // 注意：该值在 main() 执行期间被后台 Task 与主线程同时访问，存在数据竞争风险
    private var currentRetryCount = 0

    // 进度回调闭包：外部通过 setProgressHandler 注入
    // 在 excuteTask 执行过程中由子类主动调用，用于上报 0.0 ~ 1.0 的进度
    private var progressHandler: ((Double) -> Void)?

    // 最大重试次数（含首次执行），默认 3
    // 可被外部修改，但修改时机需注意线程安全
    public var maxRetryCount: Int

    // 初始化方法：允许自定义最大重试次数
    public init(maxRetryCount: Int = 3) {
        self.maxRetryCount = maxRetryCount
    }

    // 设置进度回调
    // - Parameter handler: 进度变化时被调用，参数为 0.0 ~ 1.0 的 Double
    public func setProgressHandler(_ handler: @escaping (Double) -> Void) {
        self.progressHandler = handler
    }

    // Operation 的主入口，由 OperationQueue（或手动 start）在子线程调用
    // 关键职责：
    //   1. 启动一个 Swift Concurrency 的 Task 去执行真正的业务逻辑
    //   2. 阻塞当前线程（同步等待）直到任务完成 / 失败达到上限 / 被取消
    //   3. 结束后调用 finish() 通知 Operation 状态机
    open override func main() {
        // 信号量：用于在 main() 的同步上下文中"等待"后台 Task 完成
        // 初始值为 0，表示开始时处于阻塞状态；后台 Task 完成时 signal() 唤醒
        let semaphore = DispatchSemaphore(value: 0)

        // 启动并发任务执行真正的业务逻辑（异步执行，不阻塞当前线程）
        Task {
            // 循环条件：未超过最大重试次数 && 未被取消
            // ⚠️ 问题 1：isCancelled 是 Operation 的标志位，不是 Task.isCancelled，
            //          excuteTask 内部的 await 点无法感知它，导致取消不能及时打断挂起中的任务
            while currentRetryCount < maxRetryCount && !isCancelled {
                do {
                    // 执行实际任务（由子类覆写 excuteTask 实现）
                    // 将内部进度通过闭包转发给外部 progressHandler
                    try await excuteTask { progress in
                        self.progressHandler?(progress)
                    }

                    // 任务成功完成 → 唤醒 main() 中的 semaphore.wait()
                    // ⚠️ 问题 2：如果在 main() 尚未进入 wait 之前就 signal（比如任务极快完成），
                    //          信号会被"预先消耗"，之后进入 wait 时不会阻塞，但代码用 break 提前退出，
                    //          这种设计依赖 break 兜底，语义脆弱
                    semaphore.signal()
                    break
                } catch {
                    // 任务失败：重试次数 +1
                    // ⚠️ 问题 3：currentRetryCount 在后台 Task 写，但 main() 也可能读（虽然当前没读），
                    //          且 isCancelled 在主线程改、这里读，跨线程访问需同步
                    currentRetryCount += 1
                    FTLogger.error(message: "任务失败，重试次数: \(currentRetryCount), 错误: \(error)")

                    // 达到最大重试次数 → 记录日志、唤醒等待、退出循环
                    if currentRetryCount >= maxRetryCount {
                        FTLogger.error(message: "任务达到最大重试次数")
                        semaphore.signal()
                        break
                    }
                    // ⚠️ 问题 4：失败后立即进入下一轮重试，没有退避（backoff），
                    //          网络/IO 类任务连续失败时会瞬间打满重试次数，应加 Task.sleep 指数退避
                }
            }
            // ⚠️ 问题 5：如果 while 循环因 isCancelled == true 直接退出（一次都不进循环），
            //          则此处不会 signal，main() 中若已进入 semaphore.wait() 会永久阻塞
        }

        // 以下为 main() 的同步等待逻辑：阻塞当前线程，直到任务结束 / 被取消
        // ⚠️ 问题 6：整体循环结构与后台 Task 的 signal 存在竞态：
        //          - 若任务先完成（signal 已发），此时可能正处于 isPaused 分支的 sleep 中，
        //            等恢复后进入 wait()，但信号早已被消耗，wait() 会永久阻塞（除非再次被 cancel）
        //          - 若先进入 wait() 再 signal()，正常唤醒；但取消路径下没有 signal 唤醒
        while !isCancelled {
            if isPaused {
                // 暂停状态：忙等轮询
                // ⚠️ 问题 7：Thread.sleep 会阻塞 Operation 所在线程（通常是 OperationQueue 的并发线程），
                //          暂停期间白白占用线程资源；且 0.1s 粒度的轮询延迟了恢复响应
                Thread.sleep(forTimeInterval: 0.1)
            } else {
                // 非暂停：阻塞等待后台 Task 的 signal
                semaphore.wait()
                break
            }
        }

        // 标记 Operation 完成，通知 OperationQueue / KVO 观察者
        // ⚠️ 问题 8：如果是被取消导致循环退出，后台 Task 可能仍在跑 excuteTask，
        //          此刻 finish() 会让外部以为任务已结束，但后续仍可能有进度回调/日志产生，
        //          违反 Operation 完成语义（finish 后不应再有副作用）
        // ⚠️ 问题 9：finish() 应保证幂等（多次调用安全），AsyncOperation 基类需要做防护
        finish()
    }

    // 实际执行任务的抽象方法，由子类覆写
    // - Parameter progressHandler: 进度回调，子类在异步执行过程中调用以上报进度
    // - Throws: 子类抛出的错误会被 main() 捕获并触发重试
    //
    // 约定：
    //   1. 子类实现中应定期调用 `try Task.checkCancellation()`
    //      或在长耗时操作前后检查 `Task.isCancelled`，以配合取消
    //   2. 进度值建议从 0.0 递增到 1.0
    //   3. 抛出的错误应具备"重试可能成功"的语义（如网络抖动），
    //      不可重试的错误（如参数非法）应自行处理或设计专门的错误类型
    open func excuteTask(progressHandler: ((Double) -> Void)?) async throws {
    }
}
