//
//  MeType.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/28.
//

import FTTool

// MARK: - 性别

/// 性别
/// - 遵循 `EnumCodable`：Int 原始值，未知值解码回退到 `defaultCase`(.unknown)
/// - ⚠️ `all = 0` 与 `unknown = 999` 并存：0 常被当作"未设置/全部"，而 unknown 才是真正的未知；
///      业务判断"性别已设置"时要注意 0 可能是"全部"而非"男性"
public enum TGenderGender: Int, EnumCodable {
    public static var defaultCase: TGenderGender = .unknown
    /// 全部(常用于筛选条件,不是某个人的真实性别)
    case all = 0
    /// 男
    case male = 1
    /// 女
    case female = 2
    /// 未知
    case unknown = 999
}


// MARK: - 登录类型

/// 登录方式/来源
public enum TLoginTypeLoginType: Int, EnumCodable {
    public static var defaultCase: TLoginTypeLoginType = .unknown
    case unknown = 0
    /// App 内登录
    case app = 1
    /// Web 登录
    case web = 2
    /// SDK 登录
    case sdk = 3
    /// PC 端登录
    case pc = 4
}


// MARK: - 角色类型

/// 账号角色类型
public enum TRoleTypeRoleType: Int, EnumCodable {
    public static var defaultCase: TRoleTypeRoleType = .unknown
    case unknown = 0
    /// 普通用户
    case normal = 1
    /// 官方用户
    case officialUser = 2
    /// AI 角色
    case aiRole = 3
    /// 客服
    case customerService = 4
}


// MARK: - AI 角色子类型

/// AI 角色的细分类型
/// - 数值不连续(0,1,12~15)，中间值被其他协议占用，**不可重排或压缩**
public enum TRoleTypeAiRoleType: Int, EnumCodable {
    public static var defaultCase: TRoleTypeAiRoleType = .none
    case none = 0
    /// 朋友型 AI
    case friend = 1
    /// 用户克隆(分身)
    case userClone = 12
    /// 用户智能体
    case userIntelligentAgent = 13
    /// AI 朋友
    case aiFriend = 14
    /// AI 管家
    case aiButler = 15
}


// MARK: - 账号类型(第三方登录/认证渠道)

/// 账号来源 / 第三方认证渠道
public enum TAccountTypeAccountType: Int, EnumCodable {
    public static var defaultCase: TAccountTypeAccountType = .unknown
    case unknown = 0
    case facebook = 1
    case yoti = 2
    case google = 3
    case apple = 4
    case weiXin = 5
    case qq = 6
    case weiBo = 7
    case email = 8
    case gome = 9
}


// MARK: - 关注关系

/// 关注关系(单向/双向)
/// - 0 无关系、1 我关注他、2 他关注我、3 互相关注
/// - 命名 norelation/following/followed/bothfollow 略不规范(应 NoRelation/bothFollow)，
///   但作为协议枚举，保持与服务端一致即可
public enum TFollowTypeFollowType: Int, EnumCodable {
    public static var defaultCase: TFollowTypeFollowType = .norelation
    case norelation = 0
    case following = 1
    case followed = 2
    case bothfollow = 3
}

extension TFollowTypeFollowType {
    /// 是否关注了别人(单向关注 + 互关都算)
    /// - ⚠️ 只覆盖"我→他"方向；若要判断"他→我"需另加 isFollowed，
    ///   判断"是否互关"需用 == .bothfollow
    public var isFollowing: Bool {
        return self == .following || self == .bothfollow
    }
}
