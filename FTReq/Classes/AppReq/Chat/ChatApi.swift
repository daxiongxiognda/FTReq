//
//  ChatApi.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/29.
//

import FTTool

public struct Paginated {
    var page: Int64
    var size: Int64

    public init(page: Int64, size: Int64 = 500) {
        self.page = page
        self.size = size
    }
}
public enum ChatApi {

    /// 根据会话id拉取会话
    case v1Conversation(conversationIds: [String])
    
   
}

