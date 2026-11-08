# 30 天排期、测试与演示方案

Type: grilling
Mode: HITL
Status: resolved
Blocked by: 01, 02, 03, 04, 05

## Question

在剩余约 30 天、每天可投入时间待确认的前提下，如何排期并交付可演示的作品？

- 四周里程碑：脚手架/数据模型 → 追踪器核心 → 匹配引擎 → 打磨 + 演示。
- 每日/每周投入时间与缓冲。
- 测试策略：MatchingEngine 单测、状态机单测、关键 UI 流程。
- 演示脚本：3–5 分钟视频录什么；GitHub README 放什么（架构图、取舍、截图、运行说明）。
- 面试可讲的 3 个技术取舍。

## Answer

日期：2026-11-08。

### 0. 范围调整

用户明确：**不需要日历、周计划或小时级时间规划**；时间充足，不砍 P0 功能；**不做视频演示**；**中文 README、公开仓库**；简历上的具体呈现等 v1 雏形出来后再定。本 ticket 因此只保留「执行顺序 + 完成标准」「测试策略」「演示与 README」「面试技术取舍」，不产出排期表。

### 1. 执行顺序与完成标准（无日期）

沿用 [功能边界与 MVP 验收线](01-feature-boundary.md) 的 P0 顺序，只给每个里程碑的 exit criteria：

1. **领域核心**
   - 5 个 SwiftData `@Model` + `VersionedSchema` V1；七态状态机（合法转换、跳级、回退、reopen、offer 终态）；Application/UserProfile repository + StatusChange 写入；状态机与 repository 单测绿。
2. **追踪器闭环**
   - Application CRUD（列表/详情/新建/编辑/删除）；状态流转 + StatusChange；deadline + 本地通知提醒；InterviewRound；黄金路径中的追踪器段可手动走通。
3. **匹配闭环（手动）**
   - UserProfile 编辑 + 技能词典加载；手动粘贴 JD → JobPosting；MatchingEngine + MatchResult + 解释展示；匹配引擎表驱动单测绿；导入 Application。
4. **发现闭环（Remotive）**
   - JobSource + RemotiveJobSource；JobRepository upsert/节流/缓存/错误映射；Discover 列表/详情 + Remotive 署名回链；一键导入；断网/超时/限流/解码失败有可见错误 + 缓存兜底。
5. **收尾**
   - 仪表盘变体 A；全局空/错状态；中文 README（架构图、取舍、截图、运行说明、Remotive 声明）；现场演示可走完整黄金路径；仓库公开 + `v1.0` tag。

规则：每个里程碑完成后跑该切片的手动验收 + 单测；**不设日期、不设周检查点**；P1（URL 导入、漏斗、状态分布）不排入 v1，只在 README Roadmap 列出。

### 2. 测试策略（沿用基线）

- **测试 target**：第一天建 `NextStepTests`，Swift Testing；SwiftData 用 in-memory container；节流用 `FixedDateProvider`；来源用 fake `JobSource`/fixture；不联网。
- **单测清单**：
  - `ApplicationStateMachine`：全部合法转换、非法转换、跳级、回退、终态、reopen、offer 终态。
  - `MatchingEngine`：表驱动覆盖空描述、无技能命中、别名/同义词、大小写/全半角、中文 JD、HTML、`Swift`/`SwiftUI` 子串陷阱、零重叠、全匹配、重复提及、地点不符、非实习、低置信度、画像门槛、分数边界/确定性；断言 0–100、分项和、ineligible 不给总分；不写死具体分数。
  - `SkillDictionaryLoader`：JSON 解析、别名、重复、缺失。
  - `RemotiveDTO`/`JobSource`：解码 fixture（正常、缺字段、坏日期、HTML、错误 JSON）。
  - `SwiftDataJobRepository`：`identityKey` upsert、去重、缓存优先、4 次/滚动 24h、60s 间隔、跨启动持久化、手动导入不计、离线/失败降级。
  - `ApplicationRepository`：StatusChange 写入、`appliedAt` 派生、级联删除；`UserProfileRepository` fetch-or-create。
  - 选定 VM：`DiscoverViewModel` 的 LoadState/错误映射/节流 UI；`ApplicationDetailViewModel` 的状态转换。
- **UI**：手动验收黄金路径；不做 XCUITest/完整 UI 测试；不配 CI（本地 `xcodebuild test`）。
- **合入门槛**：核心逻辑改动必须有对应单测；不设覆盖率百分比。

### 3. 演示与 README

- **不做视频演示**。演示 = 现场打开 App（模拟器），按黄金路径走；不承诺真机安装包（免费账号 7 天签名）。
- **README（中文）**结构：项目简介 + 截图 → 功能 → 技术栈 → 架构图与分层 → 三个关键取舍 → 运行方式（Xcode 27 / 模拟器 / 免费账号说明）→ 测试命令 → Remotive 数据来源与合规声明 → 已知限制 + P1 Roadmap → 设计文档链接（GLOSSARY、ADR）。
- **截图/GIF**：README 内嵌关键截图；GIF 可选，不算演示视频。
- **演示数据**：申请和手动 JD 全部虚构；Discover 用真实 Remotive 数据并署名回链；建议加 Debug-only「重置演示数据」入口，保证现场可重复。
- **仓库**：公开；不公开 `.scratch/` 原始记录，另建 `docs/design/` 精选设计说明；License MIT。
- **简历呈现**：不在本 ticket 定；等 v1 雏形出来后，再按实际实现决定 bullet 和演示重点（见 map 的 Not yet specified）。

### 4. 面试三个技术取舍

1. **匹配引擎：技能词典 + 规则加权 vs embedding/LLM**（[匹配算法与技能词典](02-matching-engine.md)）
   - 讲点：可解释、确定性、可测试、无 API/成本/隐私问题；代价是召回受词典覆盖限制、语义泛化弱。
   - 可扛追问：为什么不用 embedding？词表小、JD 结构相对固定、需要展示「匹配/缺失」证据；embedding 可作为 P1 的 5–10 分 tie-breaker。
2. **`JobSource` / `JobPostingDraft` / `JobRepository` 统一摄入缝**（[混合架构与 JobSource 抽象](04-architecture.md)，ADR-0003）
   - 讲点：所有来源（Remotive、手动、未来 URL）统一为 draft；Repository 唯一写入口，集中 upsert、节流、缓存、错误映射；UI 和匹配不碰来源，测试用 fake source。
   - 可扛追问：为什么多一层？30 天里换来可测试性和离线/节流逻辑的单点维护，比每个页面直接 fetch 划算。
3. **SwiftData `@Model` 兼作领域模型 + 纯 `MatchingEngine`**（[领域模型与投递状态机](03-domain-model.md)，ADR-0002）
   - 讲点：单 target 下不另造一套 domain entity，减少映射；`MatchingEngine` 保持纯结构、无 I/O、无 `ModelContext`，可直接用 `@Model` 实例做输入并用单元测试覆盖；代价是领域层与 SwiftData 耦合，未来拆模块时需要解耦。
   - 可扛追问：为什么不拆 SPM/独立 Domain？30 天优先交付与可测性；协议缝只放在真正需要替换的地方（来源、仓库、通知、时间）。

### 5. 技术决策索引（供后续简历/面试引用）

详细内容在各 ticket，不在本 ticket 重复：

- 功能边界与 P0/P1：[功能边界与 MVP 验收线](01-feature-boundary.md)。
- 匹配算法、权重、解释展示、技能词典：[匹配算法与技能词典](02-matching-engine.md)、[技能词典初稿](../skill-dictionary.md)。
- 5 个实体、七态状态机、StatusChange、SwiftData 迁移：[领域模型与投递状态机](03-domain-model.md)。
- 分层、`JobSource`/`JobPostingDraft`/`JobRepository`、MVVM/UIKit 边界、4 条 ADR：[混合架构与 JobSource 抽象](04-architecture.md)、`docs/adr/0001`–`0004`。
- Remotive 数据源约束与映射：[Remotive 集成约束与数据映射](07-remotive-integration.md)。
- 仪表盘首屏结构：[仪表盘原型](08-dashboard-prototype.md)。
- 提醒策略（待解决）：[截止与面试提醒策略](10-reminder-policy.md)。
- 术语表：`GLOSSARY.md`。

### 6. 依赖与风险（无日期）

- **10 号「截止与面试提醒策略」**：追踪器闭环做通知前必须解决，否则通知实现没有规则。
- **09 号「Remotive API 现状复核」**：发现闭环前必须解决；若 internship 仍稀缺，按「真实数据 + ineligible + 手动虚构实习 JD」演示，不伪造数据。
- **免费账号**：模拟器演示；真机 7 天签名，不作为交付承诺。
- **P1**：URL 导入、漏斗、状态分布图不排入 v1，README 列为 Roadmap。

### 7. 明确不做

- 日历、周计划、小时级排期。
- 视频演示。
- XCUITest / 完整 UI 测试 / CI。
- 简历条目的最终定稿（等雏形后）。
- P1 功能进 v1 验收线。

## Comments

### 2026-11-08 范围变更（通知延后）

本地通知移出 v1（见 [截止与面试提醒策略](10-reminder-policy.md)，已关闭）。据此：

- 第 1 节里程碑 2 的「deadline + 本地通知提醒」改为「deadline + 仪表盘 upcoming 展示」。
- 第 6 节风险中的 10 号提醒策略不再阻塞 v1。
- 其余执行顺序、测试策略、演示/README 不变。
