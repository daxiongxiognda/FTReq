//
//  UploadModels.swift
//  FTTool
//
//  Created by 熊坤鹏 on 2026/10/27.
//

import FTTool
import Alamofire

// MARK: - 腾讯云上传凭证

/// 腾讯云上传所需的凭证信息（由服务端下发，客户端据此直传 COS）
/// 图片与视频字段分开存放，因为两类资源的 host / key / 签名 / token 可能不同
public struct TencentUploadResInfo: Codable {
    /// 云服务 host（COS 域名，如 xxx.cos.ap-shanghai.myqcloud.com）
    public var cosHost: String?

    /// 云服务图片文件上传路径（对象 Key，即 COS 上的存储路径）
    public var cosKey: String?

    /// 云服务图片文件上传签名（Authorization 头）
    public var authorization: String?

    /// 图片临时的 token（STS 临时密钥的 SecurityToken）
    public var securityToken: String?

    /// 图片压缩的配置 json 字符串（COS 图片处理参数 pic-operations）
    public var picOperations: String?

    /// 图片 CDN URL（上传成功后访问地址）
    public var cdnUrl: String?

    /// 视频文件 CDN URL
    public var videoCdnUrl: String?

    /// 云服务视频文件上传路径
    public var videoCosKey: String?

    /// 云服务视频文件上传签名
    public var videoAuthorization: String?

    /// 云服务视频文件上传 sessionToken
    public var videoSecurityToken: String?
}


// MARK: - 上传资源类型枚举

/// 上传资源业务类型，Int 值对应服务端约定的枚举
/// 遵循 EnumCodable：未知值会回退到 defaultCase（.unkonwn）而非解码失败
public enum UploadResType: Int, EnumCodable {
    public static var defaultCase: UploadResType = .unkonwn

    /// 0 代表未知
    case unkonwn = 0
    /// 1 代表用户反馈
    case userFeedback = 1
    /// 2 代表群组头像
    case groupPhoto = 2
    /// 3 代表用户头像
    case userAvatar = 3
    /// 4 是 ugc 图片
    case picture = 4
    /// 5 ugc 视频
    case video = 5
    /// 6 活动图片
    case activity = 6
    /// 7 消息图片
    case messageImage = 7
    /// 8 消息音频
    case messageAudio = 8
    /// 9 代表视频（消息视频）
    case messageVideo = 9
    /// 10 代表经营证图片
    case dipi = 10
    /// 12 代表商城
    case mall = 12
    /// 13 代表本地生活
    case localLife = 13
    /// 14 代表联联
    case lianLian = 14
    /// 15 zip 日志
    case zipFile = 15
    /// 16 GIF 图
    case messageGif = 16
    /// 17 文件（未显式写 rawValue，默认 = 17，依赖前一个 case 的 rawValue + 1）
    case file
    /// 18 热门话题图
    case hotTopic = 18
    /// ⚠️ 注释写"20 表情包"，但 rawValue 是 21，注释与代码不一致
    case sticker = 21
    /// 语音房（rawValue 未显式写 = 22）
    case audioRoom = 22
    /// 私聊背景图
    case privateChatBGImg = 23
    /// nft 图片
    case nftImage = 25
    /// nft 视频
    case nftVideo = 26
    /// 地皮 2.0 头图
    case dp2headImage = 27
    /// 地皮 2.0 视频
    case dp2Video = 28
    /// H5 支付平台
    case paymentPlatform = 29
    /// 群名片背景图
    case groupBgImg = 30
    /// ip 俱乐部
    case ipPhoto = 31
}


// MARK: - 通用任务结果

/// 通用异步任务结果包装（上传、请求等复用）
/// - code: 业务状态码
/// - msg: 提示信息
/// - data: 实际负载
public struct TaskResult<T: Codable>: Codable {
    public var code: Int
    public var msg: String?
    public var data: T?

    public init(code: Int, data: T? = nil) {
        self.code = code
        self.data = data
    }
    // ⚠️ 注意：init 里没有 msg 参数，但结构体声明了 msg 字段，
    //    意味着外部无法通过 init 设置 msg（只能解码时赋值），
    //    若业务需要构造带 msg 的结果需补参数。
}


// MARK: - 上传结果

/// 单个文件的上传结果
public struct UploadResult: Codable {
    public var code: Int
    public var sucUrl: String?        // 上传成功后的访问 URL
    public var path: String?          // 本地文件路径
    public var width: String?         // 宽度
    public var height: String?        // 高度
    public var duration: String?      // 时长
    public var cdnUrl: String?        // CDN 地址
    public var videoCdnUrl: String?   // 视频 CDN 地址

    /// 初始化：默认把 sucUrl 同时写入 cdnUrl
    /// - 说明：width/height/duration 用 String 而非数值，
    ///   可能是为了兼容服务端返回字符串或空值，但不利于数值计算，需注意转换。
    public init(code: Int,
                sucUrl: String? = nil,
                path: String? = nil,
                width: String? = nil,
                height: String? = nil,
                duration: String? = nil,
                videoCdnUrl: String? = nil) {
        self.code = code
        self.sucUrl = sucUrl
        self.cdnUrl = sucUrl          // 默认 cdnUrl = sucUrl
        self.path = path
        self.width = width
        self.height = height
        self.duration = duration
        self.videoCdnUrl = videoCdnUrl
    }
}


// MARK: - 上传数据抽象协议

/// 上传数据源抽象：URL / Data / UIImage 等都实现此协议
/// 统一提供：表单字段名、文件名、MIME、大小、multipart 追加、流式读取
public protocol UploadDatable {
    var fieldName: String { get set }
    var fileName: String? { get set }
    var mimeType: String? { get set }
    var size: Int64 { get }
    func append(to multipartFormData: MultipartFormData)
    var stream: InputStream? { get }
}

// 协议默认实现：普通表单上传不需要 stream，默认返回 nil；append 默认空实现
public extension UploadDatable {
    func append(to multipartFormData: MultipartFormData) {}
    var stream: InputStream? { return nil }
}


// MARK: - 基于本地文件 URL 的上传数据

open class UploadFileURL: UploadDatable {
    let fileURL: URL
    public var fieldName: String
    public var fileName: String?
    public var mimeType: String?

    /// 文件大小：每次访问都会读一次文件属性
    /// ⚠️ 性能点：size 是计算属性，频繁访问会重复 IO；
    ///    且 attributesOfItem 在文件不存在时返回 nil，此处静默为 0。
    public var size: Int64 {
        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = (fileAttributes?[.size] as? Int64) ?? 0
        return fileSize
    }

    /// 流式读取文件（避免把大文件读进内存）
    /// ⚠️ 每次访问都新建 InputStream；若文件不存在返回的流打开时会失败。
    public var stream: InputStream? {
        let tempStream = InputStream(url: fileURL)
        return tempStream
    }

    public init(fileURL: URL,
                fieldName: String = "",
                fileName: String? = nil,
                mimeType: String? = nil) {
        self.fieldName = fieldName
        self.fileName = fileName
        self.mimeType = mimeType
        self.fileURL = fileURL

        // fieldName 为空时，根据文件名自动推断 fieldName / fileName / mimeType
        if fieldName.isEmpty {
            let tempFileName = fileURL.lastPathComponent
            let subs = tempFileName.components(separatedBy: ".")
            var tempFieldName = ""
            // ⚠️ 取第一个点之前的部分作为 fieldName；
            //    对 "a.b.c.png" 会得到 "a"，对 ".hidden" 会得到空串（边界情况）
            if !subs.isEmpty { tempFieldName = subs[0] }
            let tempMimeType = fileURL.pathExtension.mimeType
            self.fieldName = tempFieldName
            self.fileName = tempFileName
            self.mimeType = tempMimeType
        }
    }

    /// multipart 表单追加
    /// 有 mimeType 时带 fileName/mimeType，否则退化为无类型追加
    public func append(to multipartFormData: MultipartFormData) {
        if let type = mimeType {
            multipartFormData.append(fileURL, withName: fieldName, fileName: fileName ?? "", mimeType: type)
        } else {
            multipartFormData.append(fileURL, withName: fieldName)
        }
    }
}


// MARK: - 基于内存 Data 的上传数据

open class UploadRawData: UploadDatable {
    /// 数据大小直接取 Data.count
    public var size: Int64 {
        return Int64(data.count)
    }

    let data: Data
    public var fieldName: String
    public var fileName: String?
    public var mimeType: String?

    /// 用内存 Data 构造 InputStream
    public var stream: InputStream? {
        let tempStream = InputStream(data: data)
        return tempStream
    }

    public init(data: Data,
                fieldName: String,
                fileName: String? = nil,
                mimeType: String? = nil) {
        self.data = data
        self.fieldName = fieldName
        self.fileName = fileName
        self.mimeType = mimeType
    }

    public func append(to multipartFormData: MultipartFormData) {
        multipartFormData.append(data, withName: fieldName, fileName: fileName, mimeType: mimeType)
    }
}


// MARK: - 基于 UIImage 的上传数据

open class UploadImage: UploadDatable {
    /// 图片大小：懒压缩并缓存压缩结果
    /// ⚠️ 线程安全：imageData 是懒加载，多线程同时访问可能重复压缩/竞争，
    ///    建议加锁或改为初始化时压缩。
    public var size: Int64 {
        if imageData == nil { imageData = compressImageData() }
        return Int64(imageData?.count ?? 0)
    }

    let image: UIImage
    public var imageData: Data?
    public var fieldName: String
    public var fileName: String?
    public var mimeType: String?

    /// 流：首次访问时压缩并缓存
    public var stream: InputStream? {
        if imageData == nil { imageData = compressImageData() }
        if let tempData = imageData {
            return InputStream(data: tempData)
        }
        return nil
    }

    public init(image: UIImage,
                fieldName: String,
                fileName: String? = nil,
                mimeType: String? = nil) {
        self.image = image
        self.fieldName = fieldName
        self.fileName = fileName
        self.mimeType = mimeType
    }

    public func append(to multipartFormData: MultipartFormData) {
        if imageData == nil { imageData = compressImageData() }
        if let tempData = imageData {
            multipartFormData.append(tempData, withName: fieldName, fileName: fileName, mimeType: mimeType)
        }
    }

    /// 图片压缩策略（子类可覆写）
    /// 当前实现：调用 image.compressQuality(maxLength: 30MB)
    /// 被注释掉的旧策略：先按最大宽高 1920 缩放，再按约 400KB 质量压缩
    /// ⚠️ 30MB 上限偏大，移动端上传建议更小（如 5MB）并在后台线程压缩。
    open func compressImageData() -> Data? {
        return image.compressQuality(maxLength: 30 * 1024 * 1024)
        /* 旧实现（保留参考）：
        let whSize: CGFloat = 1920
        let dataSize = 409600
        var compressData: Data?
        if image.size.width > whSize || image.size.height > whSize {
            compressData = image.compressSizeAndQualityData(maxLength: dataSize, maxWH: whSize)
        } else if let imgData = image.jpegData(compressionQuality: 1.0), imgData.count > dataSize {
            compressData = image.compressSizeAndQualityData(maxLength: dataSize, maxWH: whSize)
        } else {
            compressData = image.jpegData(compressionQuality: 0.9)
        }
        return compressData */
    }
}


// MARK: - 文件路径 -> URL 转换

/// 让 String / URL 都能统一转成 URL 参与上传
public protocol FileURLConvertible {
    func asURL() -> URL
}

extension String: FileURLConvertible {
    public func asURL() -> URL {
        // 已是 file:// 前缀则按 URL 解析，否则当作本地路径
        if self.hasPrefix("file:"), let url = URL(string: self) {
            return url
        } else {
            return URL(fileURLWithPath: self)
        }
    }
}

extension URL: FileURLConvertible {
    public func asURL() -> URL { self }
}
