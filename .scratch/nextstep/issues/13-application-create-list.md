# 13: 申请创建与列表

**What to build:** 用户可以从空状态新建第一份申请，填写公司、职位、初始状态（7 选 1）、状态日期、Deadline（日期 + 可选时刻）、岗位链接、地点、备注；保存时写入初始 StatusChange（fromStatus = nil）并出现在申请列表。列表支持全部 / 进行中 / 临近截止 / Offer / 已结束筛选，按最近 upcoming 节点（Deadline 或 pending InterviewRound）升序、无节点按 lastModifiedAt 降序排序，同时间用 id 兜底；顶部显示「N 份申请 · M 份进行中」摘要；筛选无结果时显示对应空状态与两个入口。点击行进入只读详情壳（公司、职位、状态、Deadline、备注），完整详情在 14 补齐。数据杀进程重启后仍在。

**Blocked by:** 12（工程脚手架与领域模型）

**Status:** resolved

- [x] 空状态含「添加第一份申请」「去 Discover 看看」，不出现 1/2/3 步骤说明。
- [x] 新建表单字段完整；初始状态可选全部 7 种；非 wishlist 时显示状态日期，默认今天、可补录过去。
- [x] Deadline 为日期 + 可选 HH:mm，缺省 09:00；岗位链接填写时必须是合法 URL；公司、职位 trim 后非空；校验失败内联显示。
- [x] 保存写初始 StatusChange，changedAt 使用状态日期；Application 快照字段与 lastModifiedAt 正确。
- [x] 列表五筛选规则、排序与 tie-breaker 符合 spec；行显示公司、职位、状态徽标、最近节点、最近更新时间。
- [x] 摘要与各筛选空状态；保存或点击行进入只读详情壳（14 起为完整详情）。
- [x] 杀进程重启后数据仍在。
- [x] 单测覆盖筛选规则、排序、初始 StatusChange 与表单校验（repository 层）。

## Answer

日期：2026-11-09。实现 commit：`39a80f7`（`ticket/13-application-create-list`，基于 integration/nextstep-v1 `f9dc04f`）。

### 交付内容

- **ApplicationRepository 实现**：新增 `SwiftDataApplicationRepository`（`@MainActor`，注入 `ModelContext` + `DateProvider`）。读取：`allApplications()`、`application(id:)`、`applications(for:)`（按 JobPosting 过滤）、`statusChanges(for:)`（`changedAt` 降序、同时间 `id` 升序）。创建：同一 save 内插入 `Application`（快照字段、`createdAt`/`lastModifiedAt = dateProvider.now`）与初始 `StatusChange`（`fromStatus = nil`、`toStatus = 初始状态`、`changedAt = 状态日期`），失败 rollback 并抛 `RepositoryError.saveFailed`。`updateApplication`、`deleteApplication`、`changeStatus` 与三个面试轮次方法保留为 `RepositoryError.unavailable`，注释标明由 ticket 14/16 实现。
- **组合根**：`AppContainer` 默认 `applicationRepository` 改为 `SwiftDataApplicationRepository`，保留所有可注入参数；`AppRootView`/预览补 `.modelContainer(...)`，供 `@Query` 使用。
- **申请列表**：`ApplicationsView` 为只读 `@Query` + `@State` 筛选，无 ViewModel；纯 `ApplicationListBuilder` 接收 `applications`、`filter`、`now`、`Calendar`，输出筛选/排序后的行、最近 upcoming 节点与「N 份申请 · M 份进行中」计数。五种筛选、7 天窗口（今天 00:00 至今天+7 当天结束，排除 rejected/withdrawn，offer 的 deadline 计入）、最近节点升序 + 无节点按 `lastModifiedAt` 降序 + `id` tie-break 均按 spec。行显示公司、职位、中文状态徽标、最近节点（截止/面试 + 日期）与最近更新时间；点击 push 详情。
- **新建流程**：`ApplicationEditorViewModel`（`@Observable @MainActor`）承载草稿、内联校验、保存态与未保存修改信号；`ApplicationEditorView` 为完整表单：公司*、职位*、7 种初始状态、非 wishlist 才显示的状态日期（默认今天、可补录过去）、可选 Deadline 日期 + 时刻开关（缺省 09:00）、岗位链接、地点、备注。保存按钮在保存中禁用；失败显示「保存失败，请重试」；放弃未保存修改二次确认；成功后 dismiss 并通过 `AppRouter` 打开新详情。
- **详情壳**：`ApplicationDetailView` 通过 repository 读取，显示公司/职位/状态/最近更新、Deadline、备注；加载失败显示中文「加载失败，请稍后重试」+ 重试。ticket 14 将替换内容。
- **空状态**：全局与各筛选均有中文空状态，含「添加第一份申请」「去 Discover 看看」（`container.router.openDiscover()`），无 1/2/3 步骤说明。
- **持久化**：默认 `ModelContainer` 使用磁盘存储；repository 测试使用内存容器验证创建/读取。

### 关键文件

- `NextStep/Data/Repositories/SwiftDataApplicationRepository.swift`
- `NextStep/Features/Applications/ApplicationListBuilder.swift`、`ApplicationRowView.swift`、`ApplicationStatusBadge.swift`、`ApplicationDateFormatting.swift`
- `NextStep/Features/Applications/ApplicationEditorViewModel.swift`、`ApplicationEditorView.swift`
- `NextStep/Features/Applications/ApplicationsView.swift`、`ApplicationDetailView.swift`
- `NextStep/App/AppContainer.swift`、`AppRootView.swift`、`RootTabView.swift`
- `NextStepTests/Data/ApplicationRepositoryTests.swift`、`NextStepTests/Features/ApplicationListBuilderTests.swift`、`NextStepTests/Features/ApplicationEditorViewModelTests.swift`、`NextStepTests/Support/FakeApplicationRepository.swift`、`NextStepTests/App/AppContainerTests.swift`

### 验证

```bash
xcodebuild -project NextStep.xcodeproj -scheme NextStep \
  -destination 'platform=iOS Simulator,id=430CDEBB-8ABA-4F35-A1D3-954C3E39EC81' test
```

结果：exit 0，`** TEST SUCCEEDED **`，50 个测试全部通过（新增 repository 创建/读取/排序、列表筛选与排序表驱动、编辑器校验/默认值/保存失败，以及 AppContainer 默认申请仓库）。模拟器安装启动确认 4 个 tab 正常显示、App 进程存活。

### 决策与说明

- 「upcoming 节点」定义为不早于 `now` 的 Deadline 或 pending InterviewRound；应用内节点并列时 Deadline 优先，跨应用同时间按 `id` 升序。终态申请的未来节点在「全部」排序中仍按字面规则参与（spec 未排除），而「临近截止」筛选明确排除 rejected/withdrawn。
- 7 天窗口按日历日计算：今天 00:00 起至今天+7 的 23:59:59（共 8 个日历日）；跨越边界由 `Calendar` 处理。
- `applications(for:)` 在内存中按 `jobPosting.id` 过滤，避免 SwiftData 可选关系谓词的不稳定性；v1 数据量小。
- 列表不设 ViewModel（ADR-0004）；所有筛选/排序/计数在纯 helper 中，注入 `now` 与 `Calendar` 保证确定性。
- 保存为 MainActor 同步调用；`isSaving` 防重复提交并在 repository 调用期间为 true（单测可观察到），UI 按钮同步 `.disabled`。
- 详情壳是最小只读实现，明确标注 ticket 14 替换；状态历史 UIKit 页、编辑、状态流转、面试轮次不在本票范围。
- `ApplicationsView` 通过 `AppRouter.openApplication` 复用既有跨 tab 路由打开新详情，避免把导航路径下传到列表页。
