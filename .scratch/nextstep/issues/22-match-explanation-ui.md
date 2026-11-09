# 22: 匹配解释展示

**What to build:** 浏览岗位时把 MatchResult 变成可读解释。Discover 列表按 eligibility 分组：「适合你」为 eligible 岗位，按 score 降序、同分按 matchedSkills.count、publishedAt（nil 最后）、identityKey；卡片含分数 pill（低置信度带 `*`）、band、「匹配 X/Y」、前 3 个匹配技能标签、前 2 个缺失技能标签 +N、一句原因（最多两行）。「不符合条件 · N 条」为 ineligible 岗位，按 createdAt 降序、identityKey 兜底，默认显示前 4 条可展开，每行「不符合」徽标 + 原因 + 技能命中数，不显示 0 分；分组按 eligibility 不按来源。画像不足或词典不可用时仍按 eligibility 分组：eligible 组不显示分数，显示「完善画像后查看匹配」或「匹配暂不可用」，按 publishedAt 降序、identityKey；ineligible 组仍显示原因，画像不足时不显示技能命中数。岗位详情：eligible 显示分数 hero、band、低置信度 `*`、匹配 / 缺失技能标签、四项分项条、一句话原因、JD 绿 / 红高亮；ineligible 显示危险 banner + 原因 + 技能匹配，不显示分数 hero 和分项条；低置信度显示 banner；画像不足显示 gate + 两个条件 +「去完善画像」；词典不可用显示提示。申请详情在关联岗位下现算紧凑匹配摘要，画像不足时隐藏并提示。所有 MatchResult 现算，不持久化。

**Blocked by:** 18（匹配核心）、19（用户画像页）、21（岗位详情与导入申请）

**Status:** resolved

- [x] Discover 分组、排序、卡片信息、展开与来源标记符合 spec；eligible / ineligible 不混排。
- [x] 画像不足与词典不可用两种降级状态正确；「只看实习」只影响显示，不改变匹配与排序。
- [x] JobDetail 四种匹配状态（gate / eligible / ineligible / 词典不可用）与低置信度展示正确。
- [x] JD 高亮非重叠、最长优先，matched 绿 / missing 红，不持久化。
- [x] 申请详情紧凑匹配摘要现算；画像不足时隐藏并提示。
- [x] 「适合你」为空时显示内联空状态 + 粘贴 JD，ineligible 分组保留。
- [x] 单测：分组 / 排序规则、gate、低置信度、ineligible 展示条件。

## Answer

日期：2026-11-09。实现 commit：`9b48d9f`（`feat: add match explanation UI`，`ticket/22-match-explanation-ui`，基于 integration/nextstep-v1 `b566d6b`）。

### 交付内容

- **Discover 分组与排序**：新增纯 helper `DiscoverJobGrouping`（`NextStep/Features/Discover/DiscoverJobGrouping.swift`），输入缓存岗位、按 `identityKey` 的 `MatchResult` 字典、门槛独立的 eligibility 字典和 `MatchAvailability`，输出 eligible / ineligible 两组。eligible ready 时按 score 降序 → matchedSkills.count 降序 → publishedAt 降序（nil 最后）→ identityKey 升序；画像不足或词典不可用时 eligible 按 publishedAt 降序（nil 最后）→ identityKey 升序；ineligible 始终按 createdAt 降序 → identityKey 升序。eligibility 与来源无关，手动导入的不符合岗位同样进入 ineligible 组并标来源。
- **门槛独立的 eligibility**：`MatchProviding` 新增 `eligibility(jobs:)`，`MatchService` 只读一次画像后调用 `MatchingEngine.eligibility(profile:job:lexicon:)`，复用岗位类型与地点规则而不执行画像技能门槛。这样画像技能不足时仍能把「非实习」「地点不符」正确分到 ineligible 组并显示原因。词典不可用（`matchProvider == nil`）时退化为仅按已存储 `jobType` / 标题推断分组，地点未知不误判（原因仅「非实习」）。
- **DiscoverViewModel**：注入可选 `MatchProviding`；`loadCachedJobs()` 每次读缓存后现算匹配，按 `identityKey` 保存结果（仅内存）。状态：`matchAvailability`（`.ready` / `.profileIncomplete` / `.unavailable`）、`eligibleJobs`、`ineligibleJobs`、`visibleIneligibleJobs`（默认前 4 条）、`hasMoreIneligible`、`isShowingAllIneligible` 与 `toggleIneligibleExpansion()`。非空岗位却返回空结果字典视为画像门槛未满足（`MatchService` 的既定语义）；provider 抛错、provider 为 nil 或 eligibility 读取失败均降级为「匹配暂不可用」，岗位仍可浏览/导入。匹配对全部缓存岗位计算，「只看实习」只在分组时过滤显示，不重算、不改变排序。
- **Discover 卡片（变体 A）**：`MatchCardPresenter` + `SkillTag` / `SkillTagView` 统一展示规则。eligible 卡片含分数 pill（低置信度 `*`）、band、「匹配 X/Y」、前 3 个匹配技能（绿）、前 2 个缺失技能（红）+ 各组 `+N`、最多两行模板原因、来源徽标；画像不足显示「完善画像后查看匹配」，词典不可用显示「匹配暂不可用」，均不显示分数。ineligible 行为「不符合」徽标 + 原因（非实习/地点不符）+ 技能命中数（仅匹配可用时）+ 来源；不显示 0 分。分组头为「适合你」与「不符合条件 · N 条」，超过 4 条可展开/收起；「适合你」为空时显示内联空状态 + 粘贴 JD，下方保留 ineligible 分组。
- **岗位详情匹配区**：`JobMatchSection` 四态——画像不足 gate 卡片（两条条件 + 「去完善画像」切到我的 tab）、eligible（分数 hero、band、低置信度标记、匹配/缺失标签、四项分项条 60/20/10/10、模板原因）、ineligible（危险 banner「岗位不符合」+ 原因 + 「仍展示、不隐藏；不计算总分」+ 技能匹配数/标签，无 hero 与分项条）、词典不可用「匹配暂不可用」。低置信度显示警告 banner。
- **JD 高亮**：纯 helper `JDHighlighter` 在详情页按技能 canonical 名称与别名做大小写不敏感、ASCII 词边界、非重叠、最长优先匹配；matched 绿、missing 红，保留原文大小写；无匹配结果时不渲染高亮。仅用于展示，不写入任何模型。
- **申请详情紧凑摘要**：`ApplicationDetailViewModel` 注入可选 `MatchProviding`，在 `load` / `refresh` 时按关联岗位现算 `MatchResult`；关联岗位 Section 内显示分数 pill + band + 「匹配 X/Y」+ 两行原因（ineligible 显示「不符合」+ 原因）。画像不足时隐藏摘要并提示「完善画像后查看匹配」（可跳转我的 tab），词典不可用时提示「匹配暂不可用」；无关联岗位时不渲染摘要。所有 MatchResult 均不持久化。
- **测试**：新增 45 个测试函数（276 / 30 suites，483 个参数化用例全部通过）：`DiscoverJobGroupingTests` 9（两种画像状态排序、四层 tie-break、来源无关、展开过滤）、`JDHighlighterTests` 8（最长优先非重叠、词边界、中文、大小写、相同别名去重、空文本）、`MatchCardPresenterTests` 9（分数/`*`、标签上限与 `+N`、gate 文案、ineligible 原因/技能数/来源）、`MatchServiceTests` 1（门槛未满仍按岗位类型与地点判 eligibility）、`DiscoverViewModelTests` +7（分组、两种降级、抛错、只看实习不重算、展开、重复加载重算）、`JobDetailViewModelTests` +5、`ApplicationDetailViewModelTests` +6。`AppContainerTests` 的 stub 同步实现新协议方法。

### 关键文件

- `NextStep/Features/Discover/DiscoverJobGrouping.swift`、`DiscoverViewModel.swift`、`DiscoverView.swift`
- `NextStep/Features/Discover/JobDetailViewModel.swift`、`JobDetailView.swift`、`JobMatchSection.swift`
- `NextStep/Features/Shared/SkillTag` / `SkillTagView`（`MatchCardPresenter.swift`、`MatchViews.swift`）、`JDHighlighter.swift`、`MatchAvailability.swift`
- `NextStep/Features/Applications/ApplicationDetailViewModel.swift`、`ApplicationDetailView.swift`
- `NextStep/Domain/Matching/MatchProviding.swift`、`MatchService.swift`、`MatchingEngine.swift`（新增 `eligibility`）
- 测试：`NextStepTests/Features/Discover/DiscoverJobGroupingTests.swift`、`DiscoverViewModelTests.swift`、`JobDetailViewModelTests.swift`、`NextStepTests/Features/JDHighlighterTests.swift`、`MatchCardPresenterTests.swift`、`ApplicationDetailViewModelTests.swift`、`NextStepTests/Domain/MatchServiceTests.swift`、`NextStepTests/Support/FakeMatchProvider.swift`、`MatchFixtures.swift`

### 验证

```bash
xcodebuild -project NextStep.xcodeproj -scheme NextStep \
  -destination 'platform=iOS Simulator,id=34F2F13F-FBED-46E6-BC02-C59C545FDF2C' \
  -derivedDataPath /Users/wuyifan/.claude/jobs/82faab4c/tmp/t22-dd \
  -collect-test-diagnostics never -parallel-testing-enabled NO test
```

结果：exit 0，`** TEST SUCCEEDED **`；276 个测试函数 / 30 个 suite，设备级 `passedTests 483`、`failedTests 0`、`skippedTests 0`（iPhone 18 Pro Max / iOS 27.0）。App 在同一模拟器安装并启动成功，无崩溃。

合并 integration/nextstep-v1 `ae4764c`（ticket 17）时无冲突，merge commit `c4f9b65`；合并后重跑同一命令：exit 0，`** TEST SUCCEEDED **`，283 个测试函数 / 31 个 suite，设备级 `passedTests 499`、`failedTests 0`、`skippedTests 0`。

合并回 integration/nextstep-v1：merge commit `0b68aa2`，无冲突；在 iPhone 18 Pro（iOS 27.0）重跑全量：exit 0，`** TEST SUCCEEDED **`，283 个测试函数 / 31 个 suite，设备级 `passedTests 499`、`failedTests 0`、`skippedTests 0`。

### 决策与说明

- **协议新增 `eligibility(jobs:)`**：spec 要求画像不足时仍按 eligibility（job type 与地点规则）分组且 ineligible 组仍显示原因，仅靠 `evaluate` 的 nil（门槛未满）无法得到原因。因此把门槛独立的 eligibility 放到既有 `MatchProviding` 缝上，`MatchingEngine` 复用私有岗位类型/地点规则；未新增协议或领域实体。ticket 17/23 若新增 `MatchProviding` 测试替身需实现该方法。
- **词典不可用的地点降级**：`matchProvider == nil` 时没有 LocationLexicon，只能按已存储岗位类型（含 title intern/实习 推断）判 ineligible；地点不符无法判定，按 eligible 处理而不是误报。
- **空结果字典语义**：沿用 `MatchService.evaluate(jobs:)` 在门槛未满时返回 `[:]` 的契约，Discover 将「有岗位但空结果」解释为 `.profileIncomplete`；provider 抛错则 `.unavailable`，避免把错误伪装成画像不足。
- **JD 高亮优先级**：候选区间按长度降序、起点升序、matched 优先、别名升序排序后贪心选非重叠区间，再按文本顺序输出；与匹配引擎一样，ASCII 字母数字边缘用词边界，中文按子串，因此 `Swift` 不会命中 `SwiftUI`，但更长的 `SwiftUI` 会胜出。原文大小写保留。
- **申请详情摘要位置**：放在既有「关联岗位」Section 末尾；无 `jobPosting` 时整段不渲染，快照字段照常显示。
- **兼容性**：`JobDetailViewModel` 与 `ApplicationDetailViewModel` 的新 `matchProvider` 参数带默认值 `nil`，既有测试/预览无需改动；App 组合根显式传入 `container.matchProvider`。
- 未实现：Remotive 刷新/ledger/TTL（23）、概览 dashboard（17）；未改 Overview 或 `JobPosting` 模型，未持久化任何 MatchResult。

