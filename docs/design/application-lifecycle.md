# 申请生命周期与概览派生

申请追踪的核心约束是：**`Application.status` 是当前值，`StatusChange` 是历史事实源**。两者只在 `ApplicationRepository` 的同一次操作里更新，UI 不直接改状态。

## 七态状态机

状态 raw value：`wishlist / applied / oa / interview / offer / rejected / withdrawn`；界面文案：想投 / 已投 / OA/笔试 / 面试 / Offer / 已拒 / 已撤。

| from | 允许的普通 to |
|---|---|
| wishlist | applied、withdrawn |
| applied | wishlist（回退）、oa、interview、offer、rejected、withdrawn |
| oa | wishlist / applied（回退）、interview、offer、rejected、withdrawn |
| interview | wishlist / applied / oa（回退）、offer、rejected、withdrawn |
| offer | —（成功终态，无出口） |
| rejected | —（终态，只能「重新打开」） |
| withdrawn | —（终态，只能「重新打开」） |

- **允许跳级**：例如 applied → offer、oa → interview。
- **重新打开**：rejected → applied / oa / interview / offer；withdrawn → wishlist / applied / oa / interview / offer。重开必须二次确认并写 StatusChange。
- **活动态回退**（applied → wishlist、oa → applied、interview → oa 等）同样二次确认。
- 规则集中在纯 `ApplicationStateMachine`：`allowedTransitions(from:)`、`isValidTransition(from:to:)`、`reopenTargets(from:)`、`requiresConfirmation(from:to:)`。状态变更 sheet 与 repository 共用这套规则，转换表不复制。
- 非法转换抛 `ApplicationTransitionError`，UI 映射「当前状态不能这样变更」。

## StatusChange

- append-only：`fromStatus`、`toStatus`、`changedAt`、可选 `note`；初始记录 `fromStatus = nil`。
- 创建申请时在同一 save 内写初始记录，`changedAt` 使用用户填写的状态日期（可补录过去）。
- 每次状态变化写一条；备注、deadline、面试轮次的修改 **不写** 状态历史，只更新 `lastModifiedAt`。
- `appliedAt` 是派生值：第一条 `toStatus == applied` 的 `changedAt`，不落库。
- 状态历史页是唯一的 UIKit/MVC 页面：`UITableViewDiffableDataSource` 按 `changedAt` 降序、同时间 `id` 兜底展示 from → to、时间、备注；无 ViewModel，直接注入 repository。

## Deadline 与面试轮次

- `Application.deadline` 表示**下一个关键节点**（投递、OA、offer 回复等），日期 + 可选 HH:mm；缺省时刻按当天 09:00。面试时间不属于 deadline。
- `InterviewRound` 记时间、形式（电话/视频/现场/其他）、名称、联系人、备注、结果（待定/通过/未通过/取消）。
- 轮次按 `scheduledAt` 升序、同时间 `id` 兜底；过去的轮次弱化显示。
- 添加未来轮次时，若当前状态是 applied 或 oa，追问是否标记为「面试中」；仅当状态机允许时才提示。轮次失败不会自动把申请标为 rejected。
- 保存轮次时同步指针：`deadline` 为空，或轮次时间早于 `deadline`，就把该时刻写入；改 `deadline` 不反向改轮次，也不做自动对账（ADR-0005 决策 4）。
- 申请详情「下一个节点」就是 `deadline` 本身（ADR-0005）；为空或申请已终结时显示「还没有下一个节点」。已过的指针是可见状态，不是空态。
- 节点文案：同刻存在轮次就取那轮的 `label`（`label` 为空取「面试」，不筛 `result`），否则一律「截止」；不按 `status` 推导。

## 概览派生

概览不配 ViewModel：`@Query` 取全部 `Application`，纯 `DashboardBuilder` 输出：

- **今天事件**：此刻到明天 00:00 之间的 `deadline`，一个申请最多一条。
- **接下来 7 天**：明天起，到「今天 + 8 天 00:00」为止。
- 过去的事件不进入议程，改由议程上方一行「N 个申请的节点已过，去更新」报数。
- 终态 rejected / withdrawn 既不产生事件，也不计入已过报数；offer 的答复截止仍计入。
- 事件按时间升序；同时间按 `application.id`。
- **计数**：进行中 / 接下来 7 天 / Offer。`upcomingCount` 与议程同源——一个申请最多一条事件，所以它恒等于议程条数，不另算一遍。
- **最近更新**：全部状态按 `lastModifiedAt` 降序取前 5，同时间 `id` 兜底。

首屏顺序固定为：已过报数行（`N > 0` 才出现）→ 事件 → 一行计数 → 最近更新；没有事件时显示轻量提示，不用图表挤占注意力。

## 仓库职责

`ApplicationRepository` 是申请写的唯一入口：

- 创建申请并写初始 StatusChange；
- 修改快照字段/备注/deadline 并更新 `lastModifiedAt`；
- 删除申请（cascade 轮次与历史）；
- `changeStatus(of:to:note:at:)`：校验 → 更新 `Application.status` + `lastModifiedAt` → 写 StatusChange；
- 增删改 InterviewRound 并更新 `lastModifiedAt`；
- 按申请读取 StatusChange；按 JobPosting 查已有申请（导入去重）。

导入去重：岗位已有 wishlist/applied/oa/interview 的申请 → 只提供「查看」，不重复创建；只有终态时才允许「再次导入为申请」。

## 列表筛选与排序

- 全部 / 进行中 / 接下来 7 天 / Offer / 已结束。
- 进行中 = wishlist、applied、oa、interview；接下来 7 天 = `deadline` 落在 `[此刻, 今天+8 天 00:00)` 且状态不是 rejected/withdrawn；已结束 = rejected、withdrawn。
- 全部 / 进行中 / 接下来 7 天：有节点的在前——未来的按时间升序，已过的按时间降序（最近过期的先）；无节点按 `lastModifiedAt` 降序；同时间 `id` 兜底。
- Offer / 已结束：`lastModifiedAt` 降序，同时间 `id` 兜底。

## 删除与恢复

- 删除申请会 cascade 删除面试轮次和状态历史；关联的 JobPosting 保留。
- 删除 JobPosting 只把 `Application.jobPosting` 置空，快照字段（公司、职位、链接、地点）仍在。
- 所有数据只在本机；杀进程重启后申请、状态历史、面试轮次、画像和岗位缓存都会保留。
