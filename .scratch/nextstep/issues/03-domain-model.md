# 领域模型与投递状态机

Type: grilling
Mode: HITL
Status: resolved
Blocked by: 01

## Question

NextStep 的核心领域对象和状态流转是什么？

- Application / JobPosting / Company / InterviewRound / UserProfile / Skill 之间的关系。
- 投递状态：wishlist → applied → OA/笔试 → interview → offer / rejected / withdrawn；允许的转换与回退。
- 面试轮次如何记录（时间、形式、联系人、备注、结果）。
- 哪些字段必填/可选，哪些是派生（匹配分、截止提醒、漏斗统计）。
- SwiftData 模型与迁移策略的初步边界。

## Answer

日期：2026-11-08。术语已同步到 `GLOSSARY.md`。

### 1. 实体与关系

v1 只有 5 个 SwiftData 模型：

- `Application`：投递记录，存投递过程 + 公司/职位/链接/地点快照；可选关联 `JobPosting`。
- `JobPosting`：岗位发布，只读/导入；JD 全文在 `descriptionPlainText`。
- `InterviewRound`：Application 下的面试轮次；不含 OA/笔试。
- `StatusChange`：Application 的状态转换历史，append-only。
- `UserProfile`：单例用户画像，不与其它实体建关系。

不建独立 Company / Skill 实体（见 [功能边界与 MVP 验收线](01-feature-boundary.md)）。公司用 `companyName: String`；技能用 `UserProfile.skills: [String]`，存技能词典的 canonical 名称，不带熟练度。

关系与删除规则：

- `Application.jobPosting`：可选 to-one；`JobPosting.applications`：to-many inverse；删除 JobPosting → nullify；删除 Application 不影响 JobPosting。
- `Application.interviewRounds`、`Application.statusChanges`：to-many inverse；删除 Application → cascade。
- 同一 JobPosting 在 schema 上允许多条 Application（换周期再投）；导入流程发现已有非终态申请时提示打开已有申请，不重复创建。
- 快照字段：`companyName`、`roleTitle`、`jobURL`、`location`；列表/详情不依赖 JobPosting 是否还在。

### 2. 申请状态机

状态（`ApplicationStatus`，raw String）：`wishlist`、`applied`、`oa`、`interview`、`offer`、`rejected`、`withdrawn`；显示时 OA =「OA/笔试」。

普通转换（允许跳级）：

| from | 允许的 to |
|---|---|
| wishlist | applied, withdrawn |
| applied | wishlist（回退）, oa, interview, offer, rejected, withdrawn |
| oa | wishlist / applied（回退）, interview, offer, rejected, withdrawn |
| interview | wishlist / applied / oa（回退）, offer, rejected, withdrawn |
| offer | —（成功终态） |
| rejected | —（终态；只能经「重新打开」） |
| withdrawn | —（终态；只能经「重新打开」） |

终态与「重新打开」：

- `offer` 是成功终态，不可离开；拒 offer 用备注记录（v1 不建 `offerResponse`）。
- `rejected`、`withdrawn` 是终态，但可显式「重新打开」并二次确认：
  - `rejected` → `applied` / `oa` / `interview` / `offer`（→ `offer` 覆盖「HR 捞回」）
  - `withdrawn` → `wishlist` / `applied` / `oa` / `interview` / `offer`
- 普通转换不能进入/离开终态；重新打开必须记录 `StatusChange`。
- 活动态之间的回退需二次确认，照常记录 `StatusChange`。
- 每次状态变化写一条 `StatusChange`；创建 Application 时写初始记录（`fromStatus = nil`, `toStatus = 初始状态`），初始 `changedAt` 可补录为过去日期；之后 append-only，不编辑。

### 3. StatusChange

- 字段：`fromStatus: ApplicationStatus?`（初始为 nil）、`toStatus`、`changedAt`、`note: String?`、`application` 反向关系。
- 只记录状态转换，不记录备注/截止/轮次修改；这些只更新 `Application.lastModifiedAt`。
- `Application.status` 冗余存当前状态，用于列表筛选/仪表盘计数；`StatusChange` 是历史事实源，两者由 repository 在同一次操作更新。
- 派生 `appliedAt` = 第一条 `toStatus == applied` 的 `changedAt`（若初始记录直接为 applied，则取初始记录），不单独存字段。
- 存储为独立的 SwiftData `@Model`，与 Application 一对多、cascade 删除；在同一个本地 SwiftData store，不是 JSON/UserDefaults。

### 4. InterviewRound

- `scheduledAt: Date`（必填，日期 + 时刻）
- `format: InterviewFormat`（phone / video / onsite / other，必填）
- `label: String?`（可选，如「一面」「HR 面」）
- `contact: String?`（可选自由文本）
- `notes: String?`（可选）
- `result: InterviewResult`（pending / passed / failed / cancelled，默认 pending）
- OA/笔试不记入 InterviewRound；OA 的时间点由 `StatusChange` 提供。
- 轮次不自动改 Application 状态；加未来轮次时 UI 可提示「是否标记为面试中？」，由用户确认。某轮 failed 不自动 rejected。

### 5. Application / JobPosting / UserProfile 字段

**Application**

- 必填：`id: UUID`、`companyName`、`roleTitle`、`status`（默认 wishlist）、`createdAt`、`lastModifiedAt`
- 可选：`jobPosting`、`deadline: Date?`、`notes: String?`、`jobURL: URL?`、`location: String?`
- `lastModifiedAt`：任何编辑（备注、deadline、轮次、状态）都更新；仪表盘「最近更新」按它排序。
- 不存 `appliedAt`（派生）。
- `deadline` 语义：下一个关键节点时间（投递、OA、offer 回复等），日期 + 可选 HH:mm；不填时刻默认当天 09:00；面试时间在 InterviewRound。

**JobPosting**

- 必填：`id: UUID`、`title`、`companyName`、`intakeMethod: JobIntakeMethod`、`descriptionPlainText`、`createdAt`、`identityKey`
- 可选：`externalJobID: String?`、`jobURL: URL?`、`location: String?`、`jobType: String?`、`tags: [String]`、`publishedAt: Date?`、`salary: String?`、`companyLogoURL: URL?`
- `intakeMethod`：`.remotive` / `.manual`（未来 `.url`），表示岗位进入本机的渠道；不用 `source`（易与 HTTP method / sourceURL 混淆）。
- `identityKey`：稳定身份键，`"remotive:<id>"` / `"manual:<uuid>"`；`@Attribute(.unique)`，冲突行为 upsert；不同于本机主键 `id`。
- 不存 `fetchedAt`；刷新节流是 `JobRepository` 的全局 `lastRefreshAt`。未来要显示单条更新时间再加 `lastFetchedAt`。
- 只读/导入；Repository 按 `identityKey` upsert 更新缓存。

**UserProfile（单例）**

- `id: UUID`、`skills: [String]`、`targetRoles: [String]`；可为空数组，不阻塞保存；匹配入口提示补全。
- 可选：`preferredLocations: [String]`、`timeZoneIdentifier: String?`、`availableFrom: Date?`、`availableUntil: Date?`、`graduationYear: Int?`
- 技能不带熟练度；存技能词典的 canonical 名称（不是 `SkillID`）；`MatchingEngine` 计算时解析为 `SkillID`。等级/权重由 [匹配算法与技能词典](02-matching-engine.md) 的技能词典和规则处理。
- 不与其它实体建关系；匹配时按需读取。

### 6. 派生值（不落库）

- `MatchResult`：`MatchingEngine(UserProfile, JobPosting, SkillDictionary)` 现算。
- `appliedAt`：第一条 `toStatus == applied` 的 `StatusChange`。
- 截止提醒：`Application.deadline` + 提醒策略派生（提醒策略见 [截止与面试提醒策略](10-reminder-policy.md)）。
- 仪表盘计数 / 最近更新 / 漏斗：查询 `Application` / `StatusChange` 现算；漏斗为 P1，不在 v1 验收线。
- `Application.status` 是唯一「可派生但故意冗余存」的字段，用于筛选/计数；`StatusChange` 为事实源。

### 7. SwiftData 边界与迁移

- 5 个 `@Model final class`：`Application`、`JobPosting`、`InterviewRound`、`StatusChange`、`UserProfile`。
- 枚举存 raw String + computed enum（如 `statusRaw: String` + `var status: ApplicationStatus`）；过滤/排序用 raw 字段，computed 枚举不用于 `#Predicate` / `SortDescriptor`。raw value 显式写死。
- 从第一天用 `VersionedSchema`（SchemaV1），预留 `SchemaMigrationPlan`；v1.x 只做轻量迁移（加可选字段/新模型），不做破坏性修改；破坏性变更允许清库 + 明确提示。
- 所有实体显式 `id: UUID`；`JobPosting.identityKey` 唯一（upsert）。
- `UserProfile` 单例由 repository fetch-or-create 保证。
- 关系显式写 `inverse`；cascade / nullify 如上。
- 日期存绝对 `Date`，展示本地时区；deadline 按上述 HH:mm 语义。
- to-many 不保序：`InterviewRound` 按 `scheduledAt`、`StatusChange` 按 `changedAt` 排序，同时间用 id 兜底；v1 不加额外 `sortIndex`。
- 数据只在本机，不做 CloudKit / 多设备；不做 schema 回滚。

### 8. 交给后续 ticket

- 匹配算法、技能词典、权重、`MatchResult` 结构 → [匹配算法与技能词典](02-matching-engine.md)。
- 分层、`JobSource` / `JobRepository` 协议、依赖注入 → [混合架构与 JobSource 抽象](04-architecture.md)。
- 提醒时机、文案、通知权限 → [截止与面试提醒策略](10-reminder-policy.md)（本 ticket 新拆出）。
- 排期、测试、演示 → [30 天排期、测试与演示方案](06-schedule-demo.md)。

### 9. 与 ticket 02 的对齐

- ticket 02 的交接写 `UserProfile.skills` 用 `[SkillID]`；本 ticket 定稿为 `[String]`（技能词典的 canonical 名称），`MatchingEngine` 计算时解析为 `SkillID`。`MatchResult.matchedSkills` / `missingSkills` 仍用 `[SkillID]`。
