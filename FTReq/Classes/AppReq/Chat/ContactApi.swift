//
//  ContactApi.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/30.
//

import FTTool

public enum ContactApi {
    /**
     删除好友
     - Returns: nil
     */
    case v1FriendDelete(friendId: Int64)
    /// 删除好友申请
    case v1FriendApplyDelete(applyUserId: Int64, beApplyUserId: Int64)
    /// 获取好友申请列表
    case friendApplyList(page: Int, size: Int)
    /// 清空联系人未读数
    case cleanUnreadCount

    /// 获取AI好友列表
    case aiOfficialFriends
    /// 获取该用户的好友列表
    case getUserFriends(userId: Int64, page: Int, size: Int)
    
    /// 根据fields，批量获取用户信息
    case v1User(ids: [Int64], fields: String)
    /// 用户拉黑
    case userBlock(uid: Int64)
    /// 解除拉黑
    case userUnblock(uid: Int64)
    /// 获取用户黑名单
    case userGetBlockListByUserId
    /// 获取用户信息
    case getUserInfo(userId: Int64, fields: String? = nil)
    
    /// 我
    case v1Me(fields: String)
    
    case friendapplyApply(friendID: Int64, noteName: String, reason: String, fromResourceType: Int, fromResourceId: String)

    /// 获取用户商业卡片 scn: 场景码，SCN_001 查询自己  SCN_002 查询别人信息
    case businessCard(scn: String, userId: Int64)
    
    // 验证验证码
    case verifyCodeVerify([String: Any])
    // 加群验证提醒小红点
    case verifyNotice
}


