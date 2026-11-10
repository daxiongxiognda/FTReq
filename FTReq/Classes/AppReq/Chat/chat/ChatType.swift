//
//  ChatType.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/28.
//

import FTTool

// MARK: - 消息内容类型

/// IM 消息内容类型(业务协议枚举)
/// - 遵循 `EnumCodable` + `Int` 原始值,未知值解码时回退到 `defaultCase`(.null)
/// - 原始值是**服务端约定的协议号**,客户端不可随意改动
/// - 辅助 `map` 提供"字符串常量 → 协议号"的映射,用于序列化/反序列化
public enum TIMMessageContentType: Int, EnumCodable {
    /// 解码失败时的兜底值
    public static var defaultCase: TIMMessageContentType = .null

    // MARK: 基础内容类型
    case unknown = -1
    case null = 0
    case text = 100               // 文本
    case image = 101              // 图片
    case voiceMessage = 102       // 语音
    case videoMessage = 103       // 视频
    case voiceChat = 104          // 语音通话
    case videoChat = 105          // 视频通话
    case personalCard = 106       // 个人卡片
    case location = 107           // 位置
    case link = 108               // 链接
    case textImage = 109
    case card = 110               // 卡片消息
    case cite = 111               // 引用
    case redPacket = 112          // 红包
    case sticker = 113            // 表情包
    case file = 117               // 文件
    case redPacketMessage = 118   // 红包消息
    case chatHistory = 119        // 聊天记录
    case patMessage = 120         // 拍一拍
    case aiPersonalCard = 121     // AI 推荐个人卡片

    // MARK: AI 相关
    case aitext = 501             // AI 文本
    case aiproduct = 502          // AI 商品
    case airedpacket = 503        // AI 红包
    case aiGroupImText = 504      // AI 群聊助手

    // MARK: 用户 / 会话变更(1xxx / 2xxx)
    case userUpdated = 1001
    case conversationUpdate = 2000

    // MARK: 好友(3xxx / 4xxx)
    case followed = 3001
    case unFollow = 3002
    case friendListChange = 4001
    case newFriend = 4002
    case strangerTalkTip = 4003
    case newFriendApply = 4004
    case newFriendJudge = 4005

    // MARK: 动态(6xxx)
    case userCollect = 6001       // 动态-收藏
    case userLike = 6002          // 动态-点赞
    case userComment = 6003       // 动态-评论
    case violationContent = 6004  // 内容违规
    case userCommentApprove = 6005 // 动态-评论-认可
    case userCommentDenied = 6006  // 动态-评论-不认可

    // MARK: 推送(7xxx)
    case pushNotification = 7000
    case pushTopic = 7001

    case signContract = 8000

    // MARK: 群操作(9xxx)
    case newGroup = 9000
    case newJoinApply = 9001
    case groupChanged = 9002
    case groupPlacardChanged = 9003
    case groupDissolve = 9004         // 群解散
    case groupQuit = 9005
    case groupKickOut = 9006
    case newMember = 9007
    case inviteJoin = 9008
    case newLeader = 9009
    case removeLeader = 9010
    case groupDissolveCommand = 9011
    case groupKickOutCommand = 9012
    case userRefuseToJoinGroup = 9013
    case groupApplyJudgeRefuse = 9014 // 用户加群申请被审核拒绝
    case groupAllMembersMuted = 9016   // 群组全员禁言
    case groupAllMembersUnMute = 9017  // 群组全员解除禁言
    case groupTransferMaster = 9018    // 群主转让
    case groupModifyName = 9019        // 修改群名称
    case groupInviteTitle = 9020       // 群中群邀请系统消息
    case groupShareNewProductNum = 9021 // 群中群推荐商品未读数量
    case contractGuideMessage = 9022    // 合约指南消息
    case contractDetailMeasage = 9023   // 合约详情消息(⚠️ 拼写 Measage)
    case joinGroupVerifyCommand = 9024  // 加群验证指令
    case adXiaohujiCard = 9025          // 小虎机
    case adChuanshanjiaCard = 9026      // 穿山甲
    case loudspeakerNotice = 9027       // 群喇叭
    case groupInviteNotFriend = 9028    // 群邀请非好友系统提示
    case groupSnowHideNotice = 9029     // 群 - 雪藏群

    // MARK: 奖励 / 活动
    case reward = 10000
    case groupActivity = 11000
    case scrambleRedPacket = 12000
    case scrambleRedPacketV2 = 12001

    // MARK: 拉黑(13xxx)
    case blockUser = 13000
    case unblockUser = 13001

    // MARK: AI 助手(14xxx)
    case aiSelectMessage = 14000
    case aiException = 14001
    case helpReplyMessage = 14002
    case firstSentenceAssistant = 14003
    case digitalPeople = 14004

    // MARK: 群通话(15xxx)
    case groupNewCall = 15000
    case groupCallEnd = 15001
    case callEndCommand = 15002
    case newCallCommand = 15003
    case userCloseCallCommand = 15004
    case userJoinCallCommand = 15005
    case groupCallChangeCommand = 15006
    case groupCallNoAnswered = 15007

    // MARK: 商家 / 订单 / 地皮 / 经营证(16xxx)
    case merchantsSettleIn = 16000        // 商家入驻信息
    case goodsOrderExpiringSoon = 16001   // 商品-订单
    case land = 16002                     // 地皮
    case license = 16004                  // 经营证

    case generalTips = 18001              // 系统消息通用提示

    // MARK: 群签到 / 接龙
    case groupCheckIn = 20000             // 群签到
    case dragonChain = 123                // 群接龙(⚠️ 123 与本组 2xxxx 不连续,孤立值)

    // MARK: 公会 / 语音房
    case guildJoinDetail = 30000          // 公会入驻成功/失败/封禁通知
    case userWarning = 10014              // 语音房超管警告用户
    case userBan = 10015                  // 语音房封禁用户
    case welcomeGroup = 41001

    /// 字符串常量 → 协议号 的映射表
    /// 用途:序列化时把枚举/字符串写为协议号;反序列化时按字符串还原
    /// ⚠️ 维护风险:
    ///   1. 必须与上面的 case 一一对应,新增 case 忘记加 map → 该类型无法序列化
    ///   2. 值重复 case 时,以 map 为准,容易与枚举定义不一致(见下方核对)
    ///   3. 多处拼写不规范(COMMAND/MEASAGE/SCRAMBLE 等),跨端对接需以服务端为准
    public static var map: [String: Int]? {
        [
            "NULL": 0,
            "UNKNOWN": -1,
            "TEXT": 100,
            "IMAGE": 101,
            "VOICE": 102,
            "VIDEO": 103,
            "VOICE_CHAT_RECORD": 104,
            "VIDEO_CHAT_RECORD": 105,
            "PERSONAL_CARD": 106,
            "LOCATION": 107,
            "LINK": 108,
            "TEXT_IMAGE": 109,
            "CARD": 110,
            "CITE": 111,
            "RED_PACKET": 112,
            "EMOJIS": 113,
            "FILE": 117,
            "RED_PACKET_V2": 118,
            "CHAT_RECORD": 119,
            "CLAP": 120,
            "MATCHMAKER_CARD": 121,
            "AI_TEXT": 501,
            "AI_PRODUCT": 502,
            "AI_RED_PACKET": 503,
            "AI_GROUP_ASSISTANT": 504,
            "USER_UPDATED": 1001,
            "CONVERSATION_UPDATE": 2000,
            "FOLLOWED": 3001,
            "UN_FOLLOW": 3002,
            "FRIEND_LIST_CHANGE": 4001,
            "NEW_FRIEND": 4002,
            "STRANGER_TALK_TIP": 4003,
            "NEW_FRIEND_APPLY": 4004,
            "NEW_FRIEND_JUDGE": 4005,
            "USER_COLLECT": 6001,
            "USER_LIKE": 6002,
            "USER_COMMENT": 6003,
            "USER_UGC_AUDIT": 6004,
            "USER_COMMENT_LIKE": 6005,
            "USER_COMMENT_DISLIKE": 6006,
            "PUSH_NOTIFICATION": 7000,
            "PUSH_TOPIC": 7001,
            "SIGN_CONTRACT": 8000,
            "NEW_GROUP": 9000,
            "NEW_JOIN_APPLY": 9001,
            "GROUP_CHANGED": 9002,
            "GROUP_PLACARD_CHANGED": 9003,
            "GROUP_DISSOLVE": 9004,
            "GROUP_QUIT": 9005,
            "GROUP_KICK_OUT": 9006,
            "NEW_MEMBER": 9007,
            "INVITE_JOIN": 9008,
            "NEW_LEADER": 9009,
            "REMOVE_LEADER": 9010,
            "GROUP_DISSOLVE_COMMAND": 9011,
            "GROUP_KICK_OUT_COMMAND": 9012,
            "USER_REFUSE_TO_JOIN_GROUP": 9013,
            "GROUP_APPLY_JUDGE_REFUSE": 9014,
            "GROUP_ALL_MEMBERS_MUTED": 9016,
            "GROUP_ALL_MEMBERS_UN_MUTE": 9017,
            "GROUP_TRANSFER_MASTER": 9018,
            "GROUP_MODIFY_NAME": 9019,
            "GROUP_INVITE_TITLE": 9020,
            "GROUP_SHARE_NEW_PRODUCT_NUM": 9021,
            "CONTRACT_GUIDE_MESSAGE": 9022,
            "CONTRACT_DETAIL_MEASAGE": 9023,   // 注意拼写
            "JOIN_GROUP_VERIFY_COMMAND": 9024,
            "AD_XIAOHUJI_CARD": 9025,
            "AD_CHUANSHANJIA_CARD": 9026,
            "LOUDSPEAKER_NOTICE": 9027,
            "GROUP_INVITE_NOT_FRIEND": 9028,
            "REWARD": 10000,
            "GROUP_ACTIVITY": 11000,
            "SCRAMBLE_RED_PACKET": 12000,      // 注意 SCRAMBLE 拼写
            "SCRAMBLE_RED_PACKET_V2": 12001,   // 注意 RED_PACKET 拼写
            "BLOCK_USER": 13000,
            "UNBLOCK_USER": 13001,
            "AI_SELECT_MESSAGE": 14000,
            "AI_EXCEPTION": 14001,
            "HELP_REPLY_MESSAGE": 14002,
            "FIRST_SENTENCE_ASSISTANT": 14003,
            "DIGITAL_PEOPLE": 14004,
            "GROUP_NEW_CALL": 15000,
            "GROUP_CALL_END": 15001,
            "CALL_END_COMMAND": 15002,         // 注意 COMMAND 拼写
            "NEW_CALL_COMMAND": 15003,
            "USER_CLOSE_CALL_COMMAND": 15004,
            "USER_JOIN_CALL_COMMAND": 15005,
            "GROUP_CALL_CHANGE_COMMAND": 15006,
            "GROUP_CALL_NO_ANSWERED": 15007,
            "NEW_MERCHANT_ENTRY_NOTICE": 16000,
            "CHANNEL_ORDER_SEND_MESSAGE": 16001,
            "SELL_LAND_NOTICE": 16002,
            "RENT_LICENSE_NOTICE": 16004,
            "SYSTEM_SEND_TEXT": 18001,
            "GROUP_CHECK_IN": 20000,           // 群签到
            "DRAGON_CHAIN": 123,               // 群接龙
            "GUILDJOIN_DETAIL": 30000,         // 公会入驻
            "USER_WARNING": 10014,             // 语音房警告
            "USER_BAN": 10015,                 // 封禁用户
            "WELCOME_GROUP": 41001
        ]
    }
}

// MARK: - 卡片消息子类型

/// 卡片消息的卡片类型(用于 110 卡片消息内部区分)
public enum TIMMessageContentCardType: Int, EnumCodable {
    public static var defaultCase: TIMMessageContentCardType = .nullCard
    case nullCard = 0
    case groupInvite = 110100          // 群邀请
    case shareMoment = 110200          // 动态分享
    case locationMoment = 110201       // 位置动态
    case shareActiity = 110202         // 活动分享(⚠️ 拼写 Actiity)
    case shareLand = 110203            // 地皮分享
    case shareLicense = 110204         // 经营证分享
    case shareLocationDetail = 110206  // 地址详情分享
    case shareLocalLife = 110207       // 本地生活分享
    case shareProduct = 110208         // 爆品分享
    case shareMallProduct = 110209     // 商城商品分享
    case shareNtfDipiassets = 110210   // NFT 资产分享
    case imageText = 110211            // 图文
    case shareRoom = 110212            // 直播间分享
    case sharePlaylet = 110213         // 短剧分享
    case shareAiactive = 110214        // AI 激活
    case shareAibody = 110215          // AI 分身分享
    case smallApp = 110216             // 小 app
    case shareAiproduct = 110217       // AI 商品分享
    case sharePlay = 110219            // 拼玩活动
    case shareLandInvite = 110220      // 地皮分享邀请卡片
    case groupInviteGroup = 110221     // 群中群邀请
    case shareAimessage = 110222       // AI 分身聊天记录分享
    case shareSlot = 110223            // 小虎机活动
    case shareExploreServiceProduct = 110224 // 探索器服务商品分享
    case shareMiniproduct = 110225     // 小 app 商品分享
    case sharePersonalAi = 110226      // 个人 AI 名片分享
    case shareGroupAi = 110227         // 群组 AI 名片分享
    case groupAddGroupApply = 110228   // 群加群申请
    case shareEnterpriseAiBusinessCard = 110229 // 企业 AI 名片
    case addFunFroupCard = 110230      // 加入粉丝群(⚠️ 拼写 Froup)
    case addStarUnionGroup = 110231    // 加入星空联盟
    case freeTrialEvent = 110232       // 0 元试用活动
    case priorityReturnGoods = 110233  // 顺位返商品
    case ipSquareShare = 110234        // ip 广场分享
}

// MARK: - 好友关系

public enum TFriendRelationTypeFriendRelationType: Int, EnumCodable {
    public static var defaultCase: TFriendRelationTypeFriendRelationType = .norelation
    case norelation = 0
    case apply = 1
    case friend = 2
}

// MARK: - 消息检查结果

public enum TCheckResultCheckResult: Int, EnumCodable {
    public static var defaultCase: TCheckResultCheckResult = .success
    case success = 0
    case forbiddenWord = 1   // 命中敏感词
    case processing = 2      // 审核中
}

// MARK: - 群成员类型

public enum TGroupMemberTypeGroupMemberType: Int, EnumCodable {
    public static var defaultCase: TGroupMemberTypeGroupMemberType = .unknowntype
    case unknowntype = 0
    case master = 1
    case leader = 2
    case member = 3
    case unknown = 1000
}

// MARK: - 会话状态

public enum TConversationStatusE: Int, EnumCodable {
    public static var defaultCase: TConversationStatusE = .unknown
    case unknown = 0
    case normal = 1
    case hide = 2
    case delete = 3
    case quit = 4
}

// MARK: - 会话类型

public enum TConversationTypeE: Int, EnumCodable {
    public static var defaultCase: TConversationTypeE = .null
    case null = 0
    case `private` = 1
    case group = 2
}

// MARK: - 会话列表类型

public enum TConversationListTypeE: Int, EnumCodable {
    public static var defaultCase: TConversationListTypeE = .null
    case null = 0
    case normal = 1
    case stick = 2
    case notification = 4
}
