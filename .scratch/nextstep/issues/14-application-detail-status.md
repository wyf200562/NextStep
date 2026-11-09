# 14: 申请详情与状态流转

**What to build:** 申请详情展示头部（公司 / 职位 / 状态 / 最近更新）、下一节点卡片（Deadline，pending 轮次在 16 合并）、备注与编辑 / 删除工具栏。编辑复用申请表单修改公司、职位、链接、地点、备注、Deadline / 时刻，保存更新 lastModifiedAt，状态不能在编辑器中修改。删除二次确认后级联删除面试轮次与状态历史，JobPosting 保留。状态变更 sheet 只列 ApplicationStateMachine 允许的目标状态，可填备注；活动态回退与 rejected / withdrawn 重新打开需二次确认；offer 为成功终态不可离开；每次变更写 StatusChange、更新 Application.status 与 lastModifiedAt；非法转换抛 typed error，UI 显示「当前状态不能这样变更」。ApplicationStateMachine 为纯结构，无 I/O。

**Blocked by:** 13（申请创建与列表）

**Status:** resolved

- [x] 状态机规则与 spec 转换表完全一致（含跳级、活动态回退、终态、reopenTargets、requiresConfirmation）；offer 无出口；表驱动测试覆盖全部转换。
- [x] 状态变更 sheet 只列合法目标；回退 / 重开二次确认；备注写入 StatusChange。
- [x] 编辑不改变状态，保存更新 lastModifiedAt；删除 cascade 且 JobPosting 保留。
- [x] 详情头部与下一节点卡片（Deadline）正确；关联 JobPosting 不存在时快照仍正常显示。
- [x] 非法转换显示中文错误文案，不展示原始 error。
- [x] Repository 单测：每次转换写记录、lastModifiedAt、cascade、非法转换抛错。

## Answer

日期：2026-11-09。实现 commit：`dcabcdc`（`ticket/14-application-detail-status`，基于 integration/nextstep-v1 `82843dd`）。

### 交付内容

- **ApplicationStateMachine（Domain）**：纯 `enum` + 静态函数，无 I/O。普通转换表与 spec §2 完全一致（`wishlist→{applied,withdrawn}`、`applied/oa/interview` 各自含回退、跳级、`rejected/withdrawn`、`offer` 无出口）；`reopenTargets` 为 `rejected→{applied,oa,interview,offer}`、`withdrawn→{wishlist,applied,oa,interview,offer}`；`allowedTransitions` = 普通 ∪ reopen，按 `ApplicationStatus.allCases` 规范顺序；`isValidTransition` 只接受合法边（含 reopen、拒绝自转换）；`requiresConfirmation` 对活动态回退（applied→wishlist、oa→wishlist/applied、interview→wishlist/applied/oa）与全部 reopen 返回 true，其余 false。非法转换抛 typed `ApplicationTransitionError(from:to:)`；Repository 与 UI 共用同一套规则，UI 不复制转换表。
- **Repository 实现**：`updateApplication` 更新快照字段/备注/deadline 且 `lastModifiedAt = DateProvider.now`，不触碰 status/statusChanges；`deleteApplication` 保存后级联删除 InterviewRound 与 StatusChange、保留 JobPosting（nullify）；`changeStatus` 先经状态机校验（非法抛 typed error、状态不变），同一 save 内写 `StatusChange(from/to/changedAt/note)`、更新 `Application.status` 与 `lastModifiedAt`。三个面试轮次方法保留 `RepositoryError.unavailable` 空壳并注释 ticket 16。
- **ApplicationDetailViewModel**：`@Observable @MainActor`，无 ModelContext/@Query；`state: LoadState<Application>`、`targets`、`requiresConfirmation(to:)`、`isReopen(to:)`、`changeStatus(to:note:)`（预校验 + 捕获 typed error 映射「当前状态不能这样变更」，保存失败「保存失败，请重试」，空白备注归一为 nil）、`delete()`（失败「删除失败，请重试」且不退出）、`refresh()`、`clearActionError()`。
- **申请详情 UI**：头部（公司/职位/中文状态徽标/最近更新）、下一个节点卡片（Deadline 日期 + 时刻，预留 ticket 16 的 pending 轮次）、岗位快照区（公司/职位/链接/地点全部来自 Application 快照，JobPosting 为 nil 时照常显示）、备注、工具栏「编辑 / 删除」；删除二次确认后级联删除并 pop；加载中/失败均为中文并提供重试。
- **状态变更 sheet**：只列 ViewModel 暴露的合法目标（中文），可选备注；对回退/重开用 confirmationDialog 二次确认（标题/文案区分「回退状态？」与「重新打开申请？」）；offer 打开时说明「Offer 是成功终态，不能再变更状态。」；非法转换在 sheet 内显示「当前状态不能这样变更」，从不展示原始 error。
- **编辑模式**：`ApplicationEditorViewModel` 增加 create/edit 两种模式；编辑时从快照预填公司、职位、链接、地点、备注、deadline 日期与时刻（09:00 视为默认时刻），隐藏状态区且保存经 `updateApplication`（状态不变）；校验与新建一致；未保存修改按「当前会保存的值 vs 载入快照」比较；失败显示「保存失败，请重试」。
- **导航接线**：申请 tab 与概览 tab 的详情 destination 均向 `ApplicationDetailView` 注入 `AppContainer`。

### 关键文件

- `NextStep/Domain/ApplicationStateMachine.swift`
- `NextStep/Data/Repositories/SwiftDataApplicationRepository.swift`
- `NextStep/Features/Applications/ApplicationDetailViewModel.swift`、`ApplicationDetailView.swift`、`ApplicationStatusChangeView.swift`
- `NextStep/Features/Applications/ApplicationEditorViewModel.swift`、`ApplicationEditorView.swift`
- `NextStep/Features/Applications/ApplicationsTabView.swift`、`NextStep/Features/Overview/OverviewTabView.swift`
- `NextStepTests/Domain/ApplicationStateMachineTests.swift`、`NextStepTests/Data/ApplicationRepositoryTests.swift`、`NextStepTests/Features/ApplicationDetailViewModelTests.swift`、`NextStepTests/Features/ApplicationEditorViewModelTests.swift`、`NextStepTests/Support/FakeApplicationRepository.swift`、`NextStepTests/Support/MutableDateProvider.swift`

### 验证

```bash
xcodebuild -project NextStep.xcodeproj -scheme NextStep \
  -destination 'platform=iOS Simulator,id=430CDEBB-8ABA-4F35-A1D3-954C3E39EC81' \
  -derivedDataPath /tmp/nextstep-t14-dd -collect-test-diagnostics never \
  -parallel-testing-enabled NO test
```

结果：exit 0，`** TEST SUCCEEDED **`（-quiet 下 exit 0），81 个测试函数 / 242 个参数化用例全部通过，0 失败 0 跳过。新增覆盖：状态机 7×7 全转换表（allowed/reopen/isValid/requiresConfirmation）、29 条合法转换与 20 条非法转换的 repository 行为、update/delete cascade、详情 VM 的目标/确认/错误映射/删除、编辑器编辑模式。隔离 DerivedData 与 `-collect-test-diagnostics never` 仅用于绕开并发 agent 场景下 Xcode 收集模拟器诊断时的卡死。App 在分配模拟器上安装启动成功（4 个 tab 正常）。

### 决策与说明

- `ApplicationTransitionError` 定义在 Domain（与状态机同文件）；Repository 抛它，ViewModel 先做本地校验并把 repository 抛出的 typed error 映射为同一句中文。删除失败使用「删除失败，请重试」（spec 只给了保存失败示例）。
- `allowedTransitions` 返回 `[ApplicationStatus]`（规范顺序，便于 UI 直接展示），测试另外断言无重复；`requiresConfirmation` 对非法对返回 false。
- 状态历史页（15）、面试轮次 UI/repository（16）、关联岗位摘要与匹配摘要（17/21/22）、概览 dashboard 均未实现；详情中的下一个节点卡片已留出 ticket 16 插入 pending 轮次的位置。
- 编辑模式的未保存修改比较按 trim 后、即将保存的值与载入快照比较，改回原值不会误报；deadline 09:00 视为未选择具体时刻，保存后 instant 不变。
- 多个 `.sheet` 会互相覆盖，因此详情用一个 `PresentedSheet` 枚举驱动编辑与状态变更两个 sheet；状态 sheet 打开期间详情不弹错误 alert，错误在 sheet 内联显示。
- 新增测试辅助 `MutableDateProvider`（手动推进时钟）用于断言 `lastModifiedAt` 更新；其余测试仍用固定日期，无真实时钟/网络。

