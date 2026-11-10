//
//  AsyncOperation.swift
//  FTTool
//
//  Created by 熊坤鹏 on 2026/10/27.
//

import FTTool

// ═══════════════════════════════════════════════════════════════
// MARK: - AsyncOperation（支持异步执行的 Operation 基类）
// ═══════════════════════════════════════════════════════════════
//
// 背景：
// - 系统 `Operation` 默认是"同步"的：重写 `main()` 后，执行完 `main()` 就认为完成
// - 如果需要"异步"（如网络请求、下载），必须自定义 `isAsynchronous = true`
// - 并且手动管理 `isExecuting` / `isFinished` 的 KVO 通知
// - 否则队列无法知道 Operation 何时真正完成
//
// 本类的作用：
// 1. 提供 `isAsynchronous = true` 的基础实现
// 2. 用 KVO 安全地管理 `isExecuting` / `isFinished` / `isCancelled`
// 3. 提供 `finish()` 方法供子类在异步任务完成时调用
// 4. 提供 `pause()` / `resume()` 暂停恢复（需子类配合实现）
// 5. 强制子类重写 `main()`

open class AsyncOperation: Operation {

    // ═══════════════════════════════════════════════════════════
    // MARK: - 并发队列（保护状态）
    // ═══════════════════════════════════════════════════════════

    /// 用于保护 `_isExecuting` / `_isFinished` / `_isCancelled` 的并发队列。
    ///
    /// 为什么用 concurrent：
    /// - 读操作（get）可以并发执行
    /// - 写操作（set）用 `.barrier` 保证独占
    ///
    /// 为什么不用 NSLock：
    /// - `sync(flags: .barrier)` 是读写锁语义，读并发、写独占，性能更好
    /// - 系统 `Operation` 的 `isExecuting` / `isFinished` 可能被多线程同时访问
    private let lockQueue = DispatchQueue(label: "com.AsyncOperation.lockQueue", attributes: .concurrent)

    // ═══════════════════════════════════════════════════════════
    // MARK: - 异步标记
    // ═══════════════════════════════════════════════════════════

    /// 标记这是一个异步 Operation。
    ///
    /// 系统 `Operation` 默认 `isAsynchronous = false`（同步）。
    /// 如果子类需要异步执行（如网络请求），必须重写为 `true`。
    ///
    /// 作用：
    /// - 告诉 `OperationQueue`：`start()` 返回后不要立即认为操作完成
    /// - 需要子类手动调用 `finish()` 标记完成
    public override var isAsynchronous: Bool {
        return true
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 暂停状态
    // ═══════════════════════════════════════════════════════════

    /// 是否已暂停。
    ///
    /// 注意：这个属性只是标记，**是否真正暂停取决于子类的实现**。
    /// 子类应在 `main()` 或执行循环里检查 `isPaused`，如果为 true 则挂起。
    ///
    /// 为什么不做成自动暂停：
    /// - `Operation` 没有内置的"暂停"语义
    /// - 暂停的实现方式因任务而异（如网络请求暂停、定时器暂停）
    /// - 所以基类只提供标记，子类自己处理
    public private(set) var isPaused = false

    // ═══════════════════════════════════════════════════════════
    // MARK: - isExecuting（执行中状态）
    // ═══════════════════════════════════════════════════════════

    /// 是否正在执行（KVO 安全）。
    ///
    /// 为什么需要手动管理：
    /// - 异步 Operation 的 `start()` 返回后，系统不知道任务是否还在跑
    /// - 必须通过 KVO 通知 `isExecuting` 变化，`OperationQueue` 才能正确调度
    ///
    /// 为什么用私有 `_isExecuting` + 计算属性：
    /// - 读写都要加锁（`lockQueue`）
    /// - 写入时要发 KVO 通知（`willChangeValue` / `didChangeValue`）
    /// - 系统 `Operation` 的 `isExecuting` 是只读的，无法直接覆盖
    private var _isExecuting = false

    public override private(set) var isExecuting: Bool {
        get {
            // ① 读操作：同步读取（读可以并发）
            return lockQueue.sync { () -> Bool in
                return _isExecuting
            }
        }
        set {
            // ② 写操作：先发 willChange，再 barrier 写入，最后发 didChange
            //    为什么需要 KVO：
            //    - `OperationQueue` 通过 KVO 监听 `isExecuting` 变化
            //    - 如果不发 KVO，队列不知道 Operation 开始执行了
            willChangeValue(forKey: #keyPath(isExecuting))
            lockQueue.sync(flags: [.barrier]) {
                _isExecuting = newValue
            }
            didChangeValue(forKey: #keyPath(isExecuting))
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - isFinished（完成状态）
    // ═══════════════════════════════════════════════════════════

    /// 是否已完成（KVO 安全）。
    ///
    /// 为什么需要手动管理：
    /// - 系统 `Operation` 在 `main()` 返回后认为完成
    /// - 但异步 Operation 的 `main()` 可能只是"发起任务"，真正完成在回调里
    /// - 必须通过 KVO 通知 `isFinished` 变化，`OperationQueue` 才知道任务完成
    ///
    /// ⚠️ 重要：
    /// - `isFinished = true` 后，Operation **不能再变成 false**
    /// - 否则会崩溃（系统断言）
    private var _isFinished = false

    public override private(set) var isFinished: Bool {
        get {
            return lockQueue.sync { () -> Bool in
                return _isFinished
            }
        }
        set {
            willChangeValue(forKey: #keyPath(isFinished))
            lockQueue.sync(flags: [.barrier]) {
                _isFinished = newValue
            }
            didChangeValue(forKey: #keyPath(isFinished))
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - isCancelled（取消状态）
    // ═══════════════════════════════════════════════════════════

    /// 是否已取消（KVO 安全）。
    ///
    /// 为什么需要手动管理：
    /// - 系统 `Operation` 的 `cancel()` 只是设置 `isCancelled` 标记
    /// - 但异步 Operation 需要在任务回调里检查 `isCancelled`，决定是否继续
    ///
    /// 注意：
    /// - `cancel()` 不等于"立即停止"
    /// - 只是设置标记，子类需要在合适时机检查并提前 `finish()`
    private var _isCancelled = false

    public override private(set) var isCancelled: Bool {
        get {
            return lockQueue.sync { () -> Bool in
                return _isCancelled
            }
        }
        set {
            willChangeValue(forKey: #keyPath(isCancelled))
            lockQueue.sync(flags: [.barrier]) {
                _isCancelled = newValue
            }
            didChangeValue(forKey: #keyPath(isCancelled))
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - finish（标记完成）
    // ═══════════════════════════════════════════════════════════

    /// 标记 Operation 完成。
    ///
    /// 子类在异步任务完成（成功 / 失败 / 取消）时**必须调用**。
    ///
    /// 流程：
    /// 1. `isExecuting = false`：不再执行
    /// 2. `isFinished = true`：标记完成，`OperationQueue` 会移除并调度下一个
    ///
    /// ⚠️ 注意：
    /// - 每个 Operation 只能调用一次 `finish()`
    /// - 调用后不能再改状态（再调用会崩溃）
    open func finish() {
        isExecuting = false
        isFinished = true
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - start（启动）
    // ═══════════════════════════════════════════════════════════

    /// 启动 Operation。
    ///
    /// 系统调用 `start()` 时：
    /// 1. 如果已取消 → 直接 `finish()`
    /// 2. 否则标记 `isExecuting = true`，调用 `main()`
    ///
    /// 注意：
    /// - 子类**不要**重写 `start()`，只重写 `main()`
    /// - `start()` 返回后，系统不会认为完成（因为 `isAsynchronous = true`）
    /// - 完成由子类调 `finish()` 通知
    public override func start() {
        FTLogger.info(message: "AsyncOperation: Try Starting")

        // ① 检查取消状态
        guard !isCancelled else {
            FTLogger.info(message: "AsyncOperation: Canceled before starting")
            finish()
            return
        }

        FTLogger.info(message: "AsyncOperation: Started")

        // ② 标记开始执行
        isFinished = false
        isExecuting = true

        // ③ 调用 main()（子类实现）
        //    ⚠️ 异步任务在 main() 里"发起"，完成由回调调 finish()
        main()
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - cancel（取消）
    // ═══════════════════════════════════════════════════════════

    /// 取消 Operation。
    ///
    /// 流程：
    /// 1. 调 `super.cancel()`（系统内部标记）
    /// 2. 设置 `isCancelled = true`（触发 KVO）
    ///
    /// 注意：
    /// - 只是设置标记，**不会立即停止任务**
    /// - 子类需在任务回调里检查 `isCancelled`，如果为 true 则提前 `finish()`
    open override func cancel() {
        super.cancel()
        isCancelled = true
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - main（子类实现）
    // ═══════════════════════════════════════════════════════════

    /// 子类必须重写。
    ///
    /// `fatalError` 保证如果子类忘记重写，会立即崩溃（开发期暴露问题）。
    ///
    /// ⚠️ 子类不要调用 `super.main()`。
    open override func main() {
        fatalError("Subclass should implement `main()` and Never call super.main()")
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - pause / resume
    // ═══════════════════════════════════════════════════════════

    /// 暂停 Operation。
    ///
    /// 只设置标记，是否真正暂停取决于子类实现。
    open func pause() {
        isPaused = true
    }

    /// 恢复 Operation。
    ///
    /// 只清除标记，是否真正恢复取决于子类实现。
    open func resume() {
        isPaused = false
    }
}
