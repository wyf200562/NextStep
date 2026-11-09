# 16: 面试轮次与下一节点

**What to build:** 申请详情可添加 / 编辑 / 删除 InterviewRound，表单含时间（日期 + 时刻）、形式（电话 / 视频 / 现场 / 其他）、名称、联系人、备注、结果（默认待定）。轮次按 scheduledAt 升序、同时间用 id 兜底，过去轮次弱化显示。添加未来轮次后，若 Application 状态是 applied 或 oa，弹出「是否标记为面试中？」；确认后走状态机合法转换到 interview，取消不改；wishlist 不弹；interview / offer 不弹；rejected / withdrawn 不自动重开。编辑轮次或结果只更新 lastModifiedAt，不自动改状态；某轮 failed 不自动 rejected。申请详情的下一节点卡片与申请列表排序同时考虑 Deadline 和 pending 轮次。

**Blocked by:** 14（申请详情与状态流转）

**Status:** resolved

- [x] 轮次 CRUD 与表单字段、默认 pending 结果；任何编辑更新 lastModifiedAt。
- [x] 轮次按 scheduledAt 升序、同时间 id 兜底；过去轮次弱化。
- [x] 「标记为面试中」提示条件严格：applied / oa + 未来轮次；确认走 changeStatus；取消或其他状态不弹。
- [x] 轮次结果与失败均不自动改 Application 状态。
- [x] 下一节点卡片取更早的 Deadline 或 pending 轮次；申请列表排序使用最近 upcoming 节点。
- [x] 单测覆盖提示条件、下一节点合并与排序。

## Answer

日期：2026-11-09。实现 commit：`065ed10`（`ticket/16-interview-rounds`，基于 integration/nextstep-v1 `3f090ae`）。

### 交付内容

- **Repository**：`SwiftDataApplicationRepository` 实现 `addInterviewRound` / `updateInterviewRound` / `deleteInterviewRound`。添加时插入 `InterviewRound`、设置 `round.application` 反向关系；三种写入都在同一次 save 内把 owning `Application.lastModifiedAt = DateProvider.now`（删除前先捕获 owner）。任何轮次写入都不改 `Application.status`、不写 `StatusChange`；失败 rollback 并抛 `RepositoryError.saveFailed`。
- **详情 UI 轮次区**：按 `scheduledAt` 升序、同时间 `id` 兜底展示（`ApplicationDetailViewModel.rounds`）；过去轮次整行 `secondary` 弱化；每行显示名称/结果/形式/时间/联系人。点击行编辑，左滑删除（无需二次确认），「添加面试轮次」行打开表单。表单字段：日期* + 时刻*、形式*（电话/视频/现场/其他，默认视频）、名称、联系人、备注、结果（默认待定）；文本 trim 后空串存 nil；有未保存修改时放弃需二次确认。
- **「标记为面试中」提示**：`ApplicationDetailViewModel.addRound` 保存成功后，若 `scheduledAt > now`（严格未来）且添加前状态为 `.applied` / `.oa`，设置 `isPromptingMarkAsInterview`；详情在表单 sheet 完全 dismiss 后弹 alert「是否标记为面试中？」。确认调用既有 `changeStatus(to: .interview, note: nil, at: now)`（状态机校验、写 StatusChange）；取消仅清除提示。wishlist / interview / offer / rejected / withdrawn 与过去/当前时刻轮次一律不弹；rejected / withdrawn 不会自动重开。编辑/删除轮次与 failed 结果均不改状态。
- **下一节点**：新增纯 helper `ApplicationNextNode.nearest(for:at:)` 作为唯一规则——取 `>= now` 的更早 Deadline 与 pending 轮次；同 instant Deadline 优先，轮次同 instant 用 id 兜底；结果携带轮次 label。详情卡片显示「截止」或「面试 · 一面」+ 时间，无 upcoming 时显示弱化中文「暂无即将到来的截止或面试」。`ApplicationListBuilder` 改为复用该 helper（`NearestNode` typealias），列表排序继续按最近 upcoming 节点升序、无节点按 `lastModifiedAt` 降序、同时间 id 兜底。
- **ViewModel**：`ApplicationDetailViewModel` 新增 `rounds`、`nextNode`、`currentDate`、`addRound` / `updateRound` / `deleteRound`、`isSavingRound`、`isPromptingMarkAsInterview`、`confirmMarkAsInterview` / `cancelMarkAsInterviewPrompt`；错误沿用「保存失败，请重试」「删除失败，请重试」。表单草稿由小型 `InterviewRoundEditorViewModel`（`@Observable @MainActor`，无 repository）承载，保存意图仍由详情 VM 拥有。
- **测试**：Repository 新增 add/update/delete 轮次（关系、字段、`lastModifiedAt`、status 与 statusChanges 不变）；详情 VM 新增 next-node 合并/边界/并列、轮次排序、提示条件（applied/oa 弹；wishlist/interview/offer/rejected/withdrawn 不弹；now 与过去不弹）、确认写状态、取消无写入、编辑/删除轮次不改状态、失败文案。

### 关键文件

- `NextStep/Data/Repositories/SwiftDataApplicationRepository.swift`
- `NextStep/Features/Applications/ApplicationNextNode.swift`（新增）
- `NextStep/Features/Applications/ApplicationDetailViewModel.swift`、`ApplicationDetailView.swift`
- `NextStep/Features/Applications/InterviewRoundEditorViewModel.swift`、`InterviewRoundEditorView.swift`（新增）
- `NextStep/Features/Applications/ApplicationListBuilder.swift`
- `NextStepTests/Data/ApplicationRepositoryTests.swift`、`NextStepTests/Features/ApplicationDetailViewModelTests.swift`、`NextStepTests/Support/FakeApplicationRepository.swift`

### 验证

```bash
xcodebuild -project NextStep.xcodeproj -scheme NextStep \
  -destination 'platform=iOS Simulator,id=55BECEC5-7590-4465-A6AD-129E521B729C' \
  -derivedDataPath /tmp/nextstep-t16-dd -collect-test-diagnostics never \
  -parallel-testing-enabled NO test
```

结果：exit 0，`** TEST SUCCEEDED **`，`Test run with 184 tests in 18 suites passed`（Swift Testing 展开后的用例数；0 失败 0 跳过）。App 在分配模拟器安装启动成功，4 个 tab 正常显示。

### 决策与说明

- `ApplicationNextNode` 从 ticket 13 的 `ApplicationListBuilder` 私有逻辑提取为共享纯 helper，详情卡片与列表排序共用同一套规则，避免两处规则漂移；列表原测试全部保持通过。
- 提示基于「添加前」状态判断（`statusBeforeSave`），因为轮次写入本身不改状态；未来轮次定义为严格 `> now`，恰好等于 now 不弹。
- 表单的「添加/编辑」不做 `status` 提示的二次触发：只有添加未来轮次会提示，编辑轮次（即使改到未来）不提示，符合 spec「添加未来轮次后」。
- 轮次删除按 ticket 说明不要求二次确认；表单放弃未保存修改仍按 spec §11 二次确认。
- 为避开 sheet 未完全关闭时 alert 被吞的问题，详情在 `.sheet(onDismiss:)` 中把 ViewModel 的提示意图转成视图层 alert 状态；alert 按钮显式确认/取消 VM 意图。
- 状态历史页（15）、概览 dashboard（17）、关联岗位/匹配摘要（21/22）不在本票范围；`ApplicationDetailView.swift` 的改动集中在下一个节点卡片、追加的轮次 Section、sheet case 与 alert，便于与并行的 ticket 15 合并。
- 编辑 `ApplicationDetailView` 时把 action error alert 的抑制条件从「仅状态 sheet」放宽为「任意 sheet」；其他 sheet 内已有自己的内联错误展示。
