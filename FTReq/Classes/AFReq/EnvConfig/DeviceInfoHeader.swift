//
//  DeviceInfoHeader.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/26.
//  

import UIKit

// 导入 CoreTelephony：提供 CTTelephonyNetworkInfo，用于获取运营商名称
import CoreTelephony

// 导入 CFNetwork：提供 CFNetworkCopySystemProxySettings，用于读取系统代理设置
import CFNetwork

// 导入 Darwin：提供底层 POSIX API，如 uname（机型）、getifaddrs（网络接口）、task_info（内存）
import Darwin


/// 设备信息请求头生成器。
///
/// 用 enum 作为命名空间：
/// - 纯静态方法，不可实例化
/// - 语义上就是"工具集合"
enum DeviceInfoHeader {

    // ═══════════════════════════════════════════════════════════
    // MARK: - 对外入口
    // ═══════════════════════════════════════════════════════════

    /// 生成编码后的 deviceinfo 请求头值。
    ///
    /// 完整流程：
    /// 1. 采集设备信息（20+ 项指标）
    /// 2. 序列化成 JSON
    /// 3. URL 编码（HTTP header 不能含特殊字符）
    ///
    /// - Parameters:
    ///   - config: 网络配置（需要 deviceId 作为设备唯一标识）
    ///   - networkStatu: 当前网络状态（wifi / cellular / none / unavailable）
    /// - Returns: URL 编码后的 JSON 字符串；任一步失败返回 nil
    static func makeEncodedValue(config: NetworkConfig, networkStatu: NetworkStatu) -> String? {

        // ① 采集设备信息，得到字典（已过滤 nil 值）
        let payload = makePayload(config: config, networkStatu: networkStatu)

        // ② 校验 payload 是否是合法 JSON 对象
        //    为什么需要：字典里如果有 Date、Data、自定义类等非 JSON 类型，
        //    序列化会失败。提前校验避免后续抛错。
        guard JSONSerialization.isValidJSONObject(payload),

              // ③ 序列化成 Data
              //    try? 吞掉错误：上报失败不影响主流程，直接返回 nil
              let data = try? JSONSerialization.data(withJSONObject: payload, options: []),

              // ④ Data 转 UTF-8 字符串
              //    编码失败（理论上不会）返回 nil
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }

        // ⑤ URL 编码
        //    为什么需要：HTTP header 不能包含 { } " 空格 等特殊字符，
        //    URL 编码后变成 %7B %7D %22 %20，保证安全
        //    只用 RFC 3986 的 unreserved 字符集，其他全部转义
        return json.addingPercentEncoding(withAllowedCharacters: urlQueryValueAllowed)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 采集设备信息（核心）
    // ═══════════════════════════════════════════════════════════

    /// 采集设备信息（20+ 项指标），返回字典。
    ///
    /// - Parameters:
    ///   - config: 网络配置（取 deviceId）
    ///   - networkStatu: 网络状态
    /// - Returns: 设备信息字典（nil 值已被过滤）
    private static func makePayload(config: NetworkConfig, networkStatu: NetworkStatu) -> [String: Any] {

        // ───────── 3.1 基础引用 ─────────

        // 当前设备（后续多处使用，避免重复调用 UIDevice.current）
        let device = UIDevice.current

        // ───────── 3.2 内存信息 ─────────

        // 总物理内存（字节）
        // physicalMemory 是 UInt64，转 Int64 避免后续计算溢出
        let totalRAM = Int64(ProcessInfo.processInfo.physicalMemory)

        // 当前 App 已用内存（字节）
        // 调用 Mach API 获取 resident_size，失败兜底 0
        let usedRAM = Int64(usedAppMemoryBytes() ?? 0)

        // ───────── 3.3 存储信息 ─────────

        // 总存储容量（字节）
        // 读 volumeTotalCapacityKey，失败兜底 0
        let totalStorage = totalStorageBytes() ?? 0

        // 已用存储（字节）
        // 需要传 totalStorage 计算（已用 = 总 - 可用）
        let usedStorage = usedStorageBytes(totalStorage: totalStorage) ?? 0

        // ───────── 3.4 电池监控 ─────────

        // 保存电池监控的原状态
        // isBatteryMonitoringEnabled 默认 false
        let previousBatteryMonitoringState = device.isBatteryMonitoringEnabled

        // 临时开启电池监控
        // 为什么：关闭状态下 batteryLevel 返回 -1（未知），开启才能读真实电量
        device.isBatteryMonitoringEnabled = true

        // defer 延迟恢复：函数退出时一定执行（无论正常返回还是提前 return）
        // 为什么：电池监控有性能开销（系统持续监控），用完立即关闭
        defer { device.isBatteryMonitoringEnabled = previousBatteryMonitoringState }

        // 读电量百分比（0~100 的整数，未知时 nil）
        let batteryLevel = batteryLevelPercent(for: device)

        // ───────── 3.5 屏幕信息 ─────────

        // 主屏幕
        // ⚠️ iOS 26+ 中 UIScreen.main 已废弃，应改用 windowScene.screen
        let screen = UIScreen.main

        // ───────── 3.6 组装 payload ─────────

        // 类型是 [String: Any?]（value 可选）
        // 为什么：部分字段可能返回 nil（如电量未知），用 Any? 允许 nil
        let payload: [String: Any?] = [

            // ① 品牌：固定 Apple
            "brand": "Apple",

            // ② 制造商：固定 Apple
            "manufacturer": "Apple",

            // ③ 机型标识：如 iPhone15,2、iPad13,4
            //    用 uname 读 utsname.machine
            "model": machineIdentifier(),

            // ④ 国家/地区：如 CN、US
            //    Locale.current.regionCode，取不到返回空字符串
            "country": Locale.current.regionCode ?? "",

            // ⑤ 屏幕密度（DPI）：nativeScale * 160
            //    如 @3x 屏：3.0 * 160 = 480 DPI
            "densityDpi": Int(screen.nativeScale * 160.0),

            // ⑥ 密度名：对齐 Android 的 mdpi/xhdpi/xxhdpi/xxxhdpi
            "densityName": densityName(for: screen.nativeScale),

            // ⑦ IP 类型：IPv4 / IPv6 / IPv4/IPv6
            //    遍历网络接口检测
            "ipType": ipType(),

            // ⑧ 是否 Debug 包：编译期判断（#if DEBUG）
            //    服务端风控用：Debug 包可能是越狱或破解版
            "isDebug": isDebugBuild,

            // ⑨ 是否开了代理：风控核心指标
            //    检测 HTTP/HTTPS/SOCKS 代理
            "isProxy": isProxyEnabled(),

            // ⑩ 网络类型：wifi / cellular / none / unknown
            "netWorkInfo": networkInfo(from: networkStatu),

            // ⑪ 运营商名称：如 中国移动、中国联通
            //    iOS 12+ 用 serviceSubscriberCellularProviders
            "operatorName": carrierName(),

            // ⑫ iOS 大版本号：如 17、18
            "osBigVersionCode": ProcessInfo.processInfo.operatingSystemVersion.majorVersion,

            // ⑬ 系统名：固定 iOS
            "osName": device.systemName,

            // ⑭ 系统版本：如 17.2.1
            "osVersionName": device.systemVersion,

            // ⑮ 电源状态：charging（充电）/ full（满电）/ battery（电池）/ unknown
            "powerSource": powerSource(for: device),

            // ⑯ 内存使用率（0~100 的整数）
            "ramUsagePercent": usagePercent(used: usedRAM, total: totalRAM),

            // ⑰ 屏幕刷新率：60 / 120
            //    maximumFramesPerSecond 返回 Int，转 Double
            "refreshRate": Double(screen.maximumFramesPerSecond),

            // ⑱ 屏幕分辨率（物理像素）：如 1179x2556
            "screenResolution": screenResolution(for: screen),

            // ⑲ 存储使用率（0~100 的整数）
            "storageUsagePercent": usagePercent(used: usedStorage, total: totalStorage),

            // ⑳ 总内存（GB，保留 2 位小数）
            "totalRAM": formatBytesToGBString(totalRAM),

            // ㉑ 总存储（GB）
            "totalStorage": formatBytesToGBString(totalStorage),

            // ㉒ 已用内存（GB）
            "usedRAM": formatBytesToGBString(usedRAM),

            // ㉓ 已用存储（GB）
            "usedStorage": formatBytesToGBString(usedStorage),

            // ㉔ 设备唯一 id：来自 config.deviceId（持久化在 Keychain）
            "uuid": config.deviceId,

            // ㉕ 单次请求追踪 id：每次随机生成
            //    注意：不是设备标识，只用于日志关联
            "iosId": UUID().uuidString,

            // ㉖ 电量百分比：0~100 的整数，未知时 nil
            "batteryLevel": batteryLevel
        ]

        // ⑦ 过滤 nil 值
        // compactMapValues：遍历所有 value，nil 的键值对直接丢弃
        // 为什么：JSON 序列化不支持 nil 值，必须过滤
        return payload.compactMapValues { $0 }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - URL 编码字符集
    // ═══════════════════════════════════════════════════════════

    /// URL 编码允许的字符集。
    ///
    /// 这是 RFC 3986 的 unreserved 字符集：
    /// - 字母（a-z, A-Z）
    /// - 数字（0-9）
    /// - 特殊字符：- . _ ~
    ///
    /// 其他字符都会被转义：
    /// - { → %7B
    /// - } → %7D
    /// - " → %22
    /// - 空格 → %20
    ///
    /// 用 lazy 静态属性：只初始化一次，避免每次调用都构建 CharacterSet
    private static var urlQueryValueAllowed: CharacterSet = {
        // 从字母数字开始
        var allowed = CharacterSet.alphanumerics
        // 加入 RFC 3986 的 unreserved 特殊字符
        allowed.insert(charactersIn: "-._~")
        return allowed
    }()

    // ═══════════════════════════════════════════════════════════
    // MARK: - 编译期判断
    // ═══════════════════════════════════════════════════════════

    /// 是否是 Debug 包。
    ///
    /// 用 #if DEBUG 编译期判断：
    /// - Debug 包：true
    /// - Release 包：false
    ///
    /// 服务端用这个字段识别非 App Store 渠道的包（可能是越狱或破解版）。
    private static var isDebugBuild: Bool {
#if DEBUG
        return true
#else
        return false
#endif
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 网络类型
    // ═══════════════════════════════════════════════════════════

    /// 网络状态转字符串。
    ///
    /// - Parameter statu: 网络状态枚举
    /// - Returns: 字符串表示
    private static func networkInfo(from statu: NetworkStatu) -> String {
        switch statu {
        case .wifi:
            // WiFi 网络
            return "wifi"
        case .cellular:
            // 蜂窝网络（2G/3G/4G/5G）
            return "cellular"
        case .none:
            // 无网络
            return "none"
        case .unavailable:
            // 网络状态不可用（未知）
            return "unknown"
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 电池相关
    // ═══════════════════════════════════════════════════════════

    /// 电量百分比（0~100 的整数）。
    ///
    /// - Parameter device: 设备
    /// - Returns: 电量百分比；未知时返回 nil
    private static func batteryLevelPercent(for device: UIDevice) -> Int? {
        // batteryLevel 返回 0.0~1.0 的浮点数
        // 未开启电池监控时返回 -1，此时返回 nil（表示未知）
        guard device.batteryLevel >= 0 else { return nil }

        // 乘 100 后四舍五入转 Int
        return Int((device.batteryLevel * 100.0).rounded())
    }

    /// 电源状态转字符串。
    ///
    /// - Parameter device: 设备
    /// - Returns: charging / full / battery / unknown
    private static func powerSource(for device: UIDevice) -> String {
        switch device.batteryState {
        case .charging:
            // 充电中
            return "charging"
        case .full:
            // 满电
            return "full"
        case .unplugged:
            // 电池供电（未充电）
            return "battery"
        case .unknown:
            // 未知
            return "unknown"
        @unknown default:
            // 未来新增的状态兜底
            return "unknown"
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 屏幕相关
    // ═══════════════════════════════════════════════════════════

    /// 屏幕密度名（对齐 Android 的密度概念）。
    ///
    /// iOS 的 scale 和 Android 的 density 概念不同，但映射关系固定：
    /// - 1.0 → mdpi（160dpi，老设备）
    /// - 2.0 → xhdpi（320dpi，iPhone 4s~8）
    /// - 3.0 → xxhdpi（480dpi，iPhone X 及以后）
    /// - 更高 → xxxhdpi（未来设备）
    ///
    /// - Parameter scale: 屏幕 scale（nativeScale）
    /// - Returns: 密度名字符串
    private static func densityName(for scale: CGFloat) -> String {
        switch scale {
        case ..<1.5:
            // scale < 1.5（@1x）
            return "mdpi"
        case ..<2.5:
            // 1.5 <= scale < 2.5（@2x）
            return "xhdpi"
        case ..<3.5:
            // 2.5 <= scale < 3.5（@3x）
            return "xxhdpi"
        default:
            // scale >= 3.5（更高）
            return "xxxhdpi"
        }
    }

    /// 屏幕分辨率（物理像素）。
    ///
    /// nativeBounds 是物理像素（不是 point），如 iPhone 14 Pro 是 1179x2556。
    ///
    /// - Parameter screen: 屏幕
    /// - Returns: "宽x高" 格式的字符串
    private static func screenResolution(for screen: UIScreen) -> String {
        let bounds = screen.nativeBounds
        return "\(Int(bounds.width))x\(Int(bounds.height))"
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 字节格式化
    // ═══════════════════════════════════════════════════════════

    /// 字节转 GB 字符串（保留 2 位小数）。
    ///
    /// 注意：用 1_000_000_000（10^9）而不是 1_073_741_824（2^30）。
    /// 为什么：和 Android 的"GB"口径一致（厂商宣传口径），
    /// 也和 iOS 设置里的"GB"可能不一致（iOS 用 2^30）。
    ///
    /// - Parameter bytes: 字节数
    /// - Returns: "xx.xx" 格式的字符串（如 "128.00"）
    private static func formatBytesToGBString(_ bytes: Int64) -> String {
        // 非正数直接返回 "0.00"
        guard bytes > 0 else { return "0.00" }

        // 转 GB（10^9 口径）
        let value = Double(bytes) / 1_000_000_000.0

        // 保留 2 位小数
        return String(format: "%.2f", value)
    }

    /// 使用率百分比（0~100 的整数）。
    ///
    /// - Parameters:
    ///   - used: 已用量
    ///   - total: 总量
    /// - Returns: 使用率百分比；used 或 total 无效时返回 0
    private static func usagePercent(used: Int64, total: Int64) -> Int {
        // used 或 total 为 0 时返回 0（避免除零）
        guard used > 0, total > 0 else { return 0 }

        // 计算百分比 + 四舍五入
        return Int((Double(used) / Double(total) * 100.0).rounded())
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 存储信息
    // ═══════════════════════════════════════════════════════════

    /// 总存储容量（字节）。
    ///
    /// 通过 URL 资源值读取 volumeTotalCapacityKey。
    ///
    /// - Returns: 总存储字节数；读取失败返回 nil
    private static func totalStorageBytes() -> Int64? {
        // 用 App 沙盒根目录（NSHomeDirectory）作为 URL
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())

        // 读取 volumeTotalCapacityKey（总容量）
        let values = try? homeURL.resourceValues(forKeys: [.volumeTotalCapacityKey])

        if let total = values?.volumeTotalCapacity {
            return Int64(total)
        }
        return nil
    }

    /// 已用存储（字节）。
    ///
    /// 优先用 volumeAvailableCapacityForImportantUsage：
    /// - 它考虑了系统可清理空间（如缓存、临时文件）
    /// - 和 iOS 设置里的"可用空间"一致
    ///
    /// 退化到 volumeAvailableCapacity：严格可用空间。
    ///
    /// - Parameter totalStorage: 总存储（用于计算已用 = 总 - 可用）
    /// - Returns: 已用存储字节数；读取失败返回 nil
    private static func usedStorageBytes(totalStorage: Int64) -> Int64? {
        guard totalStorage > 0 else { return nil }

        let homeURL = URL(fileURLWithPath: NSHomeDirectory())

        // 同时读两个 key（优先用 ForImportantUsage）
        let values = try? homeURL.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ])

        // 优先用 ForImportantUsage（考虑可清理空间）
        if let available = values?.volumeAvailableCapacityForImportantUsage {
            // 已用 = 总 - 可用，负数归零
            return max(totalStorage - available, 0)
        }

        // 退化到 volumeAvailableCapacity（严格可用空间）
        if let available = values?.volumeAvailableCapacity {
            return max(totalStorage - Int64(available), 0)
        }
        return nil
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 内存信息
    // ═══════════════════════════════════════════════════════════

    /// 当前 App 已用内存（字节）。
    ///
    /// 用 Mach API 读取当前进程的常驻内存（resident_size）。
    ///
    /// ⚠️ resident_size 是物理内存，不含压缩内存。
    /// 更准确的是 phys_footprint（含压缩内存），但 API 更复杂。
    ///
    /// - Returns: 已用内存字节数；读取失败返回 nil
    private static func usedAppMemoryBytes() -> UInt64? {

        // ① 准备 mach_task_basic_info 结构体
        var info = mach_task_basic_info()

        // ② 计算结构体的"字数"（多少个 natural_t）
        //    因为 task_info 的参数类型是 mach_msg_type_number_t
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )

        // ③ 调用 task_info 读取当前进程的内存信息
        //    用 withUnsafeMutablePointer 获取 &info 的指针
        //    用 withMemoryRebound 把 info 指针重绑定成 integer_t（task_info 要求）
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) { infoPointer in
            infoPointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                task_info(
                    mach_task_self_,                          // 当前进程
                    task_flavor_t(MACH_TASK_BASIC_INFO),     // 读取基础信息
                    intPointer,                               // 输出指针
                    &count                                    // 输出长度
                )
            }
        }

        // ④ 检查调用结果
        guard result == KERN_SUCCESS else { return nil }

        // ⑤ 返回常驻内存大小（字节）
        return UInt64(info.resident_size)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 运营商信息
    // ═══════════════════════════════════════════════════════════

    /// 运营商名称。
    ///
    /// iOS 12+ 用 serviceSubscriberCellularProviders（多 SIM 支持），
    /// 旧版本用 subscriberCellularProvider（单 SIM）。
    ///
    /// ⚠️ iOS 16+ 中 serviceSubscriberCellularProviders 可能返回空（隐私政策变更）。
    ///
    /// - Returns: 运营商名称；取不到返回空字符串
    private static func carrierName() -> String {
        let networkInfo = CTTelephonyNetworkInfo()

        // 直接使用 iOS 12+ 的 API，不再回退到已废弃的旧 API
        if let carrier = networkInfo.serviceSubscriberCellularProviders?.values.first(where: {
            !($0.carrierName ?? "").isEmpty
        }) {
            return carrier.carrierName ?? ""
        }
        
        return ""
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 代理检测（风控核心）
    // ═══════════════════════════════════════════════════════════

    /// 是否开启了代理（风控关键指标）。
    ///
    /// 检查系统代理设置里的：
    /// - HTTPEnable：HTTP 代理是否开启
    /// - HTTPSEnable：HTTPS 代理是否开启
    /// - SOCKSEnable：SOCKS 代理是否开启
    ///
    /// 任一开启即认为使用了代理。
    ///
    /// ⚠️ 只检测系统代理，不检测：
    /// - VPN（需要额外检测）
    /// - 抓包工具的透明代理（如 Charles 的 SSL Proxying）
    ///
    /// - Returns: 是否开启了代理
    private static func isProxyEnabled() -> Bool {
        // 读取系统代理设置
        // CFNetworkCopySystemProxySettings 返回 CFDictionary?，
        // takeRetainedValue() 接管所有权，
        // 转成 Swift 的 [AnyHashable: Any]
        guard let proxySettings = CFNetworkCopySystemProxySettings()?
            .takeRetainedValue() as? [AnyHashable: Any] else {
            return false
        }

        // 检查的三个代理类型
        let proxyKeys = [
            "HTTPEnable",    // HTTP 代理
            "HTTPSEnable",   // HTTPS 代理
            "SOCKSEnable"    // SOCKS 代理
        ]

        // 任一为 true 就算开了代理
        return proxyKeys.contains { key in
            if let value = proxySettings[key] as? NSNumber {
                return value.boolValue
            }
            return false
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - IP 类型检测
    // ═══════════════════════════════════════════════════════════

    /// 检测当前网络是 IPv4、IPv6 还是双栈。
    ///
    /// 遍历所有网络接口，找非回环、运行中的接口的地址类型。
    ///
    /// - Returns: "IPv4" / "IPv6" / "IPv4/IPv6" / ""（未知）
    private static func ipType() -> String {
        // ① 输出指针
        var addressPointer: UnsafeMutablePointer<ifaddrs>?

        // ② 标志位
        var hasIPv4 = false
        var hasIPv6 = false

        // ③ 调用 getifaddrs 获取所有网络接口
        guard getifaddrs(&addressPointer) == 0, let firstAddress = addressPointer else {
            return ""
        }

        // ④ defer 保证释放指针（避免内存泄漏）
        defer { freeifaddrs(addressPointer) }

        // ⑤ 遍历所有接口
        var pointer = firstAddress
        while true {
            let interface = pointer.pointee
            let flags = Int32(interface.ifa_flags)

            // 检查接口是否运行中（IFF_UP | IFF_RUNNING）
            let isRunning = (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING)

            // 检查是否是回环接口（lo0），回环不算
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK

            if isRunning, !isLoopback, let address = interface.ifa_addr {
                // 读地址族（AF_INET = IPv4，AF_INET6 = IPv6）
                switch Int32(address.pointee.sa_family) {
                case AF_INET:
                    hasIPv4 = true
                case AF_INET6:
                    hasIPv6 = true
                default:
                    break
                }
            }

            // ⑥ 移到下一个接口
            guard let next = interface.ifa_next else { break }
            pointer = next
        }

        // ⑦ 根据标志位返回结果
        if hasIPv4 && hasIPv6 { return "IPv4/IPv6" }
        if hasIPv6 { return "IPv6" }
        if hasIPv4 { return "IPv4" }
        return ""
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - 机型标识
    // ═══════════════════════════════════════════════════════════

    /// 获取机型标识（如 iPhone15,2、iPad13,4）。
    ///
    /// 用 uname 读取 utsname.machine，这是 iOS 内部机型代号。
    ///
    /// - Returns: 机型标识；读取失败用 UIDevice.current.model 兜底
    private static func machineIdentifier() -> String {

        // ① 准备 utsname 结构体
        var systemInfo = utsname()

        // ② 调用 uname 填充结构体
        uname(&systemInfo)

        // ③ 用 Mirror 反射读取 machine 字段（C 字符串，Int8 元组）
        let machineMirror = Mirror(reflecting: systemInfo.machine)

        // ④ 逐个读取 Int8 字节，转成字符
        //    遇到 0（C 字符串结束符）停止
        let identifier = machineMirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }

        // ⑤ 兜底：读不到用 UIDevice.current.model
        return identifier.isEmpty ? UIDevice.current.model : identifier
    }
}
