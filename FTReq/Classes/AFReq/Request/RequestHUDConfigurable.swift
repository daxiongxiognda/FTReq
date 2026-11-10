//
//  RequestHUDConfigurable.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/26.
//

import FTTool

// ═══════════════════════════════════════════════════════════════
// MARK: - HUDCompatible（HUD 实现者协议）
// ═══════════════════════════════════════════════════════════════

/// 外部真实显示 HUD 的实现者，解除网络库对 UI 的依赖。
///
/// 设计意图：
/// - 网络库（FTReq）只依赖协议，不 import UIKit
/// - 业务层实现协议，注入给 NetworkManager
/// - 网络库通过 `NetworkManager.uimanager` 调用
///
/// 实现者示例：
/// ```swift
/// class HUDManager: HUDCompatible {
///     func showHUD(type: RequestHUDType) { /* 显示 HUD */ }
///     func hideHUD() { /* 隐藏 HUD */ }
///     // ...
/// }
///
/// NetworkManager.shared.configUIManager(with: HUDManager())
/// ```
///
/// 用 `AnyObject` 约束：
/// - 只能 class 实现（便于弱引用）
/// - `NetworkManager.uimanager` 用 `weak` 持有，避免循环引用
public protocol HUDCompatible: AnyObject {

    /// 显示弹窗。
    /// - Parameter config: 弹窗配置（标题、消息、按钮、回调）
    func showAlert(config: AlertConfig)

    /// 显示 HUD。
    /// - Parameter type: HUD 类型（loading / suc / err / info / alert）
    func showHUD(type: RequestHUDType)

    /// 隐藏 HUD。
    func hideHUD()

    /// 显示错误页。
    /// - Parameters:
    ///   - config: 错误页配置（标题、详情、按钮、回调）
    ///   - fromVC: 从哪个 VC 弹出（可能为 nil）
    func showErrorView(config: ErrorViewConfig, fromVC: UIViewController?)
}

// ═══════════════════════════════════════════════════════════════
// MARK: - HUDConfigurable（请求对象可配置 HUD）
// ═══════════════════════════════════════════════════════════════

/// HUD 配置协议（允许动态覆盖）。
///
/// 实现者（如 `ApiConvertable`）通过这个协议暴露自己的 HUD 配置，
/// 网络库根据配置决定是否显示 HUD、显示什么文案。
///
/// 调用链（结合你之前看的 `NetworkManager.checkShowHUD` / `checkHideHUD`）：
/// ```
/// 请求发起 → 读 apiConvertable.hudConfig?.loading → 决定显示什么
/// 请求结束 → 读 apiConvertable.hudConfig?.err / suc → 决定显示什么
/// ```
public protocol HUDConfigurable {

    /// HUD 配置（可选，nil 表示不显示 HUD）。
    var hudConfig: HUDConfig? { get }

    /// 显示指定类型的 HUD。
    func showHUD(type: RequestHUDType)

    /// 隐藏 HUD。
    /// - Parameter success: 是否成功（可能影响隐藏动画）
    func hideHUD(success: Bool)
}

// ═══════════════════════════════════════════════════════════════
// MARK: - HUDConfig（HUD 配置）
// ═══════════════════════════════════════════════════════════════

// 旧版本（已注释，保留参考）：
// public struct HUDConfig {
//     public var loading: String?  // 加载提示
//     public var suc: String?      // 成功提示
//     public var err: String?      // 失败提示
//
//     public init(loading: String? = nil, suc: String? = nil, err: String? = nil) {
//         self.loadingTitle = loadingTitle       // ⚠️ 旧代码有 bug：变量名不对
//         self.successTitle = successTitle
//         self.failureTitle = failureTitle
//     }
// }

/// HUD 配置。
///
/// 三个字段对应请求的三个阶段：
/// - `loading`：请求进行中显示的文案（nil 表示不显示 loading）
/// - `suc`：请求成功时显示的文案（nil 表示不显示成功提示）
/// - `err`：请求失败时显示的文案（默认空串，表示用服务端返回的错误消息）
///
/// 文案优先级（结合 `NetworkManager.checkHideHUD`）：
/// - 配置了非空文案 → 显示配置的
/// - 配置了空串 → 显示服务端返回的消息
/// - 配置为 nil → 不显示
public struct HUDConfig {

    /// 加载提示（nil = 不显示 loading）。
    public var loading: String?

    /// 成功提示（nil = 不显示成功提示）。
    public var suc: String?

    /// 失败提示（默认空串 = 用服务端错误消息）。
    public var err: String?

    public init(loading: String? = nil, suc: String? = nil, err: String? = "") {
        self.loading = loading
        self.suc = suc
        self.err = err
    }
}

// 另一种被注释的设计（保留参考）：
// public struct HUDConfig {
//     public var loading: RequestHUDType
//     public var suc: RequestHUDType
//     public var err: RequestHUDType
//     // ...
// }

// ═══════════════════════════════════════════════════════════════
// MARK: - RequestHUDType（HUD 类型）
// ═══════════════════════════════════════════════════════════════

// 旧版本（已注释）：
// public enum RequestHUDType {
//     case none
//     case loading(text: String)
//     case success(text: String)
//     case failure(text: String)
//     case info(text: String)
// }

/// HUD 类型枚举。
///
/// 用匿名参数（`_ text: String`）而不是命名参数（`text: String`），
/// 调用时更简洁：`.loading("加载中")` vs `.loading(text: "加载中")`。
public enum RequestHUDType {

    /// 不显示。
    case none

    /// 加载中（带菊花）。
    case loading(_ text: String)

    /// 成功提示（带 ✅ 图标）。
    case suc(_ text: String)

    /// 失败提示（带 ❌ 图标）。
    case err(_ text: String)

    /// 纯文字提示（无图标）。
    case info(_ text: String)

    /// 弹窗提示（需要用户确认）。
    case alert(_ text: String)
}

// ═══════════════════════════════════════════════════════════════
// MARK: - AlertConfig（弹窗配置）
// ═══════════════════════════════════════════════════════════════

/// 弹窗配置。
///
/// 支持两种消息格式：
/// - `message`：纯文本
/// - `attMessage`：富文本（NSMutableAttributedString）
///
/// 如果两者都传，通常 `attMessage` 优先（具体看实现者）。
public struct AlertConfig {

    /// 标题。
    public var title: String = ""

    /// 消息（纯文本）。
    public var message: String = ""

    /// 消息（富文本，优先于 message）。
    public var attMessage: NSMutableAttributedString?

    /// 取消按钮文案。
    public var cancel: String = "取消"

    /// 确认按钮文案。
    public var confirm: String = "确定"

    /// 自定义视图（可选，如果有则显示在弹窗里）。
    public var view: UIView?

    /// 是否从父视图移除（关闭弹窗时的行为）。
    public var removeFromSuperView: Bool = true

    /// 取消按钮的回调。
    public var cancelAction: VoidClosure?

    /// 确认按钮的回调。
    public var confirmAction: VoidClosure?

    public init(
        title: String = "",
        message: String = "",
        attMessage: NSMutableAttributedString? = nil,
        cancel: String = "取消",
        confirm: String = "确定",
        view: UIView? = nil,
        removeFromSuperView: Bool = true,
        cancelAction: VoidClosure? = nil,
        confirmAction: VoidClosure? = nil
    ) {
        self.title = title
        self.message = message
        self.attMessage = attMessage
        self.cancel = cancel
        self.confirm = confirm
        self.view = view
        self.removeFromSuperView = removeFromSuperView
        self.cancelAction = cancelAction
        self.confirmAction = confirmAction
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - ErrorViewConfig（错误页配置）
// ═══════════════════════════════════════════════════════════════

/// 错误页配置。
///
/// 用于网络请求失败时显示全屏错误页（如"网络异常，请重试"），
/// 通常带"返回"和"重试"两个按钮。
public struct ErrorViewConfig {

    /// 错误标题（如"网络异常"）。
    public var title: String?

    /// 错误详情（如"请检查网络设置"）。
    public var detailTitle: String?

    /// 按钮文案（如"重试"）。
    public var btnTitle: String?

    /// 返回按钮的回调。
    public var backAction: VoidClosure?

    /// 重试按钮的回调。
    public var retryAction: VoidClosure?

    public init(
        title: String? = nil,
        detailTitle: String? = nil,
        btnTitle: String? = nil,
        backAction: VoidClosure? = nil,
        retryAction: VoidClosure? = nil
    ) {
        self.title = title
        self.detailTitle = detailTitle
        self.btnTitle = btnTitle
        self.backAction = backAction
        self.retryAction = retryAction
    }
}
