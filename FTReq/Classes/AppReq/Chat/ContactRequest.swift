//
//  ContactRequest.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/30.
//

import FTTool
import Alamofire

public struct ContactRequest: ApiConvertable {
    public var apiType: ContactApi
    public var hudConfig: HUDConfig?
    public init(apiType: ContactApi, hudConfig: HUDConfig? = HUDConfig(err: "")) {
        self.apiType = apiType
        self.hudConfig = hudConfig
    }
    
    public var baseURL: String {
        switch apiType {
        case .businessCard, .v1User, .userBlock, .userUnblock, .userGetBlockListByUserId, .getUserInfo, .v1Me, .verifyCodeVerify:
            return NetworkManager.shared.baseUserUrl
        case .verifyNotice, .aiOfficialFriends, .friendapplyApply, .v1FriendApplyDelete, .cleanUnreadCount, .getUserFriends, .v1FriendDelete, .friendApplyList:
            return NetworkManager.shared.aichatBaseUrl
        case .verifyCodeVerify(_):
            return NetworkManager.shared.baseUserUrl
        }
    }
    
    public var method: Alamofire.HTTPMethod {
        switch apiType {
        case .friendApplyList, .aiOfficialFriends, .getUserFriends, .v1User, .userGetBlockListByUserId, .getUserInfo, .v1Me, .verifyNotice:
            return .get
        case .v1FriendDelete, .v1FriendApplyDelete:
            return .delete
        default:
            return .post
        }
    }
    
    public var path: String {
        switch apiType {
        case .v1FriendDelete:
            return "/chat/v1/friend/deleteFriend"//"/friend/v1/friendship"
        case .v1FriendApplyDelete:
            return "/chat/v1/friend-apply/deleteApply"//"/friend/v1/apply"
        case .friendApplyList:
            return "/chat/v1/friend-apply/list"//"/friend/v1/apply/list"
        case .cleanUnreadCount:
            return "/chat/v1/friend-apply/clean/unread-count"//"/friend/v1/apply/clean/unread-count"
 
        case .aiOfficialFriends:
            return "/chat/v1/ai/own-and-official-friends"
        case .getUserFriends(let userId, _, _):
            return "/chat/v1/friend/\(userId)/friends"//"/friend/v1/friendship/\(userId)/friends"
        case .v1User:
            return "/server/v1/user"
        case .userBlock(let uid):
            return "/server/v1/user/\(uid)/block"
        case .userUnblock(let uid):
            return "/server/v1/user/\(uid)/unblock"
        case .userGetBlockListByUserId:
            return "/server/v1/user/getBlockListByUserId"
        // User
        case .getUserInfo(let userId, _):
            return "/server/v1/user/\(userId)"
        case .v1Me:
            return "/server/v1/me"

        case .friendapplyApply:
            return "/chat/v1/friend-apply/apply"//"/friend/v1/apply/apply"

        case .businessCard:
            return "/server/userCard/getBusinessCard"
        case .verifyCodeVerify:
            return "/server/v1/verifyCode/verify"
        case .verifyNotice:
            return "/chat/v1/group/join/group/verify/notice"
        }
    }
    
    public var parameters: Any? {
        switch apiType {
        case .v1FriendDelete(let friendId):
            return ["friendId": friendId]
        case let .v1FriendApplyDelete(applyUserId, beApplyUserId):
            return ["applyUserId": applyUserId, "beApplyUserId": beApplyUserId]
        case let .friendApplyList(page, size):
            return ["page": page, "size": size]

        case let .getUserFriends(_, page, size):
            return ["page": page, "size": size]
        case let .v1User(ids, fields):
            let idsSeparated = ids.map { String($0) }.joined(separator: ",")
            return ["ids": idsSeparated, "fields": fields]
        case let .getUserInfo(_, fields):
            return ["fields": fields]
        case let .v1Me(fields):
            return ["fields": fields]
 
        case let .friendapplyApply(friendID, noteName, reason, fromResourceType, fromResourceId):
            return [
                "friendId": friendID,
                "noteName": noteName,
                "reason": reason,
                "resourceType": fromResourceType,
                "resourceId": fromResourceId,
                "appType": "IOS"
            ]
 
        case let .businessCard(scn, userId):
            return ["scn": scn, "userId": userId]
        case let .verifyCodeVerify(parameter):
            return parameter
        default:
            return nil
        }
        return nil
    }
}
