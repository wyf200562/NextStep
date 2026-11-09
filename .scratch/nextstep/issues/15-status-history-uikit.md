# 15: 状态历史 UIKit 页

**What to build:** 申请详情的「状态历史」入口打开 sheet，内部由 UINavigationController 承载唯一的 UIKit/MVC 页面，无 ViewModel。页面用 UITableViewDiffableDataSource 展示该申请的 StatusChange：按 changedAt 降序、同时间用 id 兜底；row 显示 from → to、时间、备注；初始记录显示「创建 → X」；状态名用中文。空状态「还没有状态记录」、加载失败「加载失败」+ 重试、导航栏 Done 关闭。状态变化后重新打开会重新拉取。

**Blocked by:** 14（申请详情与状态流转）

**Status:** resolved

- [x] 详情页入口打开 sheet；sheet 内嵌 UINavigationController 与 StatusHistoryViewController。
- [x] diffable data source 排序正确；格式化逻辑为纯 helper；cell 只负责展示。
- [x] 初始记录、普通记录、备注、中文状态名正确。
- [x] 空状态 / 错误重试 / Done 行为正确；页面无 ViewModel。
- [x] ApplicationRepository 提供按 application 读取 StatusChange 的能力，页面通过注入的 repository 访问，不直接碰 ModelContext。

## Answer

日期：2026-11-09。实现 commit：`d1b1b22`（`ticket/15-status-history`，基于 integration/nextstep-v1 `3f090ae`）。

### 交付内容

- **StatusHistoryViewController（UIKit/MVC，无 ViewModel）**：`UIViewController` + `UITableView(style: .insetGrouped)` + `UITableViewDiffableDataSource<Section, StatusHistoryRowModel>`。注入 `ApplicationRepository` 与 `applicationID`，`viewDidLoad` 先 `application(id:)` 取申请，再 `statusChanges(for:)` 取历史；不接触 `ModelContext`。每次 sheet 打开都会创建新 controller 并重新拉取，因此状态变化后重新打开看到最新历史。
- **排序**：直接使用 repository 返回顺序（`changedAt` 降序、同时间 `id` 升序），按顺序 append 到 snapshot；该排序由 `SwiftDataApplicationRepository.statusChanges(for:)` 提供并已有仓库单测 `statusChangesSortByDateThenID` 覆盖。
- **纯格式化 helper**：`StatusHistoryRowModel`（`nonisolated struct`）把一条 StatusChange 转成视图就绪内容：`transitionText`（初始记录「创建 → X」，普通记录「A → B」，状态名用中文 displayName）、`timeText`（注入 Calendar/Locale，格式「yyyy年M月d日 HH:mm」）、`noteText`（trim 后空白视为无备注）。cell 只把三个字符串赋给 label，不含格式化逻辑。
- **cell**：`StatusHistoryCell` 竖排 标题 / 时间 / 备注，支持 Dynamic Type 与多行；无备注时隐藏备注 label；read-only 无选中态。
- **空状态 / 错误态 / Done**：空状态用 `UIContentUnavailableConfiguration.empty()` 显示「还没有状态记录」；加载失败显示「加载失败」+「加载失败，请稍后重试」+「重试」按钮（重新拉取）；导航栏 Done 通过 `dismiss(animated:)` 关闭 sheet。
- **SwiftUI 入口**：`StatusHistorySheet: UIViewControllerRepresentable` 返回 `UINavigationController(rootViewController: StatusHistoryViewController(...))`；`ApplicationDetailView` 在备注后追加一个「状态历史」Section/按钮，并复用既有 `PresentedSheet` 枚举增加 `.statusHistory` case（保持与并行 ticket 16 的改动区域分离，diff 仅 3 处小追加）。
- **Repository**：按 application 读取 StatusChange 的 `statusChanges(for:)` 已在 ticket 14 实现，本票直接复用，未重复添加方法。

### 关键文件

- `NextStep/Features/StatusHistory/StatusHistoryViewController.swift`
- `NextStep/Features/StatusHistory/StatusHistoryCell.swift`
- `NextStep/Features/StatusHistory/StatusHistoryRowModel.swift`
- `NextStep/Features/StatusHistory/StatusHistorySheet.swift`
- `NextStep/Features/Applications/ApplicationDetailView.swift`（入口按钮 + sheet case）
- `NextStepTests/Features/StatusHistoryRowModelTests.swift`

### 验证

```bash
xcodebuild -project NextStep.xcodeproj -scheme NextStep \
  -destination 'platform=iOS Simulator,id=430CDEBB-8ABA-4F35-A1D3-954C3E39EC81' \
  -derivedDataPath /tmp/nextstep-t15-dd -collect-test-diagnostics never \
  -parallel-testing-enabled NO test
```

结果：`** TEST SUCCEEDED **`，167 个测试函数 / 348 个参数化用例全部通过，0 失败 0 跳过（新增 3 个测试函数、8 个用例：初始/普通记录与中文状态名 6 例、备注 trim/缺失、固定时区时间格式）。App 在分配模拟器安装启动成功（4 个 tab 正常）。未写 XCUITest。

集成分支合并：`4110114`（Discover 相关切片）合入后无冲突，全量重跑 182 个测试函数 / 378 个参数化用例全部通过，0 失败 0 跳过。

### 决策与说明

- 排序不在页面内重排：spec 明确 repository 提供已排序历史，页面按 snapshot 顺序展示；既有仓库测试已覆盖降序与同时间 id 兜底。
- 时间格式用显式 `DateFormatter(dateFormat:)` 并注入 Calendar/Locale，测试用 Asia/Shanghai 与 UTC 两个固定时区断言跨日转换，避免依赖系统时区。
- 页面按 ticket 要求只注入 repository + applicationID；Calendar/Locale 为带默认值的可选注入参数，仅用于确定性测试，不改变生产调用。
- 入口沿用详情页单一 `PresentedSheet` 枚举（多 `.sheet` 会互相覆盖）；ticket 16 若也新增 case，预计仅在枚举与 switch 末尾产生可轻松合并的冲突。
- 未实现面试轮次（16）、概览 dashboard（17）、匹配摘要（22）；状态历史页不提供任何修改状态的入口。
