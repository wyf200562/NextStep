# NextStep v1 规格

Status: ready-for-agent
日期：2026-11-08

## Problem Statement

iOS 实习求职者同时面对两个割裂的问题：一是投递进度散落在备忘录、表格和聊天里，截止日期和面试时间容易漏，改状态、记面试轮次、回顾时间线都要手工维护；二是招聘平台只给岗位列表，不解释「我匹配了什么、还缺什么、为什么是这个分数」，而公开岗位 API（Remotive）又只提供每日小样本，实习岗位可能为 0。

现有工具要么只记账不解释匹配，要么只聚合岗位不追踪投递；求职者需要在多个工具之间搬运信息，既容易遗漏，也无法在面试前快速判断「这份岗位值不值得投」。

## Solution

NextStep 是一个 SwiftUI 为主、SwiftData 持久化的 iOS App，把「申请追踪」和「可解释的岗位匹配」放进同一个本机 App：

- **申请追踪**：5 个领域模型（Application、JobPosting、InterviewRound、StatusChange、UserProfile）和七态状态机，支持 Application 完整 CRUD、状态流转与历史、截止日期、面试轮次。
- **行动优先的概览**：独立「概览」tab，首屏回答「今天和接下来 7 天要做什么」，辅以进行中 / 7 天内截止 / Offer 三个计数和最近更新。
- **岗位发现**：从 Remotive 公共 API 拉取每日样本，缓存优先、滚动 24 小时最多 4 次网络尝试；也支持手动粘贴 JD，作为实习岗位的主要兜底。
- **本地可解释匹配**：自建中英技能词典 + 规则加权，输出分数、匹配/缺失技能、四项分项、一句话原因和 eligibility；不依赖 LLM、embedding 或 NLTokenizer，确定性、可测试。
- **工程展示点**：单 target 分层、统一 JobSource/JobPostingDraft/JobRepository 摄入缝、MVVM 为主 + 一个 UIKit/MVC 状态历史页、Swift Testing 单测。

所有数据只在本机；断网/限流/解码失败有缓存兜底和可见错误；演示数据使用虚构公司/虚构 JD，Remotive 数据保留署名和原岗位回链。

## User Stories

### 首次使用与画像

1. 作为首次打开 NextStep 的求职者，我想看到清楚的空状态和「添加第一份申请」「去 Discover 看看」两个入口，以便马上知道下一步做什么。
2. 作为没有数据的求职者，我想空状态不出现 1/2/3 步骤说明，以便界面保持简洁、不把我当新手教程。
3. 作为求职者，我想编辑技能、目标方向、地点/时区、可实习时间和毕业年份，以便匹配结果反映我的真实情况。
4. 作为求职者，我想从技能词典中多选中英文技能，以便不用手打、不会因为同义词写法不同而漏匹配。
5. 作为求职者，我想用自由文本添加目标方向和偏好地点，以便表达「iOS 开发实习」「移动端」这类具体方向。
6. 作为画像不完整的求职者，我想仍然能浏览和导入岗位，只是看到「完善画像后查看匹配」，以便不被表单挡住。
7. 作为画像不完整的求职者，我想看到还缺什么（目标方向 / 3 个技能），以便快速补全。
8. 作为求职者，我想保存空画像而不被硬性阻塞，以便先记录其他信息、之后再补技能。

### 申请追踪

9. 作为求职者，我想手动新建申请（公司、职位、初始状态、截止、链接、地点、备注），以便记录任何渠道的投递。
10. 作为求职者，我想从岗位详情一键导入为 Application，以便不重复录入公司、职位和链接。
11. 作为求职者，我想在导入时发现已有进行中的申请并被提示打开已有记录，以便避免重复创建。
12. 作为求职者，我想编辑申请的公司、职位、链接、地点和备注快照，以便信息保持准确。
13. 作为求职者，我想删除申请并二次确认，以便清理错误记录且不误删。
14. 作为求职者，我想按全部 / 进行中 / 临近截止 / Offer / 已结束筛选申请列表，以便快速定位。
15. 作为求职者，我想申请列表默认按最近节点排序、已结束按最近更新排序，以便先看到最需要行动的记录。
16. 作为求职者，我想在详情里把状态改为合法的下一个状态（允许跳级），以便匹配真实招聘流程。
17. 作为求职者，我想在回退到更早状态时二次确认，以便避免误操作。
18. 作为求职者，我想把 rejected / withdrawn 显式「重新打开」到合适状态，以便记录 HR 捞回或重新投递。
19. 作为求职者，我想 offer 作为成功终态且不能误改，以便保护最终结果。
20. 作为求职者，我想每次状态变化自动写入 StatusChange，以便随时回顾时间线。
21. 作为求职者，我想在状态变化时填写可选备注，以便记录原因。
22. 作为求职者，我想打开状态历史页查看每次 from → to、时间和备注，以便了解申请经历了什么。
23. 作为求职者，我想给申请设置截止日期和可选时刻，以便知道下一个关键节点。
24. 作为求职者，我想添加、编辑、删除面试轮次（时间、形式、联系人、备注、结果），以便管理面试。
25. 作为求职者，我想在添加未来面试轮次时被询问是否标记为「面试中」（仅在状态转换合法时），以便状态跟上进度。
26. 作为求职者，我想某轮面试失败不会自动把申请标为 rejected，以便自己决定最终状态。
27. 作为求职者，我想在申请详情看到关联岗位的摘要、来源和紧凑匹配摘要，以便快速回顾为什么投它。
28. 作为求职者，我想申请的公司/职位/链接/地点保存为快照，即使关联的 JobPosting 不存在也不影响显示，以便数据长期可用。

### 概览

29. 作为求职者，我想在概览看到「今天」和「接下来 7 天」的截止与面试事件，以便知道现在要做什么。
30. 作为求职者，我想点击事件进入申请详情，以便直接处理。
31. 作为求职者，我想看到进行中 / 7 天内截止 / Offer 三个进展计数，并能点进对应筛选列表，以便了解整体进展。
32. 作为求职者，我想看到最近更新的申请清单，以便回到最近在处理的记录。
33. 作为求职者，我想首屏优先展示行动事件、计数压缩成一行，以便不被统计图挤占注意力。
34. 作为求职者，我想在 7 天内没有事件时看到轻量提示，以便确认不是加载失败。
35. 作为求职者，我想在没有申请时看到「添加第一份申请」和「去 Discover 看看」，以便开始第一条记录。

### 岗位发现与匹配

36. 作为求职者，我想 Discover 先显示本地缓存、再在后台刷新，以便快速看到内容。
37. 作为求职者，我想看到常驻的样本模式说明（来源、本机样本条数、其中实习数、手动导入数），以便不把每日样本误认为全量岗位。
38. 作为求职者，我想看到上次成功刷新时间和刷新失败/配额用完的非阻塞提示，以便知道数据新旧。
39. 作为求职者，我想在断网、超时、限流、服务端错误或解码失败时看到中文错误和重试按钮，并且有缓存时继续浏览，以便不被打断。
40. 作为求职者，我想在没有缓存且刷新失败时看到全屏错误、重试和「粘贴 JD」，以便还有兜底路径。
41. 作为求职者，我想下拉刷新但不超过 Remotive 的每日配额和最小间隔，以便尊重数据源限制。
42. 作为求职者，我想看到「适合你」的岗位按匹配分降序排列，带分数 pill、技能标签和一句话原因，以便快速筛选。
43. 作为求职者，我想看到「不符合条件」的岗位单独分组、默认只显示前 4 条、可展开，并标出不符合原因和技能命中数，以便理解为什么不符合但不被隐藏。
44. 作为求职者，我想在岗位详情看到分数、匹配/缺失技能、四项分项、一句话原因和 JD 高亮，以便理解分数怎么来的。
45. 作为求职者，我想在不符合岗位的详情看到不符合原因和技能匹配，而不是一个假的 0 分，以便判断是否仍值得投。
46. 作为求职者，我想用「只看实习」开关过滤当前列表，以便只看实习岗位；这个开关只影响显示，不影响匹配算法。
47. 作为求职者，我想在「只看实习」没有结果时看到「今天的样本里没有实习」的解释、粘贴 JD 和查看全部样本入口，以便知道不是加载失败。
48. 作为求职者，我想看到 Remotive 署名和原岗位回链，以便合规并能去原站申请。
49. 作为求职者，我想从岗位详情「导入为申请」，以便开始追踪。
50. 作为求职者，我想手动粘贴 JD（标题、公司、正文、地点、链接、岗位类型、标签），以便覆盖 Remotive 没有的实习岗位。
51. 作为求职者，我想手动导入不消耗 Remotive 配额，以便随时补充岗位。
52. 作为求职者，我想手动导入后立即看到匹配结果，以便判断是否投递。
53. 作为求职者，我想在描述为空或未识别到技能时看到低置信度标记和说明，以便知道分数不可靠。
54. 作为求职者，我想在画像不足时仍能浏览岗位并看到「完善画像后查看匹配」，以便先看岗位再补画像。
55. 作为求职者，我想匹配完全在本地、确定性计算，以便结果可解释、可测试、不依赖网络或 API 成本。
56. 作为求职者，我想同一岗位在多次刷新后更新而不是重复出现，以便列表保持干净。

### 数据、恢复与质量

57. 作为求职者，我想杀进程重启后申请、状态历史、面试轮次、画像和岗位缓存仍然存在，以便放心使用。
58. 作为求职者，我想删除申请时面试轮次和状态历史一起删除，但 JobPosting 缓存保留，以便数据一致。
59. 作为求职者，我想单一用户画像由 App 自动 fetch-or-create，以便不需要管理账号或多份画像。
60. 作为演示者，我想在 Debug 构建里清空本地演示数据，以便现场可重复走黄金路径。
61. 作为中文用户，我想所有界面文案和错误提示是中文，以便理解。
62. 作为面试官/仓库访客，我想中文 README 说明功能、架构、取舍、运行方式、测试命令和 Remotive 合规声明，以便评估项目。
63. 作为开发者，我想核心逻辑有 Swift Testing 单测且测试不联网、不依赖 UI，以便每次改动都能本地验证。

## Implementation Decisions

### 1. 产品形态与导航

- 底部 4 个 tab：**概览**、**申请**、**发现**（页面标题使用 `Discover`）、**我的**。
- 每个 tab 独立 `NavigationStack` + typed destination；跨 tab 导航由 App 层的小型 `AppRouter`（`@Observable`，只持有选中 tab 和待处理路由，不是 ViewModel）协调：
  - 概览空状态「去 Discover 看看」→ 切到「发现」tab。
  - 概览的事件行、最近更新行 → 切到「申请」tab 并 push Application 详情。
  - 概览三个计数 → 切到「申请」tab 并带对应筛选。
  - Discover 的「去完善画像」→ 切到「我的」tab。
  - Discover 导入成功 → 切到「申请」tab 并 push 新 Application 详情。
  - Discover 的「查看已有申请」→ 切到「申请」tab 并 push 已有 Application 详情。
- 部署目标沿用现有工程的 iOS 27.0，使用 Xcode 27；不使用第三方依赖。
- UI 默认中文；品牌细节（图标、配色、语气）不阻塞实现，先使用系统语义色和 SF Symbols。

### 2. 领域模型与 SwiftData

v1 只有 5 个 `@Model final class`，均带显式 `id: UUID`。枚举一律存 raw String + computed enum，raw value 显式写死，过滤/排序使用 raw 字段。

**Application**

- 必填：`id`、`companyName`、`roleTitle`、`status`（默认 `.wishlist`）、`createdAt`、`lastModifiedAt`。
- 可选：`jobPosting`（to-one）、`deadline: Date?`、`notes: String?`、`jobURL: URL?`、`location: String?`。
- 关系：`interviewRounds`、`statusChanges` 均为 to-many inverse；删除 Application cascade 删除两者。
- 快照字段：`companyName`、`roleTitle`、`jobURL`、`location`；列表/详情不依赖 JobPosting 是否还在。
- 不存 `appliedAt`，派生规则见下。
- `lastModifiedAt` 在备注、deadline、轮次、状态等任何编辑时更新。
- `deadline` 语义：下一个关键节点时间（投递、OA、offer 回复等），日期 + 可选 HH:mm；不填时刻默认当天 09:00；面试时间只放 InterviewRound。

**JobPosting**

- 必填：`id`、`title`、`companyName`、`intakeMethod: JobIntakeMethod`、`descriptionPlainText`、`createdAt`、`identityKey`。
- 可选：`externalJobID`、`jobURL`、`location`、`jobType`、`tags: [String]`、`publishedAt`、`salary`、`companyLogoURL`。
- `intakeMethod` 枚举：`.remotive`、`.manual`；未来预留 `.url`。
- `identityKey` 唯一（`@Attribute(.unique)`），格式 `"remotive:<id>"` / `"manual:<uuid>"`；用于刷新时 upsert 去重，不同于本机主键 `id`。
- `applications` 为 to-many inverse；删除 JobPosting 时 Application 的关联置空（nullify），不影响 Application 快照。
- 不存 `fetchedAt`；刷新时间由 JobRepository 的 RefreshLedger 提供。

**InterviewRound**

- 必填：`id`、`scheduledAt: Date`、`format: InterviewFormat`。
- 可选：`label`、`contact`、`notes`。
- `result: InterviewResult`，默认 `.pending`。
- OA/笔试不记入 InterviewRound；OA 的时间点由 StatusChange 提供。
- 轮次不自动改 Application 状态；某轮 failed 不自动 rejected。
- 按 `scheduledAt` 排序，同时间用 `id` 兜底（to-many 不保序）。

**StatusChange**

- 必填：`id`、`toStatus`、`changedAt`；`fromStatus: ApplicationStatus?` 初始记录为 nil；可选 `note`；`application` 反向关系。
- append-only；只记录状态转换，不记录备注/截止/轮次修改。
- 创建 Application 时写初始记录：`fromStatus = nil`、`toStatus = 初始状态`；初始 `changedAt` 可补录为过去日期。
- `Application.status` 故意冗余存当前状态，用于筛选/计数；StatusChange 是历史事实源，两者由 repository 在同一次操作更新。
- 派生 `appliedAt` = 第一条 `toStatus == applied` 的 `changedAt`；若初始记录直接为 applied，则取初始记录。按 `changedAt` 排序，同时间用 `id` 兜底。

**UserProfile（单例）**

- 必填：`id`、`skills: [String]`、`targetRoles: [String]`；允许空数组，不阻塞保存。
- 可选：`preferredLocations: [String]`、`timeZoneIdentifier: String?`、`availableFrom: Date?`、`availableUntil: Date?`、`graduationYear: Int?`。
- `skills` 存技能词典的 canonical 名称（不是 SkillID），不带熟练度；匹配计算时解析为 SkillID。
- 不与其它实体建关系；由 repository fetch-or-create 保证单例。
- 新建默认 `timeZoneIdentifier = TimeZone.current.identifier`，其余为空。

**状态机**

状态 raw value：`wishlist`、`applied`、`oa`、`interview`、`offer`、`rejected`、`withdrawn`；UI 显示「想投、已投、OA/笔试、面试、Offer、已拒、已撤」。

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

- `offer` 是成功终态，不可离开；拒 offer 用备注记录，v1 不建 `offerResponse`。
- `rejected` → `applied` / `oa` / `interview` / `offer`（→ offer 覆盖「HR 捞回」）。
- `withdrawn` → `wishlist` / `applied` / `oa` / `interview` / `offer`。
- 普通转换不能进入/离开终态；重新打开必须写 StatusChange，并二次确认。
- 活动态之间的回退需二次确认，照常写 StatusChange。
- 每次状态变化写一条 StatusChange；非法转换由状态机拒绝并抛 typed error。

**SwiftData 边界与迁移**

- 从第一天使用 `VersionedSchema` V1，并预留 `SchemaMigrationPlan`。
- v1.x 只做轻量迁移（加可选字段/新模型）；破坏性变更允许清库 + 明确提示。
- 所有关系显式写 `inverse`；cascade / nullify 如上。
- 日期存绝对 `Date`，展示本地时区；deadline 按上述 HH:mm 语义。
- 主线程单 `ModelContext`，repository `@MainActor`；测试/Preview 使用 `isStoredInMemoryOnly`；v1 不做 `ModelActor`/后台 context。
- 派生值不落库：MatchResult、appliedAt、仪表盘事件/计数/最近更新、漏斗（P1）。
- 若 ModelContainer 创建失败，显示阻塞式「本地数据无法打开」错误页 + 重试；Debug 构建额外提供清空本地数据入口。

### 3. 申请追踪

**申请列表**

- 只读页面：SwiftData `@Query` + `@State` 筛选，不配 ViewModel。
- 筛选：全部 / 进行中 / 临近截止 / Offer / 已结束。
  - 进行中 = wishlist、applied、oa、interview。
  - 临近截止 = 有 deadline 或 pending 面试落在今天起 7 天内，且状态不是 rejected/withdrawn（offer 的答复截止也算）。
  - Offer = offer；已结束 = rejected、withdrawn。
- 排序：
  - 全部 / 进行中 / 临近截止：最近 upcoming 节点（deadline 或 pending InterviewRound.scheduledAt）升序；没有 upcoming 节点的排在后面，按 `lastModifiedAt` 降序；同时间用 `id` 兜底。
  - Offer / 已结束：`lastModifiedAt` 降序，同时间用 `id` 兜底。
- 行内容：公司、职位、状态徽标、最近节点（截止/面试 + 日期）、最近更新时间；点击进详情。
- 顶部显示「N 份申请 · M 份进行中」的紧凑摘要；空列表按筛选显示对应空状态，并提供「添加第一份申请」「去 Discover 看看」。
- 不做全文搜索、不做自定义排序控件（v1）。

**新建 / 编辑**

- 有表单校验和多步保存，使用 `ApplicationEditorViewModel`（`@Observable @MainActor`）。
- 新建字段：公司*、职位*、初始状态（默认 wishlist）、状态日期（仅初始状态非 wishlist 时显示，默认今天，可补录过去）、截止日期 + 可选时刻（默认 09:00）、岗位链接、地点、备注。
- 编辑字段：公司、职位、岗位链接、地点、备注、截止日期/时刻；状态不在编辑器中修改，必须走详情页状态流转，确保状态机与历史一致。
- 公司、职位 trim 后非空；岗位链接必须是合法 URL（若填写）；校验失败内联显示。
- 初始状态允许选择全部 7 个状态（用于补录历史）；初始记录写入 StatusChange，`changedAt` 用状态日期。
- v1 编辑器不提供「选择已有 JobPosting」的关联选择器；关联只通过从岗位详情导入建立，纯手动申请不关联 JobPosting。
- 保存成功返回详情；放弃未保存修改时二次确认。

**申请详情**

- 有状态流转、轮次、截止和错误处理，使用 `ApplicationDetailViewModel`。
- 结构：头部（公司/职位/状态/最近更新）、下一个节点卡片（截止或最近的 pending 面试）、面试轮次、备注、关联岗位摘要、匹配摘要（若有关联 JobPosting）、状态历史按钮。
- 工具栏：编辑、删除（二次确认；cascade 删除轮次和状态历史，JobPosting 保留）。
- 状态变更入口打开 sheet，只列出状态机允许的目标状态；可选备注；回退和重新打开额外确认。
- 关联岗位摘要显示标题、公司、来源（Remotive/手动导入）、原岗位链接；匹配摘要通过 MatchService 现算，不持久化；画像不足或词典不可用时隐藏匹配摘要并显示提示。
- 任何编辑都更新 `lastModifiedAt`；删除后返回列表。

**面试轮次**

- 详情内可添加/编辑/删除轮次，表单字段：时间*（日期 + 时刻）、形式*（电话/视频/现场/其他）、名称（如「一面」「HR 面」）、联系人、备注、结果（待定/通过/未通过/取消，默认待定）。
- 添加未来轮次后，若当前状态是 applied 或 oa，弹出「是否标记为面试中？」；确认则走合法状态转换到 interview；wishlist 不允许直接到 interview，不弹提示；interview/offer 不弹；rejected/withdrawn 不自动重开。
- 编辑轮次或结果只更新 Application.lastModifiedAt，不自动改状态。
- 轮次按 `scheduledAt` 升序展示，过去的轮次弱化显示；同时间用 `id` 兜底。

**状态历史（UIKit/MVC）**

- 唯一 UIKit 页面：申请详情的「状态历史」，从 SwiftUI 以 sheet 打开，内部套 `UINavigationController`。
- `StatusHistoryViewController` 持有 table view + `UITableViewDiffableDataSource`；注入 `ApplicationRepository` 和 `applicationID`；**没有 ViewModel**。
- `viewDidLoad` 取 StatusChange，按 `changedAt` 降序、同时间 `id` 兜底；row 显示 from → to、时间、备注；初始记录（from == nil）显示「创建 → X」；cell 只负责展示，格式化用纯 helper。
- 空状态「还没有状态记录」；错误状态显示「加载失败」+ 重试；导航栏 Done 关闭。
- 不在页面内编辑状态；状态变化后重新打开会重新拉取。

**申请仓库**

`ApplicationRepository`（`@MainActor`，协议 + SwiftData 实现）是申请写的唯一入口：

- 创建申请并写初始 StatusChange；保存；
- 修改快照字段/备注/截止并更新 `lastModifiedAt`；
- 删除申请（cascade）；
- `changeStatus(of:to:note:at:)`：调用 `ApplicationStateMachine` 校验，更新 `Application.status` + `lastModifiedAt`，写 StatusChange；
- 添加/编辑/删除 InterviewRound，并更新 `lastModifiedAt`；
- 按 application 读取 StatusChange（供 UIKit 页）；
- 按 JobPosting 读取所有 Application（供导入去重）。
- 状态机拒绝非法转换时抛 typed error，UI 映射为「当前状态不能这样变更」。

**状态机模块**

- 纯结构/函数，无 I/O：`allowedTransitions(from:)`、`isValidTransition(from:to:)`、`reopenTargets(from:)`、`requiresConfirmation(from:to:)`。
- `requiresConfirmation` 对活动态回退和 reopened 返回 true；offer 无出口。
- 创建初始记录、跳级、回退、重新打开都由同一套规则驱动，UI 不复制转换表。

### 4. 概览

- 只读页面：`@Query` + 纯 `DashboardBuilder`，不配 ViewModel。
- `DashboardBuilder` 接收所有 Application（含 relationships）、`now`、`Calendar`，输出：
  - `todayEvents`：今天 00:00–24:00 内的截止和 pending 面试；已过去的今天事件仍显示并标「已过」。
  - `upcomingEvents`：明天起 7 天内的事件（即今天 + 1…今天 + 7）。
  - `activeCount`、`dueSoonCount`、`offerCount`。
  - `recentApplications`：全部状态按 `lastModifiedAt` 降序取前 5，同时间 `id` 兜底。
- 事件来源：
  - `Application.deadline`，且状态不是 rejected/withdrawn（offer 的答复截止也算）。
  - `InterviewRound.scheduledAt`，且 `result == .pending`、Application 状态不是 rejected/withdrawn。
  - 两个来源合并后按时间升序；同时间先按 `application.id`，再按 deadline 先于 interview，最后按轮次 `id` 兜底；面试事件标题带轮次 label。
- `dueSoonCount` 按去重后的 Application 数量计算，不是事件数；窗口为今天起 7 天。
- 首屏结构（变体 A）：
  - 日期 overline + 大标题「概览」；
  - 「今天」事件列表；
  - 「接下来 7 天」事件列表；
  - 一行三个计数：进行中 / 7 天内截止 / Offer；
  - 「最近更新」清单；
  - 无事件时显示「7 天内没有截止或面试。去 Discover 看看新岗位。」
- 空状态：英雄区 +「添加第一份申请」/「去 Discover 看看」，不放 1/2/3 步骤。
- 计数点击：进行中 → 申请 tab 的进行中筛选；7 天内截止 → 临近截止筛选；Offer → Offer 筛选。
- 不做状态分布图、漏斗、环形图；这些留 P1。

### 5. 用户画像

- 「我的」tab 是有表单校验和多步操作的页面，使用 `ProfileViewModel`（`@Observable @MainActor`）。
- 表单字段：目标方向（自由文本 chips）、技能（从词典多选，带搜索、按分类分组）、偏好地点（自由文本 chips）、时区（默认当前时区，可从常见时区列表选择）、可实习时间（from/until，可选）、毕业年份（可选）。
- 编辑使用 draft，点「保存」才写回 UserProfile；返回时有未保存修改则二次确认。保存不硬性阻塞空字段。
- 技能选择存 canonical 名称；去重；显示已选数量；技能少于 3 个时显示提示「再选 N 个技能后才会计算匹配」。
- 目标方向为空时提示「填写目标方向后才会计算匹配」。
- 技能选择器需要词典；词典不可用时禁用选择并显示「技能词典暂不可用」，其他字段仍可保存。
- 「我的」还包含「关于」区块：版本号、Remotive 数据来源声明、GitHub 链接；Debug 构建额外显示「清空演示数据」。
- 时区、可实习时间、毕业年份在 v1 只展示，不参与计分。

### 6. 匹配

**总原则**

- 本地、确定性、可解释、可测试；TF-IDF / embedding / LLM 不作为主分，不依赖网络。
- 匹配是派生数据：不写入 Application / JobPosting，每次读取时重算。
- `MatchingEngine` 是 `Domain` 下的纯 `struct`：无 I/O、无 ModelContext、无单例、`Sendable`；只依赖传入的 `UserProfile`、`JobPosting`、`SkillDictionary` 和辅助词典。
- 薄 `MatchService`（`@MainActor`，协议 `MatchProviding`）负责读 UserProfile、执行画像门槛、调用引擎，暴露 `evaluate(job:)` / `evaluate(jobs:)`；Discover/JobDetail/ApplicationDetail 只调它。

**技能词典**

- 约 50 条核心 + 15 条可选，数据驱动 JSON；字段 `id / name / aliases[] / category`。
- 覆盖 iOS/Swift 核心、架构、数据、并发、网络、测试、工具、CS 基础、发布/平台；不收软技能。
- 每条配中英文别名；别名统一小写；英文词边界匹配，中文最长子串匹配。
- 不收录 1–2 个字母的歧义别名（`go`、`js`、`os`、`rn`、`fp`、`c`）；`C++` 可以；`OC` 只按独立 token 匹配。
- v1 不建独立 Skill 实体，不做 `parents` / 技能蕴含。
- 词典加载：
  - 缺失必填字段或重复 `id` → 加载失败，匹配功能降级为「暂不可用」（浏览/追踪/导入仍可用）。
  - 跨技能重复别名 → 按词典顺序 first-wins + debug log。
  - 未知字段忽略。
- `UserProfile.skills` 的 canonical 名称解析时大小写不敏感；未知名称忽略 + debug log。

**方向与地点辅助词典**

- 为把「明确其他方向」「地点明确不可行」落成可测试规则，增加两个小型 bundle 资源：
  - `RoleDirectionLexicon`：方向家族（ios/mobile、android、backend、frontend/web、data/ml/ai、qa/test、algorithm、product、design、devops、security、embedded、game 等）→ 中英文别名。
  - `LocationLexicon`：常见国家/地区/区域的中英文别名（中国/China、亚洲/Asia、欧洲/Europe、美国/US/USA、英国/UK、加拿大、印度、日本、新加坡等）。
- 两个词典与技能词典一起加载为只读值类型；加载失败时匹配降级。它们不是领域实体。

**匹配管线**

1. **归一化**：NFKC 全半角、大小写折叠、去 HTML、标点/空白归一；保留原文用于展示。
2. **词典扫描**：别名按长度从长到短；英文用词边界（避免 `Swift` 命中 `SwiftUI`）；中文用子串/最长匹配；记录命中的字段（title / tags / description）和别名。
3. **汇总**：岗位命中的技能集合 = requiredSkills；画像也有的 = matchedSkills；岗位有但画像没有 = missingSkills。
4. **不做**：NLTokenizer、否定词、必备/加分区分、自由文本技能、软技能。
5. **输出**：MatchResult。

**评分**

| 维度 | 权重 | 规则 |
|---|---:|---|
| 技能覆盖 | 60 | `round(60 * matched / required)`；所有技能提及等权；`required == 0` 时技能分 0 且低置信度 |
| 方向 | 20 | 目标方向命中标题/标签 20；仅描述命中 15；明确命中其他方向 0；未知 10 |
| 地点 | 10 | 全球/用户所在区域 10；未知 5；明确不包含用户区域 → ineligible（组件 0，不展示总分）；远程岗位不因城市扣分 |
| 岗位类型 | 10 | internship 10；未知 5；full_time / contract / freelance / part_time 0 且 ineligible |

- **总分**：四项之和，0–100。分档 ≥75 强匹配 / 50–74 可尝试 / <50 低匹配。
- **低置信度**：描述为空或未识别到任何技能时，`confidence = .low`，技能分乘 0.5 后取整；分数带 `*`，UI 显示「低置信度 / 信息不足」。如果描述为空但标题/标签仍识别到技能，技能分同样减半。
- **方向规则**：
  - 先把每个 TargetRole 映射到 `RoleDirectionLexicon` 的方向家族；若映射不到，退化为对 TargetRole 的字面字符串 + 拉丁 token 匹配。
  - 目标家族命中标题/标签 → 20；仅命中描述 → 15。
  - 目标家族未命中，但标题/标签命中其他方向家族 → 0。
  - 都未命中 → 10。
  - 目标方向和其他方向同时命中标题/标签时，目标方向优先（20）。
- **地点规则**：
  - 用户地点关键词 = `preferredLocations` + 时区标识拆分出的区域/城市（如 `Asia/Shanghai` → Asia、Shanghai）。
  - 岗位地点含 worldwide / anywhere / global / 远程且无区域限制 → 10。
  - 岗位地点含区域关键词：命中用户关键词 → 10；用户有关键词但明确不命中 → ineligible（地点不符）；用户没有任何地点关键词 → 5。
  - 地点为空或无法识别 → 5。
- **岗位类型规则**：
  - 明确 `internship` → 10；标题含 intern / 实习且 job_type 缺失 → internship。
  - 明确 full_time / contract / freelance / part_time → 0 + ineligible（非实习）。
  - 其他或缺失且标题无 intern/实习 → 5（未知，不 ineligible）。
- **ineligible**：`job_type` 明确非实习，或地点明确不可行。`score = nil`、`band = nil`；仍计算 matched/missing 和组件，但 UI 不展示总分；岗位仍展示，排在 eligible 之后，不给假 0 分。
- 可实习时间、毕业年份只展示，不计分；必备/加分 v1 等权。

**MatchResult（来自匹配设计定稿）**

```swift
struct MatchResult {
    let score: Int?                  // ineligible 时为 nil
    let band: MatchBand?             // strong / medium / low；ineligible 时为 nil
    let matchedSkills: [SkillID]
    let missingSkills: [SkillID]
    let components: MatchComponents  // skills / direction / location / jobType
    let eligibility: Eligibility     // .eligible | .ineligible(reason)
    let confidence: Confidence       // .high | .low
    let reason: String               // 模板生成的一句话
    let evidence: [SkillEvidence]    // skillID + field + matchedAlias
}
```

- `SkillID` 是词典 id（`String`）；`SkillEvidence.field` 至少记录 `title / tags / description`；字符范围留 P1。
- 一句话原因由模板生成，不手写，例如：「匹配 6/8 项技能；缺少 Combine、SwiftData；远程全球，实习岗位。」
- ineligible 原因示例：「岗位不符合：非实习（全职）、地点不符（Europe）；技能匹配 2/6。」
- UI 不持久化 MatchResult；Application 详情如需展示，重新计算。

**画像门槛与降级**

- 门槛：至少 3 个能解析到词典的画像技能 + 至少 1 个 TargetRole；否则 `MatchResult = nil`，UI 显示「完善画像后查看匹配」，岗位仍可浏览和导入。
- 画像不足时仍按 eligibility 分组（job type 和地点规则不依赖画像技能）；eligible 组不显示分数，显示「完善画像后查看匹配」；ineligible 组只显示原因，不显示技能命中数。若用户没设置地点且岗位地点无法判断，按未知处理，不标 ineligible。「只看实习」仍可用。
- 词典加载失败 → 匹配降级为「暂不可用」，浏览/追踪/导入不受影响。
- 150 条岗位在主线程计算；若 profiling 有卡顿再移到后台（P1），不预先优化。

**匹配展示（变体 A）**

- **列表卡片**：分数 pill（ineligible 显示「不符合」，低置信度带 `*`）+ band + 「匹配 X/Y」+ 前 3 个匹配技能标签 + 前 2 个缺失技能标签 + `+N` + 一句原因（最多两行）。
- **详情**：分数 hero、匹配标签、缺失标签、四项分项条（技能 60 / 方向 20 / 地点 10 / 岗位类型 10）、一句话原因、JD 高亮；ineligible 没有分数 hero 和分项条，只保留不符合原因 + 技能匹配解释；低置信度 banner；画像不足显示 gate +「去完善画像」。
- **JD 高亮**：按技能别名在纯文本 JD 中做非重叠、最长优先匹配；matched 绿色、missing 红色；只用于详情，不持久化。
- UI 术语叫「技能标签」，Swift 类型 `SkillTag` / `SkillTagView`；不用 `SkillLabel`（与 SwiftUI `Label` 冲突）、不用 `Chip`。

### 7. 岗位摄入与 JobRepository

**统一协议**

- 所有来源（Remotive、手动粘贴、未来 URL 导入）都 conform `JobSource`：
  - `var intakeMethod: JobIntakeMethod { get }`
  - `func loadJobs() async throws -> [JobPostingDraft]`
- `JobSourceFactory` 按输入创建来源：`makeRemote(JobQuery)`、`makeManual(ManualJobInput)`。
- `JobPostingDraft` 是非持久化值类型，字段与 JobPosting 的必填/可选字段对齐，去掉本机主键 `id`、`createdAt` 和关系；`identityKey` 由来源生成，`id` 由 Repository 在插入时生成。
- 归一化（trim、HTML→纯文本、日期解析）在来源侧完成；Repository 只信任 draft。
- `JobRepository` 是唯一持久化写入口；UI 和匹配不直接碰来源。

**JobRepository**

`@MainActor`，协议 + SwiftData 实现：

- `cachedJobs() throws -> [JobPosting]`：按 `createdAt` 降序、同时间 `id` 兜底。
- `refreshDiscover(query: JobQuery) async -> RefreshOutcome`：用 `makeRemote` 拉取，upsert。
- `importManual(_ input: ManualJobInput) async throws -> JobPosting`：用 `makeManual` 拉取，upsert 单条。
- `lastRefreshAt(for source: JobIntakeMethod) -> Date?`：最近一次**成功**刷新时间，用于「更新于」和 6 小时 TTL。
- `RefreshOutcome`：
  - `.refreshed(added: Int, updated: Int)`
  - `.skipped(reason: .fresh / .quotaExhausted / .tooSoon)`
  - `.failed(error: Error, cachedCount: Int)`
- `updated` 的语义是「本次刷新 touch 到的已有 identityKey 数量」，不只字段变化的行；因此 `added + updated` 等于本次返回的 draft 数量。
- 错误：`JobSourceError` 为 `.invalidInput / .offline / .timedOut / .rateLimited / .server(Int) / .decoding`；`CancellationError` 单独处理、不展示；Repository 不产出用户文案。
- 持久化失败映射为通用刷新失败/保存失败，由 ViewModel 显示中文。

**刷新节流**

- 按来源维护 `RefreshLedger`；未来 URL 源有独立配额。
- 滚动 24 小时最多 4 次**网络尝试**；成功、失败、超时、离线、解码失败都算；一次尝试在发起时记账（包括随后被取消的请求，保守处理）。
- 两次尝试至少间隔 60 秒；ledger 持久化到 UserDefaults（测试注入临时 suite）。
- 自动刷新 TTL 6 小时，以最近一次成功刷新为准；下拉刷新可以忽略 TTL，但仍受 4 次/24h 和 60 秒限制。
- `.skipped(.fresh)` 由 ViewModel 在调用 repository 前根据 `lastRefreshAt` 判断；repository 负责 `.tooSoon` / `.quotaExhausted`。
- 手动导入不计入 Remotive 配额，不写 ledger。
- 不做后台刷新。

**缓存与离线**

- 先读缓存再刷新；有缓存时刷新失败/跳过不阻塞列表。
- 有缓存 + 失败/配额 → 列表 + 琥珀色非阻塞提示 + 重试。
- 无缓存 + 失败/配额 → 全屏错误 + 重试 + 粘贴 JD。
- `identityKey` upsert；不自动删除旧岗位（可能已被 Application 关联；30 天数据量小）；不做分页/淘汰。
- JobPosting 不存 `fetchedAt`；「更新于」用 `lastRefreshAt`。

**Remotive 来源**

- 端点：`GET https://remotive.com/api/remote-jobs`；无鉴权。
- 默认查询：无关键字、`category = "software-dev"`、数量上限 50；每次刷新只发一个请求，不为试参数消耗配额。
- 约束：每天最多 4 次请求；超过每分钟 2 次会被封；数据延迟约 24 小时；必须署名 Remotive 并回链原岗位；不得转投第三方招聘聚合站；不得收集注册/邮箱。
- DTO 字段：`id`、`url`、`title`、`company_name`、`company_logo_url`、`category`、`tags`、`job_type`、`publication_date`、`candidate_required_location`、`salary`、`description`（HTML）、`total-job-count`、`job-count`、`00-warning`。
- 解码容错：
  - `id` / `title` / `company_name` 缺失的条目跳过（debug log）；`description` 缺失按空描述处理。
  - 未知字段忽略；`00-warning` 忽略或仅日志；`total-job-count` 可选解码，仅用于日志/测试，不驱动 UI 协议。
  - 日期解析容忍 ISO 8601；坏日期置 nil，不失败整批。
  - 200 + 0 条或 200 + 12 条都是 `.refreshed`，不是解码失败/空数据错误。
- 映射：`intakeMethod = .remotive`，`identityKey = "remotive:<id>"`，`externalJobID = String(id)`；`title`、`companyName`、`jobURL`（取 `url`）、`location`（取 `candidate_required_location`）、`publishedAt`（取 `publication_date`）、`salary`、`companyLogoURL` 按字段映射；`descriptionPlainText` 由 HTML 归一化；`jobType` 原样小写保存；`tags` 原样。
- HTTP/网络错误映射：429 → `.rateLimited`；5xx → `.server(code)`；其他非 2xx → `.server(code)`；网络不可用 → `.offline`；超时 → `.timedOut`；JSON 解码失败 → `.decoding`。
- 请求超时 15 秒；URLSession 可注入，测试不联网。
- `total-job-count` 不进入 JobPostingDraft/JobPosting，不改变 JobSource / JobRepository / RefreshOutcome 协议。

**手动来源**

- `ManualJobInput`：`title`、`companyName`、`descriptionPlainText`、`jobURL?`、`location?`、`jobType?`、`tags: [String]`。
- 校验：title / company / JD 正文 trim 后非空；URL 若填写必须合法；不合法抛 `.invalidInput`。
- `ManualJobSource.loadJobs()` 同步返回一条 draft；协议仍为 `async throws`。
- `identityKey = "manual:<uuid>"`；`intakeMethod = .manual`；`externalJobID = nil`；`publishedAt = nil`；`createdAt` 由 repository 写入。
- 手动导入不消耗 Remotive 配额。

**JobQuery**

- 字段：关键字、category、数量上限；默认无关键字、`software-dev`、50。
- 只被远程源使用；手动输入在 source 初始化时注入。

### 8. Discover 页面

- 有异步加载、缓存、刷新、匹配和错误态，使用 `DiscoverViewModel`（`@Observable @MainActor`），依赖 `JobRepository` + `MatchProviding`。
- ViewModel 状态：岗位列表、匹配结果字典（按 `identityKey`）、LoadState、刷新状态/提示、`onlyInternships`、上次成功刷新时间、样本计数、错误。
- 刷新流程：
  - 首次出现：先读缓存并展示；缓存为空时显示 loading；若 `lastRefreshAt` 在 6 小时内且有缓存 → 不自动刷新；否则调用 `refreshDiscover`。
  - 下拉刷新：无视 TTL，调用 `refreshDiscover`，仍受 24h 配额和 60 秒限制。
  - `.refreshed` → 重新读缓存、重算匹配、更新「更新于」；
  - `.skipped(.fresh)` → 无提示；
  - `.skipped(.quotaExhausted/.tooSoon)` → 有缓存显示非阻塞提示；无缓存显示全屏「暂时拿不到岗位」；
  - `.failed` → 有缓存显示非阻塞提示 + 重试；无缓存显示全屏错误 + 重试 + 粘贴 JD。
  - 取消不显示错误。
- **样本头图（常驻）**：
  - 「样本模式」徽标 + 日期 overline + 大标题 `Discover` + 一句 deck。
  - 计数：本机 Remotive 样本 N 条、其中 internship M 条、手动导入 K 条；N/M/K 从缓存计算，不写死 12；若本次刷新有 `.refreshed(added, updated)`，补一行「本次刷新 added+updated 条」。
  - 说明文案：「公共 API 每天只放出一小份样本，不是全部岗位；条数少不是加载失败。」
  - 来源行：「数据来源 Remotive · <上次成功刷新时间> · 岗位回链原站」。
- **粘贴 JD**：样本头图下方第一块是虚线卡片「粘贴一份 JD」+ 说明「本地匹配，不消耗 Remotive 配额」；空状态主按钮、ineligible 分组头/尾部再出现同一入口。
- **只看实习**：样本头图下方的纯 UI 开关；只过滤 `jobType == internship` 的岗位，不改变 eligibility、MatchResult 或排序；仅本次会话有效。
- **列表分组**：
  - 画像就绪且词典可用：
    - 「适合你」：eligible 岗位，按 score 降序；同分按 matchedSkills.count 降序，再按 publishedAt 降序（nil 最后），再按 identityKey 升序；卡片按匹配展示变体 A。
    - 「不符合条件 · N 条」：ineligible 岗位，仍展示、不参与分数排序，按 `createdAt` 降序、同时间 identityKey 兜底；默认显示前 4 条，可展开全部；每行「不符合」徽标 + 原因（如「非实习」「地点不符」）+ 技能命中数；不显示 0 分；分组按 eligibility，不按来源，手动导入若不符合也进此组并标来源。
  - 画像不足或词典不可用：仍按 eligibility 分组；eligible 组不显示分数，显示「完善画像后查看匹配」或「匹配暂不可用」，按 publishedAt 降序（nil 最后）、identityKey 升序；ineligible 组照常显示原因，画像不足时不显示技能命中数；岗位仍可浏览、导入。
- **空状态**：
  - 无任何岗位：英雄区「还没有岗位」+ 样本说明 + 主按钮「粘贴 JD」+ 次按钮「重试」。
  - 只看实习且过滤后没有任何岗位：标题「今天的样本里没有实习」；正文说明 N 条样本、0 条实习、不是加载失败；主按钮「粘贴 JD」；次按钮「查看全部 N 条样本」（关闭筛选）；备注「手动导入的岗位会出现在这里；明天会有新样本」。如果过滤后仍有 ineligible 的实习岗位，则保留列表并显示「适合你」内联空状态 + 下方 ineligible 分组，不显示全屏空状态。
  - 有岗位但 eligible 为空：在「适合你」段显示内联空状态 + 粘贴 JD，下面仍显示 ineligible 分组。
- **刷新提示**：
  - 有缓存 + `.failed`：琥珀色非阻塞提示「今天没能刷新 · 显示 <日期> 的缓存」+「重试」。
  - 有缓存 + `.quotaExhausted`：琥珀色提示「今天的刷新次数已用完 · 显示 <日期> 的缓存」+「重试」。
  - 有缓存 + `.tooSoon`：琥珀色提示「刷新太频繁，请稍后再试」+「重试」。
  - 以上三种情况列表、详情、粘贴入口保持可用，不弹窗。
  - 无缓存 + `.failed` / `.quotaExhausted` / `.tooSoon`：全屏「暂时拿不到岗位」；按原因说明是网络/配额/太频繁；主按钮「重试」，次按钮「粘贴 JD」；提示手动粘贴不依赖 Remotive、配额明天恢复。
- **来源区分**：列表和详情显示「Remotive」或「手动导入」；Remotive 详情注明「本机 N 条样本之一」、样本不代表全量，并回链原岗位。
- P1 不做：来源筛选、样本头图日期切换动效、粘贴 JD 表单的额外字段/打磨、ineligible 折叠动画。v1 保留第 9 节定义的最小表单。

### 9. 岗位详情与导入

- 有匹配、导入和来源展示，使用 `JobDetailViewModel`（`@Observable @MainActor`）。
- 结构：标题/公司/地点/岗位类型/标签/发布日期/薪资/来源徽标；匹配区域；JD；来源与回链；底部导入 CTA。
- 匹配区域：
  - 画像不足：gate 卡片 + 两个条件（目标方向、3 个技能）+「去完善画像」。
  - eligible：分数 hero（score/100、band、低置信度 `*`）、匹配/缺失技能标签、四项分项条、一句话原因、JD 高亮。
  - ineligible：危险 banner「岗位不符合」+ 原因 +「仍展示、不隐藏；不计算总分」；只显示技能匹配数和匹配/缺失标签，不显示分数 hero 和分项条。
  - 低置信度：警告 banner「低置信度：描述为空或未识别到技能，分数仅供参考」。
  - 词典不可用：提示「匹配暂不可用」；岗位仍可浏览、导入。
- JD：显示归一化后的纯文本，按变体 A 做 matched 绿 / missing 红高亮；不显示 HTML 源码。
- 来源：Remotive 显示「数据来源 Remotive · 本机样本之一」+「打开原岗位」；手动导入显示「手动导入」+ 可选原链接。
- 导入 CTA：
  - 进入页面时用 `ApplicationRepository.applications(for:)` 检查该 JobPosting 的已有 Application。
  - 已有非终态（wishlist/applied/oa/interview）→ 显示「已有进行中的申请」+「查看」；点击切到申请 tab 并 push 已有详情，不创建重复记录。
  - 只有终态（offer/rejected/withdrawn）→ 显示「再次导入为申请」，确认后创建新记录。
  - 无记录 → 「导入为申请」。
  - 创建：快照 companyName/roleTitle/jobURL/location；初始状态 wishlist；关联 JobPosting；写初始 StatusChange；成功后切到申请 tab 并 push 新详情。
- 手动粘贴 JD 保存成功后 push 同一个 JobDetail，再从这里导入；不另做一套匹配页。

**手动粘贴表单**

- 字段：岗位标题*、公司*、JD 正文*（多行）、地点、岗位链接、岗位类型（实习/全职/合同/自由职业/兼职/未知）、标签（逗号分隔）。
- 若用户未手动选择岗位类型且标题含 intern/实习 → 保存为 internship。
- 标签 trim、去空、去重。
- 必填项为空或 URL 非法时内联报错；保存中禁用按钮；失败保留表单内容并显示中文错误。
- 保存成功 → dismiss → push JobDetail；返回 Discover 后重新读缓存并重算匹配。
- 不做 URL 抓取（P1）。

### 10. 架构与工程

- **单 app target + 文件夹分层**，不拆 SPM 模块；新增 `NextStepTests` 单测 target（Swift Testing）。
- 依赖方向：**Features → Domain ← Data**；`App` 是组合根；`Domain` 不依赖 Features/Data/App；`Domain` 允许 `import SwiftData`（仅 `@Model` 声明），不 `import SwiftUI`。
- 分层职责：
  - **App**：NextStepApp、AppContainer、RootTabView、AppRouter。
  - **Features**：Overview、Applications、ApplicationDetail、StatusHistory、Discover、JobDetail、Profile、ManualImport。
  - **Domain**：5 个 `@Model`、ApplicationStatus/ApplicationStateMachine、Matching（MatchingEngine、MatchResult、SkillDictionary、MatchService）、JobSource/JobPostingDraft/JobQuery、Repositories 协议。
  - **Data**：SchemaV1/ModelContainerFactory、SwiftData repositories、RemotiveJobSource/RemotiveDTO、ManualJobSource、JobSourceFactory、词典加载器、RefreshLedger。
  - **Core**：LoadState、DateProvider、HTMLTextNormalizer、格式化、设计 token。
- **协议只放在真正的缝上**：`JobSource`、`JobRepository`、`ApplicationRepository`、`UserProfileRepository`、`MatchProviding`、`DateProvider`；`MatchingEngine` / `SkillDictionary` 是值类型，不包协议。
- v1 不建 `NotificationScheduling` 协议或通知实现。
- **组合根**：`NextStepApp` 创建 `AppContainer`（ModelContainer、JobSourceFactory、repositories、MatchingLexicon、MatchingEngine、MatchService、DateProvider、AppRouter），通过 `.environment` 注入；View 的 `init` 接收 container，用自己的 `@State` 持有 VM。
- **状态**：`@Observable @MainActor final class` VM；不用 ObservableObject/Combine；`LoadState<Value>` 统一 idle/loading/loaded/failed；表单用 `@Bindable`；禁止 `.shared` 单例。
- **SwiftData**：主线程单 ModelContext；repository `@MainActor`；测试/Preview 用 `isStoredInMemoryOnly`；不做 ModelActor/后台 context。
- **并发**：从第一天把 `SWIFT_VERSION` 提到 6.0，保留 MainActor 默认隔离 + approachable concurrency；远程 source 标 `nonisolated`/`Sendable`，网络与解码在后台，落库回主线程。如果第一周被严格并发卡住，允许回退到 Swift 5 模式并在实现记录中说明。
- **日志**：`os.Logger` 按层分 category（app/data/matching/ui）；不用 `print`。
- **错误处理**：Data 层抛 typed error；ViewModel 映射中文；不把原始 error 文案直接展示给用户。
- **启动失败**：ModelContainer 创建失败时显示阻塞错误页 + 重试；Debug 构建提供清空本地数据。
- **无第三方依赖**；App 图标/品牌可最后定。

### 11. 表现层规则

- 有异步加载、错误态、表单校验或多步操作的页面 → MVVM；只读列表/派生展示 → `@Query` + 纯函数，不硬塞 VM；所有写操作走 Repository/ViewModel；ViewModel 不持有 ModelContext、不直接用 `@Query`。
- 页面形态：
  - 概览：`@Query` + `DashboardBuilder`，无 VM。
  - 申请列表：`@Query` + `@State` 筛选，无 VM。
  - 申请详情：`ApplicationDetailViewModel`。
  - 申请新建/编辑：`ApplicationEditorViewModel`。
  - 发现列表：`DiscoverViewModel`。
  - 岗位详情：`JobDetailViewModel`。
  - 用户画像：`ProfileViewModel`。
  - 手动粘贴 JD：`ManualImportViewModel`。
  - 状态历史：UIKit MVC，无 VM。
  - 根容器/路由：无 VM。
- 错误文案映射（示例）：`.offline` →「网络不可用，请检查连接」；`.timedOut` →「请求超时，请稍后重试」；`.rateLimited` →「请求过于频繁，请稍后再试」；`.server(code)` →「服务器暂时不可用（HTTP code）」；`.decoding` →「数据格式暂时无法识别」；`.invalidInput` →「请检查必填项」；未知 →「加载失败，请稍后重试」；保存失败 →「保存失败，请重试」；非法状态转换 →「当前状态不能这样变更」；匹配不可用 →「匹配暂不可用」。
- 设计语言沿用三个原型：卡片/圆角表面、状态色、分数 pill、技能标签、样本头图；系统语义色支持深浅色；图标按钮有 accessibility label；正文支持 Dynamic Type；使用系统控件，不做自定义动效（v1）。
- 状态徽标显示中文：想投 / 已投 / OA/笔试 / 面试 / Offer / 已拒 / 已撤。
- 删除、回退、重新打开、放弃未保存修改必须二次确认；错误用内联提示或系统 alert，不用阻塞式弹窗打断缓存浏览。

### 12. 资源与数据

- App bundle 资源：技能词典 JSON（约 50 核心 + 15 可选）、RoleDirectionLexicon JSON、LocationLexicon JSON。
- 演示数据：申请与手动 JD 全部虚构；Discover 使用真实 Remotive 数据并署名回链；不得把真实岗位伪造成实习，不得把虚构 JD 标成 Remotive 来源。
- Debug-only「清空演示数据」：删除所有 SwiftData 记录（Application、JobPosting、InterviewRound、StatusChange、UserProfile）并清空 RefreshLedger，回到首次启动状态；不影响 release。
- 不在仓库或演示数据集复制真实 JD 全文。

## Testing Decisions

测试缝已与用户确认：使用架构里已经定好的三条缝，不新增协议或 seam。UI 不做 XCUITest，只做手动黄金路径验收。

### 1. 三条测试缝

1. **纯领域模块接口**（最高逻辑缝）：直接调用 `ApplicationStateMachine`、`MatchingEngine`、`MatchingLexiconLoader`/`SkillDictionary` 解析、`DashboardBuilder`。无 I/O、无 ModelContext、无 container。
2. **仓库协议**（最高持久化/摄入缝）：通过 `ApplicationRepository`、`UserProfileRepository`、`JobRepository` 测试；实现使用 in-memory SwiftData，依赖注入 fake `JobSourceFactory`/`JobSource`、`FixedDateProvider`、临时 UserDefaults suite。测试不直接断言 ModelContext 的实现细节。
3. **选定的 ViewModel**（最高 UI 行为缝）：`DiscoverViewModel`、`ApplicationDetailViewModel`（按需加 `JobDetailViewModel`/`ApplicationEditorViewModel`）用 fake repository 测试 LoadState、错误映射、刷新结果处理和状态转换意图。View 本身只手动验收。

不新增 UI test target、不联网、不 mock SwiftData 本身。

### 2. 什么算好测试

- 只测外部行为：跨过 seam 观察调用者能看到的结果；不测私有 helper、不复制实现细节。
- 确定性：固定时间、固定词典、固定输入；不用 sleep、不依赖真实网络/系统时钟/真实 UserDefaults。
- 断言不变量而不是写死具体分数：0–100、分项和、ineligible 不给总分、别名/大小写不影响结果、排序规则、状态机合法性。
- 表驱动：状态机全转换、匹配边界、DTO 解码用参数化测试。
- 测试名用领域词汇（Application、StatusChange、JobPosting、MatchResult）。

### 3. 测试模块与用例

- **ApplicationStateMachine**：全部合法转换、非法转换、跳级、活动态回退、终态、reopen、offer 无出口、`requiresConfirmation`。
- **MatchingEngine**：空描述、无技能命中、同义词/别名、大小写/全半角、中文 JD、HTML、`Swift`/`SwiftUI` 子串陷阱、零重叠、全匹配、重复提及、地点不符、非实习、低置信度、画像门槛、分数边界/确定性；方向 20/15/0/10、地点 10/5/ineligible、岗位类型 10/5/0/ineligible；断言 0–100、分项和、ineligible 不给总分、别名/大小写不影响结果。
- **MatchingLexiconLoader / SkillDictionary**：JSON 解析、别名、重复 id、缺失字段、跨技能重复别名 first-wins、未知字段忽略。
- **RemotiveDTO / RemotiveJobSource**：正常响应、缺可选字段、缺必填字段跳过、坏日期、HTML、错误 JSON、200 + 0 条、200 + 12 条、`total-job-count`/`company_logo_url`/`00-warning` 容忍、HTTP 429/5xx、超时/离线映射；请求 URL/参数正确；使用 stub URLProtocol，不联网。
- **SwiftDataJobRepository**：`identityKey` upsert、added/updated 语义、去重、缓存优先、4 次/滚动 24h、60 秒间隔、跨启动持久化（临时 UserDefaults suite）、手动导入不计、离线/失败降级、`lastRefreshAt` 只记成功、不删除旧岗位。
- **ApplicationRepository**：创建写初始 StatusChange、每次状态转换写记录、初始日期补录、`appliedAt` 派生、`lastModifiedAt` 更新、cascade 删除、非法转换抛错、按 JobPosting 查已有申请。
- **UserProfileRepository**：fetch-or-create 单例、保存、默认时区。
- **DashboardBuilder**：今天/接下来 7 天窗口、截止与 pending 面试合并、排序、终态排除、offer 截止计入、计数去重、最近更新 top 5、空数据。
- **选定 VM**：`DiscoverViewModel` 的缓存优先、刷新 outcome（refreshed/skipped/failed）、错误映射、只看实习筛选、画像门禁；`ApplicationDetailViewModel` 的合法状态流转、回退/重开确认、轮次提示。
- **手动导入**：`ManualJobSource` 校验、identityKey、不消耗配额；`ManualImportViewModel` 内联错误与成功跳转。

### 4. 测试替身与既有先例

- 仓库目前没有测试；本 spec 建立首个 `NextStepTests` target 和测试模式，后续测试沿用。
- 使用 Swift Testing：`@Suite`、`@Test`、`#expect`、`#require`；参数化用 `arguments:`。
- 测试替身：fake `JobSource`/`JobSourceFactory`、`FixedDateProvider`、临时 UserDefaults suite（测试结束 removePersistentDomain）、in-memory `ModelContainer`、VM 用 fake repository。
- `@Model` 实例可直接在测试里构造，不需要 container（ADR-0002）。
- 测试 target 通过 `@testable import NextStep` 访问 internal 类型。
- 本地运行 `xcodebuild test`（scheme `NextStep`，destination 使用本机可用模拟器）；不配 CI。

### 5. 手动验收

- 按黄金路径手动走：空状态 → Discover（真实 Remotive 样本，缓存兜底）→ 岗位详情（匹配分 + 匹配/缺失解释）→ 导入 Application → 追踪器改状态/设截止/加面试轮次 → 概览看到今天/7 天事件 → 杀进程重启数据仍在。
- Remotive 网络失败时用缓存 + 手动粘贴虚构 iOS 实习 JD 走完流程。
- 不写 XCUITest、不做完整 UI 测试、不设覆盖率百分比。

## Out of Scope

- 本地通知/提醒（截止、面试）：v1 不实现调度、权限、文案、`NotificationScheduling` 缝。
- Push 通知、TestFlight、App Store 上架：免费账号不支持。
- Share Extension、Widget、App Group：v1 不纳入；未来独立 effort 重新评估。
- 账号/登录、云同步、多设备、iCloud/CloudKit、Sign in with Apple、Associated Domains。
- 抓取 BOSS直聘/实习僧/牛客/拉勾/智联/前程无忧等国内平台；实时全网聚合；把 Remotive 数据转投第三方招聘聚合站；收集岗位邮箱/注册信息。
- 把真实 JD 全文复制进仓库或演示数据集。
- 云 LLM / Foundation Models 匹配、embedding/向量检索、简历生成/自动投递/自动填表。
- URL 导入（公开页面解析）——P1。
- 漏斗转化率、状态分布图、环形图/多图分析页——P1。
- 横向看板作为主追踪界面。
- 申请列表全文搜索、自定义排序控件、CSV 导入导出。
- 独立 Company / Skill 实体、公司主页、联系人管理、日历/邮件集成、简历版本管理、团队协作、社交/推荐 Feed、薪资分析、公司点评。
- 自建后端/代理、生产级监控、完整 UI 测试、XCUITest、CI、多语言。
- 其他项目方向（本地音乐/播客播放器等）。
- 品牌细节（图标、配色、文案语气）与动效的最终定稿；简历呈现与项目叙事（等 v1 雏形后决定）。

## Further Notes

### 1. 实现顺序与完成标准

按 P0 依赖顺序推进，不排日历、不做周计划：

1. **工程脚手架与领域核心**
   - 建 `NextStepTests`、分层目录、Swift 6、in-memory container、协议空壳。
   - 5 个 `@Model` + VersionedSchema V1；七态状态机；Application/UserProfile repository + StatusChange 写入；状态机与 repository 单测绿。
2. **追踪器闭环**
   - Application CRUD（列表/详情/新建/编辑/删除）；状态流转 + StatusChange；deadline；InterviewRound；状态历史 UIKit 页；黄金路径的追踪器段可手动走通。
3. **匹配闭环（手动）**
   - UserProfile 编辑 + 词典加载；手动粘贴 JD → JobPosting；MatchingEngine + MatchResult + 解释展示；匹配表驱动单测绿；导入 Application。
4. **发现闭环（Remotive）**
   - JobSource + RemotiveJobSource；JobRepository upsert/节流/缓存/错误映射；Discover 列表/详情 + Remotive 署名回链；一键导入；断网/超时/限流/解码失败有可见错误 + 缓存兜底。
5. **收尾**
   - 概览变体 A；全局空/错状态；Debug 清空演示数据；中文 README；现场演示可走完整黄金路径；仓库公开 + `v1.0` tag。

每个里程碑完成后跑该切片的单测 + 手动验收；P1 不排入 v1，只在 README Roadmap 列出。

### 2. 演示与 README

- **不做视频演示**。演示 = 现场打开 App（模拟器），按黄金路径走；不承诺真机安装包（免费账号 7 天签名）。
- 演示前预热一次 Remotive 缓存；现场网络失败时用缓存 + 手动粘贴虚构 iOS 实习 JD 仍可走完流程。
- 演示数据：申请与手动 JD 全部虚构；Discover 用真实 Remotive 数据并署名回链；不得伪造 Remotive 数据或把虚构 JD 标为 Remotive 来源。
- README（中文）结构：项目简介 + 截图 → 功能 → 技术栈 → 架构图与分层 → 三个关键取舍 → 运行方式（Xcode 27 / 模拟器 / 免费账号说明）→ 测试命令 → Remotive 数据来源与合规声明 → 已知限制 + P1 Roadmap → 设计文档链接。
- 仓库公开；不公开 `.scratch/` 原始记录，另建 `docs/design/` 精选设计说明；License MIT；`v1.0` tag。
- 已知限制写入 README：Remotive 公共 API 每日约 10–12 条样本、查询参数不生效、实习岗位可能为 0；手动粘贴 JD 是可靠兜底。

### 3. 面试三个技术取舍

1. **匹配引擎：技能词典 + 规则加权 vs embedding/LLM**：可解释、确定性、可测试、无 API/成本/隐私问题；代价是召回受词典覆盖限制、语义泛化弱；embedding 可作为 P1 的 5–10 分 tie-breaker。
2. **JobSource / JobPostingDraft / JobRepository 统一摄入缝**：所有来源统一为 draft；Repository 唯一写入口，集中 upsert、节流、缓存、错误映射；UI 和匹配不碰来源，测试用 fake source；代价是多一层。
3. **SwiftData @Model 兼作领域模型 + 纯 MatchingEngine**：不另造一套 domain entity，减少映射；MatchingEngine 保持纯结构、无 I/O、无 ModelContext，可直接用 @Model 实例做输入并用单测覆盖；代价是领域层与 SwiftData 耦合，未来拆模块时需要解耦。

### 4. 风险与回退

- **Swift 6 严格并发**：第一周若阻塞，回退到 Swift 5 模式并在实现记录中说明；不影响功能范围。
- **Remotive 样本异常**：实习岗位可能持续为 0；按「真实样本 + ineligible + 手动虚构实习 JD」演示，不换源、不伪造。
- **词典调参**：匹配测试不写死具体分数，避免词典微调导致大面积红灯；用不变量和受控小词典验证规则。
- **免费账号**：只承诺模拟器演示；真机 7 天签名不作为交付承诺。
- **P1 不阻塞验收**：URL 导入、漏斗、状态分布图只在 README Roadmap 出现。

### 5. 设计资产

- 术语表：`GLOSSARY.md`。
- 架构决策：`docs/adr/0001`–`0004`。
- 设计过程与已解决 issue：`.scratch/nextstep/issues/01`–`11`（内部记录，不直接公开；对外用 `docs/design/` 精选版）。
- 原型：`.scratch/nextstep/prototypes/02-match-explanation.html`、`08-dashboard-prototype.html`、`11-discover-sample-ui.html`。
- 技能词典初稿：`.scratch/nextstep/skill-dictionary.md`。
- Remotive 研究：`.scratch/nextstep/research/remotive-api-recheck.md`。
