//
//  TaskManager.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/26.
//

// ═══════════════════════════════════════════════════════════════
// MARK: - TaskManager（基于 OperationQueue 的并发任务管理器）
// ═══════════════════════════════════════════════════════════════
//
// 背景：
// - Swift Concurrency 的 TaskGroup 不适合"跨调用管理一组任务"
// - OperationQueue 天然支持：并发控制、优先级、依赖、暂停、取消
// - 本类把 async/await 和 OperationQueue 结合，提供：
//   1. 并发任务管理（maxConcurrentOperationCount）
//   2. 自动重试（maxRetryCount）
//   3. 优先级（priority）
//   4. 依赖（dependencies）
//   5. 进度回调（progressHandler）
//   6. 暂停 / 恢复 / 取消

class TaskManager {

    // ═══════════════════════════════════════════════════════════
    // MARK: - 内部状态
    // ═══════════════════════════════════════════════════════════

    /// 底层 OperationQueue。
    ///
    /// 为什么用 OperationQueue 而不是 TaskGroup：
    /// - OperationQueue 支持"跨方法"管理任务（添加、暂停、取消）
    /// - TaskGroup 只能在 withTaskGroup 闭包里使用，无法跨调用管理
    /// - OperationQueue 支持依赖、优先级、并发控制
    private let operationQueue = OperationQueue()

    /// 初始化。
    ///
    /// - Parameter maxConcurrentTasks: 最大并发任务数，默认 2
    ///
    /// maxConcurrentOperationCount 的含义：
    /// - 1：串行执行
    /// - N：最多 N 个任务同时执行
    /// - -1（默认）：由系统决定（通常是 CPU 核数）
    init(maxConcurrentTasks: Int = 2) {
        operationQueue.maxConcurrentOperationCount = maxConcurrentTasks
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 添加任务
    // ═══════════════════════════════════════════════════════════

    /// 添加一个异步任务。
    ///
    /// 流程：
    /// 1. 创建 `TaskOperation`（AsyncOperation 子类）
    /// 2. 设置优先级
    /// 3. 添加依赖
    /// 4. 加入 OperationQueue（自动开始执行）
    /// 5. 返回 Operation 供调用方控制（设置进度回调、取消等）
    ///
    /// - Parameters:
    ///   - task: 异步任务闭包，接收进度回调
    ///   - maxRetryCount: 最大重试次数，默认 3
    ///   - priority: 队列优先级，默认 .normal
    ///   - dependencies: 依赖的 Operation 列表
    /// - Returns: 创建好的 TaskOperation
    func addTask(
        task: @escaping (_ progressHandler: @escaping (Double) -> Void) async throws -> Void,
        maxRetryCount: Int = 3,
        priority: Operation.QueuePriority = .normal,
        dependencies: [Operation] = []
    ) -> TaskOperation {

        // ① 创建 TaskOperation
        let operation = TaskOperation(maxRetryCount: maxRetryCount)

        // ② 设置优先级
        //    .veryHigh / .high / .normal / .low / .veryLow
        //    优先级影响 OperationQueue 的调度顺序
        operation.queuePriority = priority

        // ③ 添加依赖
        //    ⚠️ 依赖的 Operation 必须先完成，当前 Operation 才开始执行
        //    依赖用于控制任务顺序（如任务 B 依赖任务 A）
        dependencies.forEach { operation.addDependency($0) }

        // ④ 加入队列（自动开始执行）
        //    OperationQueue 会根据 maxConcurrentOperationCount 和优先级调度
        operationQueue.addOperation(operation)

        // ⑤ 返回 operation，调用方可以：
        //    - 设置进度回调：operation.setProgressHandler { ... }
        //    - 取消：operation.cancel()
        //    - 暂停/恢复：operation.pause() / resume()
        return operation
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 执行任务组（等待所有任务完成）
    // ═══════════════════════════════════════════════════════════

    /// 等待所有任务完成。
    ///
    /// 流程：
    /// 1. 用 `withTaskGroup` 创建一个任务组
    /// 2. 为每个 Operation 创建一个子任务
    /// 3. 子任务用 `withCheckedContinuation` 等待 Operation 完成
    /// 4. `group.waitForAll()` 等待所有子任务完成
    ///
    /// ⚠️ 问题：
    /// - `operationQueue.operations` 是**快照**，只包含当前队列里的 Operation
    /// - 如果任务在 `runTasks()` 之后才添加，不会被等待
    /// - `completionBlock` 是 Operation 完成时调用的闭包
    func runTasks() async {
        await withTaskGroup(of: Void.self) { group in

            // ① 遍历当前队列里的所有 Operation
            for operation in operationQueue.operations {

                // ② 为每个 Operation 创建一个子任务
                group.addTask {

                    // ③ withCheckedContinuation：等待 Operation 完成
                    //    - 设置 completionBlock，Operation 完成时调用
                    //    - completionBlock 里 resume continuation，唤醒 async 函数
                    await withCheckedContinuation { continuation in
                        operation.completionBlock = {
                            // ④ Operation 完成 → 唤醒
                            continuation.resume()
                        }
                    }
                }
            }

            // ⑤ 等待所有子任务完成
            await group.waitForAll()
        }

        print("所有任务已完成")
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 暂停所有任务
    // ═══════════════════════════════════════════════════════════

    /// 暂停所有任务。
    ///
    /// 注意：
    /// - 只对 `TaskOperation` 有效（其他 Operation 没有 `pause()` 方法）
    /// - `pause()` 只设置 `isPaused = true` 标记
    /// - **是否真正暂停取决于 TaskOperation 的实现**
    func pauseAllTasks() {
        for operation in operationQueue.operations {
            if let customOperation = operation as? TaskOperation {
                customOperation.pause()
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 恢复所有任务
    // ═══════════════════════════════════════════════════════════

    /// 恢复所有任务。
    func resumeAllTasks() {
        for operation in operationQueue.operations {
            if let customOperation = operation as? TaskOperation {
                customOperation.resume()
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 取消所有任务
    // ═══════════════════════════════════════════════════════════

    /// 取消所有任务。
    ///
    /// `cancelAllOperations()` 会：
    /// 1. 对队列里每个 Operation 调 `cancel()`
    /// 2. 未开始的 Operation 直接标记取消（不会执行）
    /// 3. 正在执行的 Operation 设置 `isCancelled = true`（需子类检查）
    func cancelAllTasks() {
        operationQueue.cancelAllOperations()
    }
}

/*
 // ═══════════════════════════════════════════════════════════════
 // MARK: - 使用示例（被注释掉了）
 // ═══════════════════════════════════════════════════════════════

 func exampleUsage() {
     // ① 创建 TaskManager，最大并发 2
     let taskManager = ConcurrentTaskManager(maxConcurrentTasks: 2)

     // ② 添加任务 1（高优先级，最多重试 3 次）
     let task1 = taskManager.addTask(maxRetryCount: 3, task: { progressHandler in
         print("任务 1 开始")
         for i in 0..<10 {
             // 检查取消
             if Task.isCancelled { break }
             // 模拟耗时
             try await Task.sleep(nanoseconds: 200_000_000)
             // 上报进度
             let progress = Double(i + 1) / 10.0
             progressHandler(progress)
             print("任务 1 进度: \(progress * 100)%")
         }
         print("任务 1 完成")
     }, priority: .high)

     // ③ 设置任务 1 的进度回调
     task1.setProgressHandler { progress in
         print("任务 1 进度回调: \(progress * 100)%")
     }

     // ④ 添加任务 2（普通优先级，最多重试 2 次）
     let task2 = taskManager.addTask(maxRetryCount: 2, task: { progressHandler in
         print("任务 2 开始")
         for i in 0..<5 {
             if Task.isCancelled { break }
             try await Task.sleep(nanoseconds: 300_000_000)
             let progress = Double(i + 1) / 5.0
             progressHandler(progress)
             print("任务 2 进度: \(progress * 100)%")
         }
         print("任务 2 完成")
     }, priority: .normal)

     task2.setProgressHandler { progress in
         print("任务 2 进度回调: \(progress * 100)%")
     }

     // ⑤ 执行任务组（等待所有完成）
     Task {
         await taskManager.runTasks()
     }

     // ⑥ 1 秒后暂停
     DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
         taskManager.pauseAllTasks()
         print("任务已暂停")

         // ⑦ 3 秒后恢复
         DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
             taskManager.resumeAllTasks()
             print("任务已恢复")
         }
     }

     // ⑧ 4 秒后取消
     DispatchQueue.global().asyncAfter(deadline: .now() + 4) {
         taskManager.cancelAllTasks()
         print("任务已取消")
     }
 }

 // 运行示例
 exampleUsage()
 */
