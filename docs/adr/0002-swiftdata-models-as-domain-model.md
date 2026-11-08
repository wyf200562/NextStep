# SwiftData @Model 兼作领域模型，MatchingEngine 保持纯计算

v1 的 5 个 `@Model` 类（Application、JobPosting、InterviewRound、StatusChange、UserProfile）同时就是领域模型，不另建一套值类型 DTO；`MatchingEngine` 直接接收 `UserProfile` / `JobPosting` 实例，但不持有 `ModelContext`、不做 I/O、不持久化，仍是确定性的纯计算模块。这样避免 30 天里维护两层模型和映射代码；代价是 Domain 层 `import SwiftData`，但仅限 `@Model` 声明，不 `import SwiftUI`。

## Considered Options

- Domain 层用纯值类型 + Data 层单独 `@Model` + 双向映射。被否：映射和同步成本高，v1 的模型字段还会频繁调整。
- 让 `MatchingEngine` 接收独立的匹配输入结构体。被否：02/03 已定签名，多一层映射不划算。

## Consequences

- `MatchingEngine` 的单元测试直接构造 `@Model` 实例，不需要 `ModelContainer`。
- 如果未来要脱离 SwiftData，需要先引入值类型快照。
- Domain 目录可以依赖 SwiftData 的模型宏，但不能依赖 SwiftUI 或持久化容器。
