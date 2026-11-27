# 概览看板（DashboardBuilder）

概览是行动优先的首屏：先回答「今天和这周还有什么节点」，再给三个进展计数和最近改动。页面自己不持有业务状态——`@Query` 取全部 `Application`，纯 `enum DashboardBuilder` 把它折算成一个只读的 `DashboardSnapshot`，View 只负责摆放（来源：NextStep/Features/Overview/OverviewView.swift:6-21）。

## 职责与数据流

```text
@Query [Application]
      │
      ▼
DashboardBuilder.snapshot(applications:now:calendar:)   ← 纯函数, 无 I/O
      │
      ▼
DashboardSnapshot  ──► OverviewView ──► DashboardEventRow / DashboardRecentRow
```

- 唯一入口是 `snapshot(applications:now:calendar:)`，返回 `DashboardSnapshot`（来源：NextStep/Features/Overview/DashboardBuilder.swift:38-83）。
- 调用方是 `OverviewView.body`，每次 body 求值重新算一遍，没有缓存层（来源：NextStep/Features/Overview/OverviewView.swift:16-21）。
- `now` / `calendar` 来自 `container.dateProvider`：生产是系统时钟，测试与 Preview 用 `FixedDateProvider`（来源：NextStep/Features/Overview/OverviewView.swift:17-20；NextStep/Core/DateProvider.swift:20-31）。
- 无 ViewModel：概览的每个动作不是 router 跳转就是共享的编辑 sheet，没有异步加载、错误态或表单校验（来源：NextStep/Features/Overview/OverviewView.swift:10；docs/adr/0004-presentation-boundaries.md:3；docs/design/presentation.md:11）。

## Snapshot 是派生值，不落库

`DashboardSnapshot` 只有七个字段：`todayEvents`、`upcomingEvents`、`activeCount`、`upcomingCount`、`overdueCount`、`offerCount`、`recentApplications`，再加一个 `hasEvents` 计算属性（来源：NextStep/Features/Overview/DashboardBuilder.swift:25-35）。

它不持久化，因为它是「此刻」的函数：同一批申请在不同 `now` 下答案不同。ADR-0005 否掉「保留两个源、派生出下一个节点」的方案时，理由之一正是派生结论无法落库，三个消费者各自实现边界后已经给出互相矛盾的答案（来源：docs/adr/0005-deadline-is-the-next-node.md:7）。把派生收进 `DashboardBuilder` 与 `ApplicationListBuilder` 两个纯函数，边界就只有一份实现。

`ApplicationDeadlineWindow` 因此被定位为 upcoming 边界的唯一住所（来源：NextStep/Features/Applications/ApplicationDeadlineWindow.swift:3）。

## 只有 deadline 产生事件

- 一个申请最多一条事件，因为 `deadline` 就是「下一个节点」，而字段本身只有一个（来源：docs/adr/0005-deadline-is-the-next-node.md:3；../../GLOSSARY.md 的 Deadline / Overdue 词条）。
- `InterviewRound.scheduledAt` 只是那场面试的历史记录与排序依据，退出「即将到来」的计算。测试断言：有未来轮次但没有 deadline，不产生事件、不计数（来源：NextStepTests/Features/DashboardBuilderTests.swift:127-140）。
- 轮次与 deadline 同刻时仍只产出一条事件，标题取轮次名（来源：NextStepTests/Features/DashboardBuilderTests.swift:108-125）。
- 已过的事件不进入议程，只折成 `overdueCount` 和议程上方一行「N 个申请的节点已过，去更新」；`count > 0` 才出现（来源：NextStep/Features/Overview/OverviewView.swift:107-136）。
- 终态 `rejected` / `withdrawn` 既不产生事件也不计入已过；`offer` 不算终态（`isEnded` 只含前两者），offer 的答复截止仍会计入（来源：NextStep/Features/Applications/ApplicationListFilter.swift:34-40；NextStepTests/Features/DashboardBuilderTests.swift:337, 350-354）。

## 时间窗口与边界

| 窗口 | 区间 | 实现 |
|---|---|---|
| 今天 | `[now, 明天 00:00)` | `event.date < tomorrowStart`（DashboardBuilder.swift:44-45, 71） |
| 接下来 7 天 | `[明天 00:00, 今天+8 天 00:00)` | `event.date >= tomorrowStart`（DashboardBuilder.swift:72） |
| 事件候选集 | `[now, 今天+8 天 00:00)` | `isWithinUpcomingWeek`（ApplicationDeadlineWindow.swift:5-15, 39-48） |

下界是**时刻**、上界是**天边界**，ADR-0005 说明这是有意的：一个回答「哪些还没过去」，一个回答「数到第几天」（来源：docs/adr/0005-deadline-is-the-next-node.md:16）。

比较在精确时刻上做，所以 09:00 的 deadline 在 09:00:00 就变成已过，而不是等这一分钟走完（来源：NextStep/Features/Applications/ApplicationDeadlineWindow.swift:17-24）。测试用固定「今天」2026-11-09 / Asia/Shanghai 钉住边界（来源：NextStepTests/Features/DashboardBuilderTests.swift:7-22）：

- `deadline == now` 仍在今天议程内；比 `now` 早一分钟的算已过（来源：NextStepTests/Features/DashboardBuilderTests.swift:75-88）。
- 今天 23:59 进「今天」；明天 00:00 进「接下来 7 天」；第 7 天 23:59 仍在内；第 8 天 00:00 外出（来源：NextStepTests/Features/DashboardBuilderTests.swift:90-106, 316-367）。
- 当天 00:00 的 deadline 在任何「当天上午」的用例里都已过期，不算事件（来源：NextStepTests/Features/DashboardBuilderTests.swift:223）。

日历算不出「明天 00:00」时整体退化为全零快照；`window(now:calendar:)` 在上界不大于 `now` 时退化为空区间，两个防御都不抛错（来源：NextStep/Features/Overview/DashboardBuilder.swift:45-55；NextStep/Features/Applications/ApplicationDeadlineWindow.swift:9-13）。

## 四个计数

| 字段 | 定义 | 说明 |
|---|---|---|
| `activeCount` | `status.isActive` 的申请数 | wishlist / applied / oa / interview，**不含 offer**（来源：ApplicationListFilter.swift:25-32） |
| `upcomingCount` | `events.count` | 不重新过滤申请，直接数议程条目 |
| `overdueCount` | `isOverdue` 的申请数 | `deadline < now` 且状态不是 rejected / withdrawn（来源：ApplicationDeadlineWindow.swift:26-30） |
| `offerCount` | `status == .offer` | 与时间无关，纯状态计数（DashboardBuilder.swift:80） |

`upcomingCount` 取事件条数而不是再过滤一遍申请，代码注释给了理由：议程已经应用过同一个谓词，数事件能让数字和行**永不**互相矛盾（来源：NextStep/Features/Overview/DashboardBuilder.swift:74-76；docs/design/application-lifecycle.md:52）。测试还把它与申请列表 `.upcoming` 筛选的行数对齐，防止两处窗口漂移（来源：NextStepTests/Features/DashboardBuilderTests.swift:228-250）。代价是：`upcomingCount` 包含今天的事件，而「接下来 7 天」那张卡片只列明天之后的行——今天的事件在「今天」卡片里，数字仍是两段之和。

`overdueCount` 只看 `deadline < now`，与「8 天」上界无关：昨天 23:59 计入，第 8 天 00:00 既不在议程里也不算过期（来源：NextStep/Features/Applications/ApplicationDeadlineWindow.swift:26-30；NextStepTests/Features/DashboardBuilderTests.swift:329-330, 360-365）。

## 事件模型与确定性排序

`DashboardEvent` 只有 `id`、`application`、`date`，外加计算属性 `applicationID` 和 `title`（来源：NextStep/Features/Overview/DashboardBuilder.swift:8-20）。

- `id` 是复合字符串 `"deadline-<uuid>"`：单一事件来源下，前缀是命名空间，后缀保证跨申请唯一且稳定，方便未来做 diffable 更新；当前 View 用下标 `ForEach(events.indices)` 渲染，尚未读取这个 id（来源：DashboardBuilder.swift:62；OverviewView.swift:167）。
- `title` 委托给 `ApplicationNodeCopy.title(forNodeAt:of:)`：同刻存在轮次就取那轮的 `label`（空白则「面试」，不筛 `result`，多轮同刻取 id 最小），否则一律「截止」；该函数从不读 `status`（来源：NextStep/Features/Applications/ApplicationNodeCopy.swift:26-48）。
- 排序是 `date` 升序，同刻按 `application.id.uuidString` 升序（来源：DashboardBuilder.swift:93-99）。这与申请列表的 tie-break 相同，所以概览和列表的顺序可以对齐（来源：NextStep/Features/Applications/ApplicationListBuilder.swift:92, 109）。
- `recentApplications` 按 `lastModifiedAt` 降序取前 5，同刻按 id 升序，且跨全部状态——已拒、已撤也会出现（来源：DashboardBuilder.swift:81, 85-91；NextStepTests/Features/DashboardBuilderTests.swift:252-270）。

## 确定性与可测性

`DashboardBuilder` 内部不调用 `Date()`、不读 `Calendar.current`、不碰 `ModelContext`：`now` 与 `calendar` 全部从参数进来（来源：DashboardBuilder.swift:37-43）。这条约束换来两件事：测试可以在任意时区、任意时刻复现边界；生产环境仍可通过 `DateProvider` 注入系统时钟（来源：NextStep/Core/DateProvider.swift:3-7）。界面上的「今天 / 明天」标签同样接收 `now` 与 `calendar`，不各自取时钟（来源：NextStep/Features/Overview/DashboardRows.swift:5-18）。

## 消费方与 UI 映射

| Snapshot | UI | 动作 |
|---|---|---|
| `overdueCount` | 议程上方一行提示 | 跳到申请列表 `.all`（没有专门的逾期筛选） |
| `todayEvents` / `upcomingEvents` | 「今天」「接下来 7 天」两张卡片 | 点行 → 切 tab 并 push 该申请详情 |
| `activeCount` / `upcomingCount` / `offerCount` | 「进展」一行三个数字 | 分别应用 `.active` / `.upcoming` / `.offer` 筛选 |
| `recentApplications` | 「最近更新」5 行 | 点行 → 申请详情 |

来源：NextStep/Features/Overview/OverviewView.swift:140-266；跨 tab 路由的约定见 docs/design/presentation.md:24-32。

`applications.isEmpty` 时整块看板换成英雄区空态；申请不为空但 `hasEvents == false` 时，只把议程换成一句「接下来 7 天没有节点」（来源：OverviewView.swift:27-34, 141-163）。

## 测试锁住的不变量

- 一个申请最多一条事件，轮次再多也不会变多（DashboardBuilderTests.swift:108-125）。
- 只有 deadline 没有轮次同样成立——标题退化成「截止」（DashboardBuilderTests.swift:157-182）。
- 终态申请对整个快照不可见（DashboardBuilderTests.swift:142-155）。
- 空输入得到全零、无事件、无最近更新（DashboardBuilderTests.swift:272-284）。
- 黄金路径把「加轮次 → 指针前移 → 派生概览 → 重开 store」串起来：轮次把 `deadline` 推到更早的时刻，概览只出一条事件且标题是「一面」，重启后仍然如此（来源：NextStepTests/GoldenPathIntegrationTests.swift:175-196, 231-241）。

## 相关

- 生命周期与状态机：[application-lifecycle.md](application-lifecycle.md)
- 页面形态与路由：[presentation.md](presentation.md)
- 决策依据：[ADR 0005 deadline 即下一个节点](../adr/0005-deadline-is-the-next-node.md)、[ADR 0004 表现层边界](../adr/0004-presentation-boundaries.md)
