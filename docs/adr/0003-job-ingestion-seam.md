# 岗位摄入：统一 JobSource、JobPostingDraft 与 JobRepository 唯一写入口

所有岗位来源（Remotive、手动粘贴、未来的 URL 导入）都实现同一个 `JobSource` 协议，`loadJobs()` 返回非持久化的 `JobPostingDraft`；`JobRepository` 按 `identityKey` upsert 成 `JobPosting`，是唯一的持久化写入口，并集中负责缓存、刷新节流和离线降级。这样来源只关心“取数 + 归一化”，Repository 只关心“存 + 节流 + 错误”，匹配和 UI 不直接碰来源。

## Considered Options

- 把手动粘贴拆成 `ManualJobImporter`，只让远程源实现 `JobSource`。语义更纯，但入口分裂，和“所有来源统一”的目标冲突。
- 让 `JobSource` 直接返回 SwiftData `JobPosting`。被否：网络解码和持久化耦合，难测试，也绕过 Repository 的 upsert/节流。
- 在协议方法里传入 `JobQuery`。被否：手动/URL 来源用不到，会留下无意义参数；查询在 source 初始化时注入更干净。

## Consequences

- 手动来源通过 `JobSourceFactory` 按输入创建；协议统一为 `async throws`，即使手动实现是同步的。
- 刷新配额按来源维护，未来 URL 源不会和 Remotive 共用 4 次/天。
- 来源不删除旧岗位；`JobRepository` 只 upsert，不做自动淘汰。
