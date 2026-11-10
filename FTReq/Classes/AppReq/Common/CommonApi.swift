//
//  CommonApi.swift
//  FTReq
//
//  Created by 熊坤鹏 on 2026/10/29.
//

import FTTool

// MARK: - 通用接口

/// 通用接口（与具体业务无关的基础接口）
public enum CommonApi {

    /// 活动标签（系统字典查询）
    /// - 参数 keywords：搜索关键词，用于过滤字典项
    case sysDictList(keywords: String)

    /// 刷新token
    case refreshToken(refreshToken: String)
    
    /// 接口请求路径
    public var reqPath: String {
        switch self {
        case .sysDictList:
            return "/basic/sysDict/list"
        case .refreshToken:
            return "/server/v1/auth/refresh/token"
            
        }
    }
}

