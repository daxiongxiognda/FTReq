//
//  GroupApi.swift
//  Alamofire
//
//  Created by 熊坤鹏 on 2026/10/29.
//

import FTTool

/// 群相关接口
/// - 每个 case 对应一个后端接口
/// - 注释中的 "Returns:" 声明该接口响应体的解析类型，用于调用方参考
/// - ⚠️ 注释与实现的一致性需要维护：新增/修改接口时若忘记改注释，容易误导调用方
public enum GroupApi {
    /// 根据 id 与 fields 拉取群信息
    /// ⚠️ fields 是 String（逗号分隔？），调用方需明确格式
    case v2Group(ids: [String], fields: String)

  

}
