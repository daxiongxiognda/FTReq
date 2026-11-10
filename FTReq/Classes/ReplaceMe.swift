/*
为什么独立队列：

上传耗时长（大文件可能几分钟），不应该和普通请求抢 Alamofire 的线程池
限制并发 3：同时上传 3 个文件，避免带宽被占满、避免服务端压力
为什么用 OperationQueue 而不是 DispatchQueue：

OperationQueue 支持依赖、优先级、取消
上传任务可能需要排队、取消（用户取消上传）
*/
