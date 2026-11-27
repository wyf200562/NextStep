# NextStep 项目简介

NextStep 是一个纯本地的 iOS 实习申请追踪与岗位发现应用：把投递状态、状态历史、截止日期和面试轮次放进本机 App，同时用可解释的本地规则回答「这份岗位匹配了什么、还缺什么、为什么是这个分数」（来源：README.md）。

## 本文与 README 的分工

README.md 面向首次接触项目的人，重点是产品功能、截图、运行方式、Remotive 合规声明和 Roadmap。本文面向需要理解代码结构的人，重点是目录职责、领域概念之间的关系、五个 ADR 的决策链，以及当前实现状态；两者重叠的部分以 README 的用户视角为准，本文不重复截图与逐步运行说明。

## 1. 项目定位

### 解决什么问题

- 求职者同时推进多份实习投递时，公司、状态、截止日期和面试时间容易散落在邮件、聊天记录和表格里；NextStep 把这些记录收敛到一个本机 App（来源：README.md）。
- 岗位来源与个人背景之间的匹配往往不透明；NextStep 用技能词典加规则加权给出可解释的分数、匹配/缺失技能和分项解释，而不是只给一个黑盒分数（来源：docs/design/matching-engine.md）。

### 目标用户

同时处理多份实习投递的求职者：一边记录申请，一边从每日岗位样本里筛选值得投的岗位（来源：README.md）。

### 产品边界

- 不登录、不云同步、不收集注册信息、不上传数据；所有数据只保存在本机（来源：README.md）。
- 不依赖任何第三方库，无 SPM 包（来源：README.md；NextStep.xcodeproj/project.pbxproj 中无 packageReferences）。
- 交付承诺只覆盖模拟器演示，不包含 TestFlight / App Store 上架流程（来源：README.md）。

## 2. 技术栈

一句话概括：**Swift 6 + SwiftUI + SwiftData，单个 Xcode 工程，零第三方依赖，Swift Testing 单测**。

| 类别 | 选型 | 具体做法 | 来源 |
|---|---|---|---|
| 语言 | Swift 6.0 | Swift 6 语言模式，编译期严格并发检查 | NextStep.xcodeproj/project.pbxproj:205 |
| 并发模型 | 默认 MainActor 隔离 | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`，并开启 `SWIFT_APPROACHABLE_CONCURRENCY` | NextStep.xcodeproj/project.pbxproj:202-203 |
| UI 框架 | SwiftUI 为主，一处 UIKit | 页面、导航、Tab 全部 SwiftUI；状态历史是唯一 UIKit 页面（`UIViewController` + `UITableViewDiffableDataSource`） | README.md；docs/adr/0004-presentation-boundaries.md |
| 持久化 | SwiftData | 单 `ModelContainer`、主线程 `ModelContext`、`VersionedSchema` V1 | README.md；NextStep/Data/Persistence/ModelContainerFactory.swift |
| 测试框架 | Swift Testing | `@Suite` / `@Test` / `#expect` / `#require`，表驱动、确定性、不联网 | README.md；NextStepTests/GoldenPathIntegrationTests.swift:3-5 |
| 日志 | os.Logger | 按层分 category，全仓库无 `print` | NextStep/Core/AppLogger.swift；docs/design/architecture.md |
| 状态管理 | `@Query` + `@Observable @MainActor` ViewModel | 只读页面不加 ViewModel，有异步/表单的页面才用 VM；无第三方状态库 | docs/adr/0004-presentation-boundaries.md；docs/design/architecture.md |
| 数据来源 | URLSession + 自写 DTO 解码 | 只访问 Remotive 公共 API，无 SDK、无鉴权；`URLSession` 与 `JSONDecoder` 均注入或直接使用，便于测试替换 | NextStep/Data/Sources/RemotiveJobSource.swift:16,52 |
| 规则数据 | 本地 JSON 词典 | 技能、方向、地点三份 JSON 随包分发 | NextStep/Resources/SkillDictionary.json 等 |
| 第三方依赖 | 零 | 无 SPM 包、无 CocoaPods、无二进制依赖 | README.md；docs/adr/0001-single-target-layered-folders.md |
| 工程形态 | 单 app target + 分层目录 | 不拆 SPM 模块，层间边界靠约定与 review | docs/adr/0001-single-target-layered-folders.md |

## 3. 平台与构建

| 项目 | 取值 | 来源 |
|---|---|---|
| 部署目标 | iOS 27.0（`IPHONEOS_DEPLOYMENT_TARGET = 27.0`） | NextStep.xcodeproj/project.pbxproj:193 |
| 开发环境 | Xcode 27（`LastUpgradeCheck = 2700`，含 iOS 27 模拟器运行时） | NextStep.xcodeproj/project.pbxproj:119；README.md |
| 设备族 | `TARGETED_DEVICE_FAMILY = "1,2"`（iPhone 与 iPad），但交付说明只承诺 iPhone 模拟器演示 | NextStep.xcodeproj/project.pbxproj:206；README.md |
| 依赖安装 | 无需任何安装步骤，直接打开 `NextStep.xcodeproj` | README.md |
| 构建命令 | `xcodebuild -project NextStep.xcodeproj -scheme NextStep -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build` | README.md |
| 测试命令 | 同上，末段换成 `test` | README.md |

## 4. 目录结构

顶层按 `App / Features / Domain / Data / Core` 分层，资源单独放在 `Resources`（来源：docs/adr/0001-single-target-layered-folders.md；docs/design/architecture.md）。

| 目录 | 职责 | 代表文件 |
|---|---|---|
| `NextStep/App` | 组合根、启动状态、根 Tab、跨 tab 路由 | `NextStepApp.swift`、`AppContainer.swift`、`RootTabView.swift`、`AppRouter.swift` |
| `NextStep/Features` | SwiftUI 页面、ViewModel、纯展示 helper；按 Overview / Applications / Discover / Profile 等子目录组织 | `Features/Discover/DiscoverViewModel.swift`、`Features/Applications/ApplicationListBuilder.swift` |
| `NextStep/Domain` | 5 个 `@Model`、七态状态机、匹配引擎、岗位来源与仓库协议 | `Domain/Models/Application.swift`、`Domain/ApplicationStateMachine.swift`、`Domain/Matching/MatchingEngine.swift` |
| `NextStep/Data` | SwiftData 仓库、Remotive / 手动来源、DTO、词典加载、刷新账本、容器工厂 | `Data/Repositories/SwiftDataJobRepository.swift`、`Data/Sources/RemotiveJobSource.swift` |
| `NextStep/Core` | 无业务依赖的基础设施：加载状态、日期、HTML 归一化、URL 校验、日志 | `Core/LoadState.swift`、`Core/DateProvider.swift`、`Core/AppLogger.swift` |
| `NextStep/Resources` | 技能、方向、地点三份 JSON 词典 | `Resources/SkillDictionary.json`、`RoleDirectionLexicon.json`、`LocationLexicon.json` |
| `NextStepTests` | 单一测试 target，通过 `@testable import NextStep` 访问 internal 类型 | `NextStepTests/GoldenPathIntegrationTests.swift` |

按当前工作区统计，`NextStep/` 下约有 107 个 Swift 文件、1.08 万行；`NextStepTests/` 约有 45 个 Swift 文件、1.03 万行（来源：本次调研对仓库文件的 `find` / `wc -l` 统计，不属于文档既有结论）。

依赖方向为 **Features → Domain ← Data**，`App` 同时依赖 Features 与 Data，`Core` 被各层共享；`Domain` 允许 `import SwiftData`（仅 `@Model` 声明），但不 `import SwiftUI`，也不持有持久化容器（来源：docs/design/architecture.md；docs/adr/0002-swiftdata-models-as-domain-model.md）。

## 5. 核心领域模型与关键概念

### 从岗位到申请的概念链

`JobSource` 负责「取数 + 归一化」，产出非持久化的 `JobPostingDraft`；`JobRepository` 是唯一持久化写入口，按 `identityKey` upsert 成 `JobPosting`；用户再从岗位创建 `Application`（来源：docs/adr/0003-job-ingestion-seam.md；docs/design/ingestion.md）。

```
JobSource（Remotive / 手动粘贴 / 未来 URL）
  -> JobPostingDraft
  -> JobRepository（唯一写入口，identityKey upsert）
  -> JobPosting
  -> Application（可关联 JobPosting，也保留公司/职位/链接/地点快照）
  -> StatusChange（状态历史） / InterviewRound（面试轮次）
```

### 五个持久化模型

| 模型 | 作用 | 关键关系/约束 |
|---|---|---|
| `Application` | 一条投递记录，承载状态、截止日期、备注与快照字段 | `interviewRounds` 与 `statusChanges` 均 cascade；`jobPosting` 在岗位删除时置空 |
| `JobPosting` | 本机缓存的岗位，来源为 Remotive 或手动粘贴 | `identityKey` 唯一，用于 upsert；`applications` 删除规则为 nullify |
| `InterviewRound` | 一轮面试的时间、形式、联系人、备注、结果 | 属于一个 `Application`；轮次时间不单独驱动「接下来」 |
| `StatusChange` | append-only 的状态转换记录 | `fromStatus` 可为 nil（创建时的初始记录），`toStatus` 必填 |
| `UserProfile` | 匹配用的单例画像：技能、目标方向、偏好地点、时区、可实习时间、毕业年份 | 由仓库 fetch-or-create 保证单例 |

（来源：NextStep/Data/Persistence/SchemaV1.swift:10-18；NextStep/Domain/Models/Application.swift:16-24；NextStep/Domain/Models/JobPosting.swift；docs/design/architecture.md）

### 关键术语之间的关系

- **JobPosting 与 JD**：JD 只是 JobPosting 中的职责与要求文本，不是独立实体（来源：GLOSSARY.md）。
- **JobIdentityKey**：形如 `remotive:12345` 或 `manual:<uuid>` 的稳定身份键，用于刷新去重；不同于本机主键 `id`（来源：GLOSSARY.md；docs/design/ingestion.md）。
- **JobRepository 与 JobSource**：来源只取数与归一化，仓库只负责存、节流与错误映射；UI 和匹配都不直接接触来源（来源：docs/adr/0003-job-ingestion-seam.md）。
- **Application 与 StatusChange**：`Application.status` 是当前值，`StatusChange` 是历史事实源；两者只在仓库的同一次操作里更新（来源：docs/design/application-lifecycle.md）。
- **Deadline 与 InterviewRound**：`Application.deadline` 是「下一个节点」的唯一指针；`InterviewRound.scheduledAt` 是那场面试的历史记录与排序依据，保存轮次时会把更早的时刻写入 `deadline`（来源：docs/adr/0005-deadline-is-the-next-node.md；NextStep/Domain/Models/Application.swift:85）。
- **Overdue**：Deadline 早于此刻的状态，是可被用户推进的可见提示，不属于「即将到来」（来源：GLOSSARY.md）。
- **MatchResult**：由 UserProfile 与 JobPosting 现算的派生结果，不持久化；`MatchingEngine` 是无 I/O 的纯计算模块（来源：GLOSSARY.md；NextStep/Domain/Matching/MatchingEngine.swift:17）。

### 七个申请状态

`wishlist / applied / oa / interview / offer / rejected / withdrawn`，界面文案依次为想投、已投、OA/笔试、面试、Offer、已拒、已撤；`offer` 无普通出口，`rejected` 与 `withdrawn` 只能通过显式「重新打开」恢复（来源：NextStep/Domain/ApplicationStatus.swift；NextStep/Domain/ApplicationStateMachine.swift:24-39）。

## 6. 架构分层与关键设计决策

| ADR | 决策 | 主要理由 | 主要代价 |
|---|---|---|---|
| 0001 | 单 app target + 分层目录，不拆 SPM 模块 | 30 天预算下，包配置与资源加载成本高于编译器强制边界带来的收益 | 层间边界靠约定与 review；未来抽包优先抽 `Domain/` |
| 0002 | SwiftData `@Model` 兼作领域模型，`MatchingEngine` 保持纯计算 | 避免维护两层模型和双向映射，把复杂度留给业务规则 | Domain 层耦合 SwiftData；脱离它需要先引入值类型快照 |
| 0003 | 统一 `JobSource` / `JobPostingDraft` / `JobRepository` 摄入缝 | 来源可替换，配额按来源独立，离线与失败行为集中可测 | 多一层协议与 draft 映射 |
| 0004 | MVVM 为主；只读列表用 `@Query`；状态历史用 UIKit/MVC | 只读页面不强行加 VM；保留一个低风险的 UIKit 展示点 | 页面形态不统一，review 需防止只读页面长出业务逻辑 |
| 0005 | Deadline 即下一个节点，一个申请只有一个时刻指针 | 求职没有可预期终局，用户只知道「下一件事是什么时候」 | 同一时刻可能同时存在于轮次和 `deadline`；不做自动对账 |

（来源：docs/adr/0001-single-target-layered-folders.md 至 docs/adr/0005-deadline-is-the-next-node.md）

### 分层落地方式

- `AppContainer` 是唯一的组合根，持有 `ModelContainer`、三个仓库、`JobSourceFactory`、`RefreshLedger`、`MatchService` 与 `AppRouter`；容器创建失败时启动页显示阻塞式中文错误页并可重试（来源：NextStep/App/AppContainer.swift:12；NextStep/App/AppRootView.swift）。
- `AppRouter` 不是 ViewModel，只持有 `selectedTab` 和最多一个 `pendingRoute`，每个 tab 自己的 `NavigationStack` 路径仍由 View 持有（来源：NextStep/App/AppRouter.swift:6-18）。
- 概览与申请列表直接用 `@Query` 加纯函数派生，不配 ViewModel（来源：NextStep/Features/Overview/OverviewView.swift:14；NextStep/Features/Applications/ApplicationsView.swift:8）。
- 有异步加载、表单或多步操作的页面使用 `@Observable @MainActor` ViewModel；ViewModel 不持有 `ModelContext`（来源：docs/adr/0004-presentation-boundaries.md；docs/design/architecture.md）。
- 状态历史是唯一 UIKit 页面，使用 `UIViewController` + `UITableViewDiffableDataSource`，无 ViewModel（来源：docs/adr/0004-presentation-boundaries.md；NextStep/Features/StatusHistory/StatusHistoryViewController.swift:11）。

## 7. 主要功能与用户流程

### 四个根 tab

概览、申请、发现（页面标题为 Discover）、我的（来源：NextStep/App/AppTab.swift；NextStep/App/RootTabView.swift）。

### 申请追踪

1. 在概览或申请列表点「添加申请」，通过编辑表单创建记录；创建时在同一保存里写入初始 `StatusChange`（来源：docs/design/application-lifecycle.md；NextStep/Features/Applications/ApplicationEditorView.swift）。
2. 在申请详情推进七态状态机；允许跳级，回退和重新打开需要二次确认，非法转换抛 `ApplicationTransitionError`（来源：NextStep/Domain/ApplicationStateMachine.swift；docs/design/application-lifecycle.md）。
3. 在详情里维护 `deadline`、备注和面试轮次；保存更早的轮次会把指针前移（来源：NextStep/Domain/Models/Application.swift:85）。
4. 状态历史 sheet 以 diffable data source 展示 from → to、时间与备注（来源：NextStep/Features/StatusHistory/StatusHistoryViewController.swift）。

### 岗位发现

1. Discover 先读本地缓存，再按 6 小时 TTL 与滚动 24 小时最多 4 次、两次至少间隔 60 秒的配额刷新 Remotive（来源：NextStep/Features/Discover/DiscoverViewModel.swift:45；NextStep/Data/Throttling/RefreshLedger.swift:11-13）。
2. 刷新失败时按是否有缓存分成琥珀色非阻塞提示与全屏阻塞提示；无缓存时提供重试与粘贴 JD 兜底（来源：docs/design/ingestion.md；NextStep/Features/Discover/DiscoverView.swift）。
3. 列表按 eligibility 分组展示；可切换「只看实习」，该过滤只影响展示（来源：NextStep/Features/Discover/DiscoverViewModel.swift）。
4. 粘贴 JD 是独立来源，不消耗 Remotive 配额；标题含 intern / 实习时自动识别为实习（来源：docs/design/ingestion.md；NextStep/Data/Sources/ManualJobSource.swift）。

### 匹配与导入申请

1. 岗位详情调用 `MatchService` 现算 `MatchResult`，展示分数、分档、四项分项、匹配/缺失技能与原因（来源：docs/design/matching-engine.md）。
2. 画像门槛为至少 3 个可解析技能 + 至少 1 个目标方向；不足时显示「完善画像后查看匹配」，但岗位仍可浏览和导入（来源：NextStep/Domain/Matching/MatchingEngine.swift:19-46）。
3. 导入前检查已有申请：进行中的申请只提供「查看」，终态岗位才允许再次导入（来源：docs/design/application-lifecycle.md；NextStep/Features/Discover/JobDetailViewModel.swift:145）。

### 跨 tab 跳转

概览的事件行与最近更新行跳申请详情；三个计数跳对应筛选列表；Discover 导入成功跳申请详情；「去完善画像」跳我的（来源：docs/design/presentation.md；NextStep/App/AppRouter.swift）。

## 8. 数据与持久化

- 5 个模型全部属于 `SchemaV1`，容器通过 `NextStepMigrationPlan` 创建；当前 `stages` 为空，只允许新增可选字段或新模型这类轻量变更（来源：NextStep/Data/Persistence/SchemaV1.swift；NextStep/Data/Persistence/NextStepMigrationPlan.swift）。
- 应用使用磁盘上的单一 store；测试与 Preview 使用 `isStoredInMemoryOnly: true`（来源：NextStep/Data/Persistence/ModelContainerFactory.swift；NextStep/App/AppContainer.swift）。
- 删除规则：申请级联删除轮次与状态历史；删除岗位只把 `Application.jobPosting` 置空，快照字段仍保留（来源：docs/design/architecture.md；NextStep/Domain/Models/Application.swift）。
- 刷新配额持久化在 `UserDefaults`，按获取方式分源维护；测试注入临时 suite 避免污染应用数据（来源：docs/design/ingestion.md；NextStep/App/AppContainer.swift）。
- Debug 构建提供「清空演示数据」，删除五类记录并重置刷新配额；该入口位于 `#if DEBUG` 内（来源：NextStep/Features/Profile/AboutView.swift:29；NextStep/Data/Persistence/DemoDataResetter.swift）。
- 网络只用于 Remotive 公共 API：`GET https://remotive.com/api/remote-jobs`，无鉴权、无后端、无账号体系（来源：NextStep/Data/Sources/RemotiveJobSource.swift:10；README.md）。

## 9. 测试情况

- 框架为 Swift Testing，测试 target 为 `NextStepTests`（来源：NextStepTests/GoldenPathIntegrationTests.swift:3-5）。
- 当前共有 45 个测试文件、40 个 `@Suite`、397 处 `@Test`（来源：本次调研对 `NextStepTests/` 的 grep 统计）。
- 测试替身集中在 `NextStepTests/Support`：fake repository、fake match provider、可控时钟、`URLProtocolStub`（来源：NextStepTests/Support/ 目录）。
- 覆盖范围包括领域模型、状态机全转换、匹配规则边界、词典解析、Remotive DTO/HTTP 映射、仓库 upsert/节流/缓存、选定 ViewModel 行为、Debug 清空演示数据（来源：README.md；NextStepTests/ 各文件）。
- `GoldenPathIntegrationTests` 在数据层串起「完善画像 → 粘贴 JD → 匹配 → 导入申请 → 推进状态 → 设置 deadline → 添加轮次 → 派生概览 → 重开 store 验证持久化」，不依赖 UI、网络或系统时钟（来源：NextStepTests/GoldenPathIntegrationTests.swift:8-12）。
- 本次调研未执行 `xcodebuild test`，因此测试是否全部通过属于「未确认」；以上只统计了测试文件与用例数量。

## 10. 当前状态与后续方向

### 版本与进行中的工作

- 仓库有 `v1.0` 标签，提交历史共 107 个 commit，最早提交为 2026-11-05，当前 HEAD 为 2026-11-26 的 PR #15 合并（来源：git log / git tag）。
- 最近两条集成线是 `integration/deadline-as-next-node`（把 Deadline 收敛为唯一下一节点，ticket 25-28）和 `integration/12-single-paste-entry`（统一粘贴 JD 入口：无岗位时一张卡，有岗位时收进工具栏）（来源：git log；NextStep/Features/Discover/DiscoverView.swift:27-38）。
- README 仍把 Discover、岗位详情匹配、申请详情标为截图占位，需要在模拟器手动走查后替换（来源：README.md；docs/images/ 目录）。

### v1 已知限制

- 岗位池受 Remotive 每日约 10-12 条样本限制，查询参数基本不生效；实习岗位可能为 0（来源：README.md）。
- 匹配依赖词典覆盖，语义泛化弱；可实习时间、毕业年份、时区只展示不参与计分（来源：README.md；docs/design/matching-engine.md）。
- 不做本地通知、后台刷新、URL 导入、全文搜索、CSV 导入导出、账号、iCloud 同步、Widget 或 Share Extension（来源：README.md）。
- 一个申请同一时刻只能表达一个待处理节点；指针由用户手动推进，会过期（来源：docs/adr/0005-deadline-is-the-next-node.md）。
- 只承诺模拟器演示；免费 Apple 账号真机签名 7 天后过期（来源：README.md）。

### P1 Roadmap

URL 导入、漏斗与状态分布图、本地通知、embedding 作为 5-10 分 tie-breaker、后台刷新、全文搜索与 CSV 导出（来源：README.md）。

### 文档一致性提示

`docs/design/application-lifecycle.md:35` 仍写着「面试时间不属于 deadline」，而 ADR-0005 与 `Application.deadlineAfterRecordingRound(at:)` 的实现都允许把更早的轮次时间写入 `deadline`（来源：docs/design/application-lifecycle.md:35；docs/adr/0005-deadline-is-the-next-node.md；NextStep/Domain/Models/Application.swift:85）。以 ADR 和代码为准，该句属于待更新的旧表述。

### 未确认事项

- 测试在当前环境下是否全部通过：未确认（本次未运行测试）。
- 真机长期可用性、App Store 上架：项目明确不承诺，属于范围外（来源：README.md）。
- 未来 URL 导入、通知、后台刷新等 P1 能力：文档中均为计划，代码中尚无实现（来源：README.md；docs/design/ingestion.md）。

## 11. 参考文件

- `README.md`、`GLOSSARY.md`、`CLAUDE.md`（`AGENTS.md` 为其符号链接）
- `docs/adr/0001` 至 `docs/adr/0005`
- `docs/design/architecture.md`、`application-lifecycle.md`、`ingestion.md`、`ingestion-architecture.md`、`matching-engine.md`、`presentation.md`
- `docs/agents/domain.md`、`issue-tracker.md`、`triage-labels.md`
- `NextStep.xcodeproj/project.pbxproj` 与 `NextStep/`、`NextStepTests/` 下的源码
