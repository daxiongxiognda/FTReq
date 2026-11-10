//
//  FTChatNotifName.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/30.
//

import Foundation

/// 聊天模块通知名
/// - 枚举用 String 原始值定义通知名
/// - 通过 `TTNotificationNameProvider` 扩展把 rawValue 转成 `Notification.Name`
///
/// ⚠️ 本文件的 rawValue 命名风格非常不统一，存在多种前缀/大小写/格式并存：
///   - "TTChat.NotificationName.xxx"（驼峰点分）
///   - "NotificationNameXxx"（驼峰无点）
///   - "NotificationName.TTChat.xxx"（点分混合）
///   - "chatListXxx" / "xtt.xyz.tongtong.xxx" / "NSNotification.xxx" 等
///   长期维护建议统一成一种前缀规范（如 `com.xtt.chat.` + 短名），
///   但改动需同步所有监听方，成本高，需评估。
public enum FTChatNotifName: String {

    // MARK: - 会话列表

    /// 刷新外部 IM 列表
    case reloadConversationList = "TTChat.NotificationName.ReloadConversationList"
    /// 语音播放完刷新下一条语音消息
    case playVoice = "NotificationNamePlayVoice"
    /// 隐藏小红点
    case hiddenBadge = "NotificationNameHiddenBadge"
    /// 下一条是未读语音时自动播放
    case playNextVoice = "NotificationNameIMAutomaticPlayNextVoice"
    /// 发送通知给群聊横幅（群申请数顶部数据更新）
    case chatGroupApplyCountTopDataUpdate = "TTIMChatGroupApplyCountTopDataUpdateNotificationKey"
    /// 列表展示"更多未读"提示
    case chatListShowMoreUnreadTips = "ChatListShowMoreUnreadTipsNotification"
    /// 列表滚动到未读顶部
    case chatListScrollToUnreadTop = "ChatListScrollToUnreadTopNotification"
    /// 列表滚动到未读底部
    case chatListScrollToUnreadBottom = "ChatListScrollToUnreadBottomNotification"
    /// 列表滚动到 @ 消息
    case chatListScrollToUnreadAtMessage = "ChatListScrollToUnreadATNotification"
    /// @ 消息被滑过，清除 @ 序列
    case chatListRemoveUnreadAtMessage = "chatListRemoveUnreadAtMessage"
    /// unity 界面的未读数字
    case chatListShowUnityUnreadTips = "chatListShowUnityUnreadTipsNotification"
    /// 清空所有消息
    case clearAllMsgs = "xtt.xyz.tongtong.clearAllMsgs"
    /// 更新聊天背景图
    case updateBackgroundImage = "NotificationNameTTUpdateBackgroundImage"
    /// 私聊顶部信息 view 回收（展开时滚动触发）
    case switchThem = "IMChatMsg.switchThem"
    /// 上传头像成功
    case uploadAvatarSuccess = "kGUIDE_UPLOAD_AVATAR_SUCCESS"

    // MARK: - 表情管理

    /// 表情管理新增
    case emotIconMangerAdd = "TTChat.NotificationName.EmotIconMangerAdd"
    /// 表情管理删除
    case emotIconMangerDelete = "TTChat.NotificationName.EmotIconMangerDelete"

    // MARK: - 录音

    /// 开始录音
    case startAudioRecord = "StartAudioRecordNotification"
    /// 结束录音
    case endAudioRecord = "EndAudioRecordNotification"
    /// 录音按钮长按（旧）
    case recordButtonLongPress2 = "NSNotification.recordButtonLongPress"
    /// 录音按钮长按（新）
    case chatRecordButtonLongPress = "NotificationName.TTChat.recordButtonLongPress"
    /// 处理音频数据（分贝）
    case soundDecibel = "soundDecibel"

    // MARK: - 群信息 / 未读

    /// 群信息更新
    case groupUpdateInfo = "NotificationNameTTChatGroupUpdateInfo"
    /// 未读数变化
    case unreadBadgeChanged = "unreadBadgeChanged"
    /// AI 管家未读数变化
    case aiButlerUnreadBadgeChanged = "aiButlerUnreadBadgeChanged"
    /// NFT 消息总数
    case nftMessageTotalCount = "NFT_TTUnreadMessageTotalCount"
    /// 双击底部按钮列表滚动后通知刷新 blurView
    case tableScrollView = "IMChatTableScrollView"

    // MARK: - 会话操作成功

    /// 免打扰设置成功
    case conversationMuteSuccess = "NotificationName.TTChat.MuteSuccess"
    /// 修改备注成功
    case conversationRemarkSuccess = "NotificationName.TTChat.RemarkSuccess"
    /// 群公开成功
    case conversationGroupPublicSuccess = "NotificationName.TTChat.GroupPublicSuccess"
    /// 退出群聊成功
    case conversationGroupLeaveSuccess = "NotificationName.TTChat.GroupLeaveSuccess"
    /// 新用户信息更新
    case chatNewUserInfoUpdate = "NotificationName.TTChat.TTChatNewUserInfoUpdate"
    /// 红包状态变化
    case redPacketStateChange = "TTChat.NotificationName.TTRedPacketStateChange"

    // MARK: - 聊天消息

    /// 首次进入群组后拉取消息
    case enterNewConversationPullMsgs = "TTChat.NotificationName.TTEnterNewConversationPullMsgs"
    /// 长按消息
    case chatMessageLongPressAction = "TTChat.NotificationName.TTChatMessageLongPressAction"
    /// 删除消息
    case chatMessageDeleteAction = "TTChat.NotificationName.TTChatMessageDeleteAction"
    /// 音频输出端口（扬声器/听筒）切换
    case chatOutputAudioPortChange = "TTChat.NotificationName.TTChatAudioOutputAudioPortChange"
    /// 聊天加密密码
    case chatConversationSecertPassword = "TTChat.NotificationName.TTChatConversationSecertPassword"
    /// 收起底部输入框
    case chatHiddenChatInput = "TTChat.NotificationName.HiddenChatInput"
    /// 更新多选底部按钮状态
    case chatUpdateSelect = "TTChat.NotificationName.UpdateSelect"
    /// 开始多选编辑
    case chatMsgBeginEdit = "TTChat.NotificationName.chatMsgBeginEdit"
    /// 删除多选消息
    case chatDeleMutiMsgs = "TTChat.NotificationName.DeleMutiMsgs"
    /// 多选转发消息
    case chatMultiForwardMsgs = "TTChat.NotificationName.MultiForardMsgs"
    /// 群组取消拉黑
    case chatGroupUnBlock = "TTChat.NotificationName.Group.Manager.UnBlock"
    /// 群解散
    case chatGroupDissolve = "TTChat.NotificationName.groupDissolve"
    /// 被踢出群
    case chatGroupKickOut = "TTChat.NotificationName.groupKickOut"
    /// 首页来源
    case chatHomePageSource = "TTChat.NotificationName.homePageSource"
    /// 开始录音
    case chatAuidoRecorderStart = "xyz.xtt.TTChatAuidoRecorderStart"
    /// IM 群组变化刷新成功
    case chatIMGroupReloadSuccess = "NotificationName.TTChat.IMGroupReloadSuccess"
    /// 红包卡片打开
    case chatOpenRedPacketCard = "TTChat.NotificationName.TTChatOpenRedPacketCard"
    /// 文件下载并保存成功
    case fileDownLoadDidComplete = "NotificationName.FileDownLoadDidComplete"

    // MARK: - 群信息更新

    /// 更改群头像、名称、本群昵称
    case conversationGroupInfoUpdate = "NotificationName.TTChat.GroupInfoUpdate"
    /// 取消编辑（旧）
    case imChatMsgcancelEdit = "IMChatMsg.cancelEdit"
    /// 结束多选编辑（新）
    case chatMsgCancelEdit = "TTChat.NotificationName.UpdateCancelEdit"
    /// 去经营群数据看板
    case gotoOperateGroupData = "TTChat.NotificationName.gotoOperateGroupData"
    /// 群主转让后 toast 提示
    case groupTransferMasterToast = "TTChat.NotificationName.groupTransferMasterToast"
    /// 显示二楼
    case tongtongVCshowSecondFloor = "TTChat.NotificationName.showSecondFloor"
    /// 跳转通通 VC
    case jumpeTotongtongVC = "TTChat.NotificationName.jumpeTotongtongVC"
    /// 权益气泡数据更新，刷新可见 cell
    case chatRightsBubbleUpdate = "TTChat.NotificationName.chatRightsBubbleUpdate"
    /// 聊天首页群列表 tab 配置更新
    case chatHomeGroupListTabConfigUpdate = "TTChat.NotificationName.chatHomeGroupListTabConfigUpdate"
}

extension FTChatNotifName: FTNotificationNameProvider {
    /// 通知名：直接用 rawValue
    /// - 因为 rawValue 本身已带各种前缀（虽不统一），这里不再额外加前缀
    public var name: Notification.Name {
        Notification.Name(rawValue)
    }
}
