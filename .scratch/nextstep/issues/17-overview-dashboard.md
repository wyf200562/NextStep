# 17: 概览（行动优先）

**What to build:** 概览 tab 首屏回答「今天和未来 7 天要做什么」：日期 overline + 大标题「概览」；「今天」与「接下来 7 天」事件列表；一行三个计数（进行中 / 7 天内截止 / Offer）；「最近更新」前 5。事件来自非终态 Application 的 Deadline 与 pending InterviewRound（offer 的答复截止也算），今天已过去的事件仍显示并标「已过」；合并按时间升序，同时间按 application.id、Deadline 先于面试、轮次 id 兜底；7 天内计数按去重后的 Application 数量。点击事件或最近更新切到申请 tab 并打开详情；点击计数切到申请 tab 并带对应筛选；无事件显示「7 天内没有截止或面试。去 Discover 看看新岗位。」；无申请显示英雄式空状态与两个入口。不做状态分布图、漏斗、环形图。

**Blocked by:** 16（面试轮次与下一节点）

**Status:** resolved

- [x] DashboardBuilder 为纯函数，接收 Application 集合、now、Calendar；表驱动测试覆盖今天 / 未来 7 天窗口、合并排序、终态排除、offer deadline、计数去重、最近 5、空数据。
- [x] 概览变体 A 布局，行动事件优先，计数压缩成一行。
- [x] 跨 tab 路由：事件 / 最近更新 → 申请详情；计数 → 对应筛选；空状态 → Discover / 新建申请。
- [x] 今天已过事件标记「已过」；面试事件标题带轮次 label。
- [x] 空事件与空数据文案正确；不出现 1/2/3 步骤。

## Answer

日期：2026-11-09。实现 commit：`16ce9eb`（`ticket/17-overview-dashboard`，基于 integration/nextstep-v1 `b566d6b`）。

### 交付内容

- **DashboardBuilder（纯函数）**：新增 `DashboardBuilder.snapshot(applications:now:calendar:)`，无 I/O、无 ModelContext、无 ViewModel。输入全部 `Application`（含 relationships）与注入的 `now`/`Calendar`，输出 `DashboardSnapshot`：`todayEvents`（今天 00:00 至明天 00:00，已过去的今天事件保留并带 `isPast`）、`upcomingEvents`（明天 00:00 至今天+8 00:00）、`activeCount`、`dueSoonCount`、`offerCount`、`recentApplications`（`lastModifiedAt` 降序、同时间 `id` 升序取前 5）。事件来源严格为：非 rejected/withdrawn 的 deadline（offer 的答复截止计入）与 `result == .pending` 的 InterviewRound；合并后按时间升序，同时间按 application.id、Deadline 先于面试、轮次 id 兜底。`dueSoonCount` 按去重后的 Application 数量计算。
- **概览变体 A UI**：`OverviewView` 为只读 `@Query` 页面，无 ViewModel、无 ModelContext。首屏自上而下：日期 overline + 大标题「概览」；「今天」事件卡片；「接下来 7 天」事件卡片；一行三个计数（进行中 / 7 天内截止 / Offer，7 天内截止 > 0 时数值橙色）；「最近更新」前 5 行；右上角「+」复用 `ApplicationEditorView` 新建并跳转详情。事件行显示日期/时间、公司、动作（面试带轮次 label）、Deadline/面试图标；今天已过事件整行弱化并标「已过」胶囊。计数与最近更新用圆角卡片、状态徽标与系统语义色，支持深浅色。
- **跨 tab 路由**：事件行与最近更新行调用既有 `AppRouter.openApplication(_:)`；三个计数调用 `openApplications(filter:)`（`.active` / `.dueSoon` / `.offer`）；「查看全部」打开 `.all`；空状态「去 Discover 看看」调用 `openDiscover()`。未新增路由类型，`OverviewRoute` 保持原样。
- **空状态**：无申请时显示英雄式空状态（target 图标 +「从第一份申请开始」+ 说明 +「添加第一份申请」「去 Discover 看看」两个入口），不出现 1/2/3 步骤。有申请但 7 天内无任何事件时，在「接下来 7 天」下显示「7 天内没有截止或面试。去 Discover 看看新岗位。」；「今天」「接下来 7 天」两个分节仅在各自有事件时渲染，避免空标题噪音。
- **共享规则抽取（最小改动）**：`ApplicationListBuilder.isDueSoon` 由 private 改为 internal 并补文档，Dashboard 的 7 天计数直接复用列表的同一窗口规则；`ApplicationStatus.isActive` / `isEnded` 从 `ApplicationListBuilder` 的 private extension 移到 `ApplicationListFilter.swift` 的共享 extension，供概览计数与列表筛选共用，避免两处规则漂移。

### 关键文件

- `NextStep/Features/Overview/DashboardBuilder.swift`（新增：事件/快照模型与纯推导）
- `NextStep/Features/Overview/OverviewView.swift`（替换占位页为完整变体 A）
- `NextStep/Features/Overview/DashboardRows.swift`、`DashboardFormatting.swift`（新增：事件行、最近更新行与日期文案）
- `NextStep/Features/Applications/ApplicationListFilter.swift`、`ApplicationListBuilder.swift`（共享状态分组与 7 天窗口规则）
- `NextStepTests/Features/DashboardBuilderTests.swift`（新增）

### 验证

```bash
xcodebuild -project NextStep.xcodeproj -scheme NextStep \
  -destination 'platform=iOS Simulator,id=430CDEBB-8ABA-4F35-A1D3-954C3E39EC81' \
  -derivedDataPath /Users/wuyifan/.claude/jobs/82faab4c/tmp/t17-dd \
  -collect-test-diagnostics never -parallel-testing-enabled NO test
```

结果：exit 0，`** TEST SUCCEEDED **`，`Test run with 238 tests in 28 suites passed`（0 失败 0 跳过）。新增 `Overview dashboard` suite 7 个测试函数，其中一个为 10 个 case 的表驱动测试；覆盖今天/未来 7 天边界、过去事件标记、终态排除、offer deadline、pending-only、合并排序与全部 tie-breaker、计数去重、最近 5 与 id tie-break、空数据。iPhone 18 Pro 模拟器安装启动，分别以空数据与 7 条种子数据检查空状态与完整首屏（今天已过事件、明天面试、计数 4/4/1、最近更新）均按预期渲染。

合并 `integration/nextstep-v1`（`b566d6b`，无冲突）后重跑全量：exit 0，`** TEST SUCCEEDED **`，238 个测试（28 个 suite）通过，0 失败 0 跳过。

### 决策与说明

- 今天窗口为 `[今天 00:00, 明天 00:00)`，未来窗口为 `[明天 00:00, 今天+8 00:00)`，与列表「临近截止」的 8 个日历日窗口一致；昨天及更早的非今天事件不显示，今天已过去的事件保留并标「已过」。
- 7 天内计数复用 `ApplicationListBuilder.isDueSoon`（含今天已过去的截止、offer deadline、去重按 Application），而不是另写一套事件计数规则。
- 计数点击一律走 `AppRouter.openApplications(filter:)`，由申请 tab 自己消费筛选并清空导航路径；没有把筛选状态下传到概览页。
- 事件用 `ForEach(indices)` 渲染快照数组，事件 id 为 `deadline-<application.uuid>` / `interview-<round.uuid>`，仅用于 SwiftUI 身份，不持久化。
- 最近更新额外提供「查看全部」入口（原型 A 的 link），行为是切到申请 tab 并显示全部；不影响 ticket 规定的行点击进详情。
- 概览右上角「+」复用既有编辑器；保存成功后通过 `openApplication` 切到申请 tab 打开新详情，与列表/Discover 的既有行为一致。
- 不做状态分布图、漏斗、环形图；Remotive 刷新（23）与匹配解释 UI（22）不在本票范围。

