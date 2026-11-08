# Remotive API 现状复核

Type: research
Mode: AFK
Status: resolved
Blocked by:

## Question

2026-11-06 实测 `GET https://remotive.com/api/remote-jobs?limit=1500` 只返回 **10 条**岗位；再加 `search=internship` 仍返回同一批 10 条。样本的 `job_type` 只有 `full_time`（6）、`contract`（2）、`freelance`（2），**0 个 `internship`**。这与 07 号研究里“`limit/search/category` 可用、`job_type` 可为 internship”的记录不一致，需要核实：

- `limit`、`search`、`category` 参数当前是否仍生效？10 条是默认上限、分页行为，还是 API 变更/临时降级？
- 按 `category=software-dev`、`search=ios|swift|internship` 查询时，实际返回多少条？其中 internship / 软件相关岗位各多少？
- 如果 internship 极少，Discover 的默认查询和空状态策略应怎么调整？（只影响数据源与 UI，不改 02 的匹配算法。）
- 是否需要换端点/参数，或把“手动粘贴 JD”作为 Discover 的主要兜底？

## 输出

更新 07 的数据源约束；给 04（`JobSource`/`JobRepository` 查询与缓存）和 06（排期/演示脚本）一个明确的 Discover 查询策略。不要把真实 JD 全文复制进仓库。

## Answer

日期：2026-11-08。完整证据、请求矩阵与引用见 [研究文档](../research/remotive-api-recheck.md)。

### 结论

**Remotive 公共 API 当前可观察到的行为是：每天返回同一份约 10–12 条的小样本，`limit` / `search` / `category` 实际全部无效。** 2026-11-08 的 8 次请求（无参数、`limit=5`、`limit=1500`、`search=internship`、`category=software-dev`、`search=ios`、`search=swift`、`category=software-dev&search=internship`）返回字节级完全相同的响应（同一 SHA-256，216,489 bytes）：`job-count=12`、`total-job-count=12`、`jobs.length=12`。

- **不是默认上限或分页**：官方文档写 `limit` 默认返回全部、无分页参数；`limit=5` 仍返回 12 条；`total-job-count=12`。11-06 的 10 条与 11-08 的 12 条更像每日快照大小变化，不是 limit 生效。
- **是每日缓存快照**：`last-modified: 2026-11-07 11:11:49 GMT`、`age≈23h`、`cf-cache-status: HIT`；同一天任何查询拿到同一对象。受请求预算限制未做 cache-busting，无法区分 CDN 缓存键忽略 query 与源站忽略参数，但对 App 的可观察行为相同。
- **样本构成**：`job_type` = full_time 6 / freelance 3 / contract 2 / part_time 1 / **internship 0**；category 以 Software Development 5 为主；title/tags/description 均无 internship；`ios` 仅 2 条标签堆砌命中、`swift` 仅 1 条，且都不是 iOS 岗位。
- **公开 API 只是样本层**：同一天 Remotive 首页匿名可见 13 条岗位，12 个 API id 全在其中（首页多 1 条更新的）。首页显示 “You're seeing 0.4% of available roles / Unlock 130,000+ jobs”，`0-legal-notice` 提供 $5k/mo 起的私有 API；状态页不监控 API。
- **文档与实测脱节**：官方文档（2026-11-04 更新）仍声明 `limit/search/category` 可用；README 的 `search` 搜 title+description 也无法验证。速率（≤4 次/天、>2 次/分钟会被封）、24h 延迟、署名回链/禁止转投/禁止收集邮箱等条款仍成立。
- **响应字段增补**：新增 `total-job-count`（可选，用于样本模式判断）、`company_logo_url`（可选）、顶层 `00-warning`（忽略）；本次 `job_type` 12/12 有值。

### Discover 查询策略（给 04 / 06）

- **默认查询**：无关键字、`category: "software-dev"`、数量上限 50（字段命名以最终 `JobQuery` 实现为准；category slug 当前无法验证，API 恢复后回归）。方向匹配交给本地 `MatchingEngine`；每次刷新只发一个请求，不为试参数消耗 4 次/日配额。
- **样本模式**：当 `total-job-count` 存在且很小（≤50）或返回条数明显偏少时，UI 标为“样本模式”并常驻说明“Remotive 公共 API 每日仅返回约 10–12 条样本，实习岗位很少”；条数少不是解码失败或空数据。
- **internship 稀缺**：不硬过滤、不改 02；按 02 展示并标 ineligible（eligible 在前，ineligible 分组/折叠），可加纯 UI 的“只看实习”开关。0 条 internship 时，空状态说明“今天的 Remotive 样本里没有实习岗位”，主 CTA“粘贴 JD”。
- **手动粘贴 JD**：提升为 Discover 的主要兜底，但不替换 Remotive。Remotive 保留为真实数据、外链与署名来源；手动导入继续走 `ManualJobSource` / `JobRepository.importManual`。
- **缓存与刷新**：沿用 04 的缓存优先、滚动 24h ≤4 次、60s 间隔；每日快照下 1 次/日成功刷新即可覆盖 24h 内容，4 次是上限不是目标。刷新失败/配额用完时展示缓存 + 非阻塞说明 + 粘贴 JD。
- **演示（06）**：确认“真实 Remotive 样本 + ineligible + 手动虚构 iOS 实习 JD”预案，去掉“若 internship 稀缺”的条件；不得伪造 Remotive 数据或把虚构 JD 标为 Remotive 来源。

### 边界

- 不改 `JobSource` / `JobRepository` / `RefreshOutcome` 协议；只确定默认值，并让 DTO 容忍新字段（`total-job-count` 用于样本模式判断，`company_logo_url` 可选，`00-warning` 忽略）。
- 不改 02 的匹配算法；不换数据源、不换端点。若“真实实习发现”成为硬需求，属于换源/接私有付费 API，需重开 destination，不在本 map 内决定。
- 已同步更新：[07](07-remotive-integration.md)、[04](04-architecture.md)、[06](06-schedule-demo.md) 的评论；研究资产见 [remotive-api-recheck.md](../research/remotive-api-recheck.md)。
