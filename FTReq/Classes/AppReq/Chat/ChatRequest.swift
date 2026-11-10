//
//  ChatRequest.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/29.
//

import FTTool
import FTReq
import Alamofire

public struct ChatRequest: ApiConvertable {
    public var apiType: ChatApi
    public var hudConfig: HUDConfig?
    public init(apiType: ChatApi, hudConfig: HUDConfig? = HUDConfig(err: "")) {
        self.apiType = apiType
        self.hudConfig = hudConfig
    }
    
    public var baseURL: String {
        switch apiType {
   
        case .v1Conversation:
            return NetworkManager.shared.aichatBaseUrl
        }
    }
    
    public var method: Alamofire.HTTPMethod {
        switch apiType {
        case .v1Conversation:
            return .get
  
        default:
            return .post
        }
    }
    
    public var path: String {
        switch apiType {

        case .v1Conversation:
            return "/chat/v1/conversation"
      
        }
    }
    
    public var parameters: Any? {
        switch apiType {

        case .v1Conversation(let conversationIds):
            return ["ids": conversationIds.joined(separator: ",")]
        
        default:
            return nil
        }
        return nil
    }
    
    public var timeout: TimeInterval {
        switch apiType {
 
        default:
            return 20
        }
    }
}

