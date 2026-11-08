# 混合架构与 JobSource 抽象

Type: grilling
Mode: HITL
Status: resolved
Blocked by: 02, 03

## Question

MVVM / MVC 在 NextStep 里具体怎么落？

- 哪些 SwiftUI 页面用 MVVM，哪个 UIKit 页面用 MVC（用真实页面举例）。
- 分层：View / ViewModel / Domain / Data；模块边界和依赖方向。
- `JobSource` 协议：`RemotiveJobSource`、`ManualJobSource`、未来的 `URLSource`；如何统一成 `JobPosting`。
- `JobRepository`：SwiftData 缓存、刷新节流（每天 ≤4 次）、错误处理、离线读取。
- 依赖注入与可测试性：`MatchingEngine` 如何做成纯函数/纯模块。
- 哪些决策值得写 ADR。

## Answer

日期：2026-11-08。术语已同步到 `GLOSSARY.md`；架构决策见 `docs/adr/0001`–`0004`。

### 1. 架构总览

- **单 app target + 文件夹分层**，不拆 SPM 模块、不引第三方依赖；新增 `NextStepTests` 单元测试 target（Swift Testing）。
- 依赖方向：**Features → Domain ← Data**；`App` 负责组合根；`Domain` 不依赖 Features/Data/App；`Domain` 允许 `import SwiftData`（仅 `@Model` 声明），不 `import SwiftUI`。
- 目录结构：

```text
NextStep/
  App/          NextStepApp、AppContainer、RootTabView
  Features/     Overview、Applications、ApplicationDetail、StatusHistory、
                Discover、JobDetail、Profile、ManualImport
  Domain/
    Models/             Application、JobPosting、InterviewRound、StatusChange、UserProfile
    ApplicationStatus.swift / ApplicationStateMachine.swift
    Matching/           MatchingEngine、MatchResult、SkillDictionary、MatchService
    JobSource.swift / JobPostingDraft.swift / JobQuery.swift
    Repositories/       JobRepository、ApplicationRepository、UserProfileRepository（协议）
    NotificationScheduling.swift
  Data/
    Persistence/        SchemaV1、ModelContainerFactory
    Repositories/       SwiftDataJobRepository、SwiftDataApplicationRepository、
                        SwiftDataUserProfileRepository
    Sources/            RemotiveJobSource、RemotiveDTO、ManualJobSource、
                        JobSourceFactory、URLJobSource（P1 预留）
    Matching/           SkillDictionaryLoader
    Throttling/         RefreshLedger
    Notifications/      UserNotificationScheduler
  Core/         LoadState、DateProvider、HTMLTextNormalizer、格式化、设计 token
NextStepTests/  DomainTests、DataTests、FeatureTests
```

- 各层职责：
  - **View**：布局与绑定；只读列表可直接 `@Query`；不写业务逻辑、不直接写 SwiftData。
  - **ViewModel**：`@Observable @MainActor`，持有 `LoadState`、用户意图和错误映射；只依赖协议。
  - **Domain**：5 个 `@Model`、状态机、匹配、来源/仓库协议、值类型。
  - **Data**：SwiftData repository、远程来源、词典加载、刷新账本、通知实现。
  - **Core**：无业务依赖的通用工具与设计 token。
- 测试 target 第一天就加；SwiftData 用 in-memory container；不做 UI test target。

### 2. 表现层：MVVM / MVC 的落点

**规则**：

- 有异步加载、错误态、表单校验或多步操作的页面 → MVVM。
- 只读列表/派生展示 → View 直接用 `@Query` + 纯函数 builder，不硬塞 VM。
- 所有写操作走 Repository/ViewModel；ViewModel 不持有 `ModelContext`，不直接用 `@Query`。

| 页面 | 形态 |
|---|---|
| 概览 | `@Query` + 纯 `DashboardBuilder`，无 VM |
| 申请列表 | `@Query` + `@State` 筛选/排序，无 VM |
| 申请详情 | `ApplicationDetailViewModel`：状态流转、轮次、截止、错误 |
| 申请新建/编辑 | `ApplicationEditorViewModel`：校验、保存、快照字段 |
| 发现列表 | `DiscoverViewModel`：缓存、刷新、节流、匹配、错误 |
| 岗位详情 | `JobDetailViewModel`：匹配、导入、来源署名 |
| 用户画像 | `ProfileViewModel`：表单、技能选择、校验 |
| 手动粘贴 JD | `ManualImportViewModel`：校验、预览、保存 |
| 状态历史 | UIKit MVC，无 VM |
| 根容器 | 无 VM |

- VM 统一：`@Observable @MainActor final class`；依赖从 `init` 注入；暴露意图方法和状态；视图用 `@State` 持有，表单用 `@Bindable`。
- 概览的「今天 / 接下来 7 天 / 三个计数 / 最近更新」由纯 `DashboardBuilder` 从 `Application`、`InterviewRound` 派生，不落库。
- 导航：每个 tab 独立 `NavigationStack` + typed destination；路由枚举细节留实现。RootTabView 的 tab 数量和 Discover/Profile 入口沿用 08 与后续 UI 决策，本 ticket 不新增 IA。

**UIKit / MVC 页面**：申请详情的「状态历史」。

- `StatusHistoryViewController`：持有 table view、data source/delegate；注入 `ApplicationRepository` + `applicationID`；`viewDidLoad` 取 `StatusChange`（`changedAt` 降序），处理空/错，负责 Done/关闭。
- `UITableViewDiffableDataSource` + `StatusHistoryCell`；cell 只负责展示；格式化用纯 helper。**没有 ViewModel**。
- 从 SwiftUI 以 sheet 打开，内部套 `UINavigationController`，避免与 SwiftUI `NavigationStack` 的导航栏冲突。
- 替代方案（Discover 网格、申请详情整页 UIKit）不采用；理由见 ADR-0004。

### 3. 岗位摄入：JobSource / JobPostingDraft / JobRepository

**统一协议**（按讨论：所有来源都 conform，不再拆 `ManualJobImporter`）：

```swift
protocol JobSource: Sendable {
    var intakeMethod: JobIntakeMethod { get }
    /// 所有来源的统一入口：返回归一化后的草稿。
    func loadJobs() async throws -> [JobPostingDraft]
}

struct JobSourceFactory: Sendable {
    var makeRemote: @Sendable (JobQuery) -> any JobSource
    var makeManual: @Sendable (ManualJobInput) -> any JobSource
}
```

- `RemotiveJobSource(query:session:)`、`ManualJobSource(input:)`、未来的 `URLJobSource(url:session:)` 各自在初始化时拿输入，只实现自己的 `loadJobs()`。
- 共同逻辑放协议扩展/共享 helper：`makeDraft(...)`（trim、HTML→纯文本、日期解析、生成 `identityKey`）、`normalizeDescription(...)`；来源特有逻辑各自实现。
- `ManualJobSource.loadJobs()` 同步返回一条 draft；输入不合法抛 `JobSourceError.invalidInput`；协议统一 `async throws`，调用方不区分来源。
- `JobQuery` 只被远程源使用；manual/URL 的输入在 source 初始化时给出。

**`JobPostingDraft`**：非持久化值类型，字段与 03 的 `JobPosting` 必填/可选对齐，去掉 `createdAt` 和关系；`identityKey` 由来源生成：`remotive:<id>` / `manual:<uuid>`。归一化（HTML→纯文本、日期、trim）在来源侧完成，Repository 只信任 draft。

**`JobRepository`**：唯一写入口。`refreshDiscover(query:)` 用 `factory.makeRemote(query:)`；`importManual(_:)` 用 `factory.makeManual(input:)`；两者都走 `upsert(drafts:)`。UI、匹配不直接碰来源。

### 4. JobRepository：节流、缓存、错误与离线

**职责与接口**（`@MainActor`，协议 + SwiftData 实现）：

```swift
protocol JobRepository: AnyObject {
    func cachedJobs() throws -> [JobPosting]
    func refreshDiscover(query: JobQuery) async -> RefreshOutcome
    func importManual(_ input: ManualJobInput) async throws -> JobPosting
    func lastRefreshAt(for source: JobIntakeMethod) -> Date?
}
```

**刷新节流**：

- 按来源维护 `RefreshLedger`（未来 URL 源有独立配额）；滚动 24 小时最多 4 次**网络尝试**（成功、失败、解码失败都算；离线也算，保守）；比自然日更严格。
- 两次尝试至少间隔 60 秒；ledger 持久化到 UserDefaults；手动导入不计。
- 自动刷新：Discover 首次出现时 `refreshIfNeeded`，TTL 6 小时（以最近一次成功刷新为准）；下拉刷新走 `refresh`；配额用完或太频繁时返回 `.skipped`，UI 显示缓存 + “刷新次数已用完/稍后再试” + 上次更新时间；不做后台刷新。
- `RefreshOutcome { refreshed(added, updated) | skipped(reason: fresh/quotaExhausted/tooSoon) | failed(error, cachedCount) }`。

**缓存与离线**：

- 先读缓存再刷新；失败且有缓存 → 列表 + 非阻塞 banner + 重试；无缓存 → 全屏错误 + 重试。
- `identityKey` upsert；不自动删除旧岗位（可能已被 Application 关联；30 天数据量小）；不做分页/淘汰。
- `JobPosting` 不存 `fetchedAt`；`lastRefreshAt` 由 ledger 提供，用于“更新于”。
- Remotive 署名与回链由 Discover/JobDetail 展示；来源字段在 `intakeMethod`/`jobURL`。

**错误**：Data 层抛类型化 `JobSourceError`（`invalidInput` / `offline` / `timedOut` / `rateLimited` / `server(Int)` / `decoding`）；`CancellationError` 单独处理、不展示。ViewModel 映射成中文文案；Repository 不产出用户文案。

**与「Remotive API 现状复核」的边界**：`JobQuery` 形状已定，默认查询值、空状态策略由 09 决定；若结论变化，只改 query 默认值和 UI，不改 Repository 协议。

### 5. 依赖注入、并发与状态

- **组合根**：`NextStepApp` 创建 `AppContainer`（ModelContainer、`JobSourceFactory`、repositories、`SkillDictionary`、`MatchingEngine`、`MatchService`、`NotificationScheduler`），通过 `.environment` 注入；View 的 `init` 接收 container，用 `@State` 持有自己的 VM。
- **协议只放在真正的缝上**：`JobSource`、`JobRepository`、`ApplicationRepository`、`UserProfileRepository`、`MatchProviding`、`NotificationScheduling`、`DateProvider`；`MatchingEngine` / `SkillDictionary` 是值类型，不包协议。
- **状态**：`@Observable` + `@MainActor` VM；不用 `ObservableObject`/Combine；`LoadState<Value>` 统一 idle/loading/loaded/failed；表单用 `@Bindable`；禁止 `.shared` 单例。
- **SwiftData**：主线程单 `ModelContext`，repository `@MainActor`；测试/Preview 用 `isStoredInMemoryOnly`；不做 `ModelActor`/后台 context（v1 数据量不需要）。
- **并发**：从第一天把 `SWIFT_VERSION` 提到 6.0（当前是 5.0），保留 MainActor 默认隔离 + approachable concurrency；远程 source 标 `nonisolated`/`Sendable`，网络与解码在后台，落库回主线程。如果第一周被严格并发卡住，再回退并在本 ticket 记录。
- **通知**：只定义 `NotificationScheduling` 协议与 live 实现；触发时机、文案、权限引导由「截止与面试提醒策略」决定，本 ticket 不替它定。
- **日志**：`os.Logger` 按层分 category；不用 `print`。
- **测试缝**：fake `JobSource`/`JobSourceFactory`、`FixedDateProvider`、临时 UserDefaults suite、in-memory container；VM 用 fake repository；无网络、无 UI test。

### 6. MatchingEngine 的纯度与接入

- `MatchingEngine` 是 `Domain/Matching` 下的纯 `struct`：无 I/O、无 `ModelContext`、无单例、确定性、`Sendable`；只依赖传入的 `UserProfile`、`JobPosting`、`SkillDictionary`。Domain 只为 `@Model` 类型 `import SwiftData`，不 `import SwiftUI`。
- 直接接收 `@Model` 实例，不另造 `MatchProfile`/`MatchJob` 值类型（02/03 已定签名；30 天里多一层映射不划算）。
- `SkillDictionary` 由 `SkillDictionaryLoader` 从 bundle JSON 加载，组合根注入；加载失败 → 日志 + 匹配功能降级为“暂不可用”，浏览/追踪仍可用；测试用内联词典，不 release `fatalError`。
- 薄 `MatchService`（`@MainActor`，协议 `MatchProviding`）：读 `UserProfile`、拿字典/引擎、执行 ≥3 技能门槛，暴露 `evaluate(job)` / `evaluate(jobs)`；Discover/JobDetail VM 只调它，避免重复取画像和门槛逻辑。匹配仍是派生、不落库、每次重算。
- 未知的 `UserProfile.skills` canonical 名称：忽略 + debug log；不报错。
- 150 条岗位在主线程计算；若 profiling 有卡顿再移到后台（P1），不预先优化。

### 7. 测试与验收缝

- `NextStepTests`：状态机、匹配引擎（表驱动）、Remotive 解码 fixture、Repository upsert/去重/节流/缓存降级、Manual 导入、选定 VM。
- 节流测试用 `FixedDateProvider` 覆盖：4 次/滚动 24h、60 秒间隔、跨启动持久化、手动导入不计。
- 匹配测试直接构造 `@Model`，不建 container；断言 0–100、分项和、ineligible 不给总分、别名/大小写不影响结果；不写死具体分数。
- UI 手动验收按「功能边界与 MVP 验收线」的黄金路径；不做完整 UI 测试。

### 8. ADR

- [ADR-0001 单 app target + 分层目录，不拆 SPM 模块](../../../docs/adr/0001-single-target-layered-folders.md)
- [ADR-0002 SwiftData @Model 兼作领域模型，MatchingEngine 保持纯计算](../../../docs/adr/0002-swiftdata-models-as-domain-model.md)
- [ADR-0003 岗位摄入：统一 JobSource、JobPostingDraft 与 JobRepository 唯一写入口](../../../docs/adr/0003-job-ingestion-seam.md)
- [ADR-0004 表现层边界：MVVM 为主，只读列表用 @Query，状态历史用 UIKit/MVC](../../../docs/adr/0004-presentation-boundaries.md)

这 4 条都满足“难回滚 / 没有上下文会显得意外 / 有真实取舍”；依赖注入的具体写法、Swift 6、日志等属于易调整的实现细节，不单独立 ADR。

### 9. 交给后续 ticket

- **「30 天排期、测试与演示方案」**：本 ticket 解除阻塞。排期需包含第 1–2 天脚手架（测试 target、目录、Swift 6、in-memory container、协议空壳），之后按 01 的 P0 顺序；README 的架构图直接复用第 1 节。
- **「Remotive API 现状复核」**：`JobQuery` 形状已定；默认查询值、Discover 空状态仍由 09 决定；不改 Repository/JobSource 协议。
- **「截止与面试提醒策略」**：`NotificationScheduling` 缝已定；触发/文案/权限由 10 决定；Repository 不参与通知调度。
- **与 02/03 对齐**：来源返回 `JobPostingDraft`，Repository upsert 成 `JobPosting`；`MatchResult` 派生不落库；状态转换写 `StatusChange` 由 ApplicationRepository 在同一次操作完成；没有新增实体。
- **与 01 对齐**：黄金路径不变；第 1 节的目录/测试 target 是 01 工程底线的落地方式。

### 10. 资产与变更记录

- `GLOSSARY.md` 新增：`JobSource`、`JobPostingDraft`、`JobRepository`、`JobQuery`、`MatchingEngine`。
- 本 ticket 最初建议把手动粘贴拆成 `ManualJobImporter`；讨论后按“所有来源统一 conform JobSource”定稿，代价是需要 `JobSourceFactory` 按输入创建手动来源，已记录在 ADR-0003。

## Comments

### 2026-11-08 范围变更（通知延后）

本地通知移出 v1（见 [截止与面试提醒策略](10-reminder-policy.md)，已关闭）。据此：

- v1 不建 `Domain/NotificationScheduling.swift` 与 `Data/Notifications/UserNotificationScheduler`，组合根不注入 `NotificationScheduler`。
- 未来实现通知时再引入协议/实现，并直接从 `Application` / `InterviewRound` 读取数据。
- 其余分层、协议缝（`JobSource` / `JobRepository` / `ApplicationRepository` / `UserProfileRepository` / `MatchProviding` / `DateProvider`）与 ADR 不变。

### 2026-11-08 Discover 默认查询与样本模式（来自「Remotive API 现状复核」）

见 [Remotive API 现状复核](09-remotive-api-recheck.md)。协议不变，只补默认值与 DTO 行为：

- 默认 `JobQuery`：无关键字、`category: "software-dev"`、数量上限 50（字段名以最终实现为准）；每次刷新只发一个查询。
- 200 + 12 条样本是 `.refreshed`，不是 `.failed`；条数很少不应视为解码失败或空数据。`total-job-count` 存在且很小（≤50）时，UI 标“样本模式”。
- DTO 新字段按可选处理：`total-job-count`（样本模式判断）、`company_logo_url`（展示可选）；顶层 `00-warning` 忽略或仅日志。
- `JobSource` / `JobRepository` / `RefreshOutcome` / `JobSourceFactory` / `JobPostingDraft` / `identityKey` 均不变；缓存、节流、错误映射、离线策略不变。每日快照下 1 次/日成功刷新足够，4 次/日是上限。
- 手动粘贴 JD 提升为 Discover 主要兜底，但继续走 `ManualJobSource` + `JobRepository.importManual`；不替换 Remotive 演示源。
