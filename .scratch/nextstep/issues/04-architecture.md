# 混合架构与 JobSource 抽象

Type: grilling
Mode: HITL
Status: open
Blocked by: 02, 03

## Question

MVVM / MVC 在 NextStep 里具体怎么落？

- 哪些 SwiftUI 页面用 MVVM，哪个 UIKit 页面用 MVC（用真实页面举例）。
- 分层：View / ViewModel / Domain / Data；模块边界和依赖方向。
- `JobSource` 协议：`RemotiveJobSource`、`ManualJobSource`、未来的 `URLSource`；如何统一成 `JobPosting`。
- `JobRepository`：SwiftData 缓存、刷新节流（每天 ≤4 次）、错误处理、离线读取。
- 依赖注入与可测试性：`MatchingEngine` 如何做成纯函数/纯模块。
- 哪些决策值得写 ADR。
