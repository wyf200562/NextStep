# 表现层与界面决策

v1 的界面目标是「行动优先、解释清楚、不把用户当新手」：概览先回答今天要做什么，Discover 先说明数据只是样本，匹配结果必须能解释到技能和规则。

## 页面形态

不是每个页面都配 ViewModel。规则如下：

| 页面 | 形态 | 原因 |
|---|---|---|
| 概览 | `@Query` + 纯 `DashboardBuilder` | 只读派生，无异步写操作 |
| 申请列表 | `@Query` + `@State` 筛选 + 纯 `ApplicationListBuilder` | 只读列表 |
| 申请详情 | `ApplicationDetailViewModel` | 状态流转、轮次、错误处理 |
| 申请新建/编辑 | `ApplicationEditorViewModel` | 表单校验、多步保存 |
| Discover | `DiscoverViewModel` | 缓存、刷新、匹配、错误态 |
| 岗位详情 | `JobDetailViewModel` | 加载、匹配、导入去重 |
| 手动粘贴 JD | `ManualImportViewModel` | 表单校验、保存 |
| 我的 | `ProfileViewModel` | draft、保存、门槛提示 |
| 状态历史 | UIKit `StatusHistoryViewController` + diffable data source | 唯一 UIKit/MVC 展示点，无 ViewModel |
| 根容器/路由 | 无 ViewModel | `AppRouter` 只持有选中 tab 和待处理路由 |

相关 ADR：[0004 表现层边界](../adr/0004-presentation-boundaries.md)。

## 跨 tab 导航

`AppRouter`（`@Observable @MainActor`）只持有一个 `selectedTab` 和最多一个 `pendingRoute`；每个 tab 自己的 `NavigationStack` 路径与筛选状态仍由该 tab 的 View 持有：

- 概览空状态「去 Discover 看看」→ 切到「发现」；
- 概览事件行、最近更新行 → 切到「申请」并 push 详情；
- 概览三个计数 → 切到「申请」并应用对应筛选；
- Discover 导入成功 / 查看已有申请 → 切到「申请」并 push 详情；
- Discover 的「去完善画像」→ 切到「我的」。

## 设计语言

- 卡片/圆角表面 + 系统语义色，自动支持深浅色；状态徽标、分数 pill、技能标签、样本头图沿用原型。
- 字号使用系统 Dynamic Type 语义样式；正文可选中的 JD 文本；图标按钮有 accessibility label。
- 不使用自定义动效；系统控件优先。

## 空状态与错误文案

每个主要页面都有明确的空状态和中文错误状态：

- 概览：无申请 → 英雄区 +「添加第一份申请」「去 Discover 看看」，不放 1/2/3 步骤；无事件 →「7 天内没有截止或面试。去 Discover 看看新岗位。」
- 申请列表：按筛选给出不同空状态文案，始终保留两个入口。
- Discover：无岗位 →「还没有岗位」+ 粘贴 JD + 重试；只看实习无结果 →「今天的样本里没有实习」+ 查看全部 + 粘贴 JD；刷新失败/配额/太频繁分有缓存（琥珀提示）与无缓存（全屏）两种。
- 岗位详情：画像不足 → gate 卡片 +「去完善画像」；词典不可用 →「匹配暂不可用」；加载失败 → 重试；JD 为空 →「暂无 JD 正文」。
- 我的：画像加载失败 → 重试；词典不可用 → 禁用技能选择、其他字段仍可保存；保存失败 → 内联「保存失败，请重试」。
- 状态历史：空 →「还没有状态记录」；失败 →「加载失败」+ 重试。
- 启动：本地数据无法打开 → 阻塞错误页 + 重试。

错误映射集中在 ViewModel，原始 error 只写入 `os.Logger`。`.offline` / `.timedOut` / `.rateLimited` / `.server(code)` / `.decoding` / `.invalidInput` 都有固定中文文案。

## 二次确认

删除申请、状态回退、重新打开、放弃未保存修改、再次导入终态岗位、Debug 清空演示数据都要求二次确认；删除申请会说明「面试轮次和状态历史会一起删除，关联岗位会保留」。

## 匹配展示

- 列表卡片：分数 pill、分档、匹配 X/Y、最多 3 个匹配技能、最多 2 个缺失技能、`+N`、一句原因。
- 详情 hero：分数 / 100、分档、低置信度标记、四项分项条、原因、JD 高亮。
- ineligible 不展示分数 hero 和分项条，只展示「岗位不符合」原因与技能命中数；不会出现假 0 分。
- 画像不足时 eligible 组不显示分数，显示「完善画像后查看匹配」，岗位仍可浏览、导入。

## 可访问性

- 状态徽标、分数 pill、分项条、技能标签都有组合后的 accessibility label（如「匹配分 82」「技能 54 / 60」）。
- 可点击行用 `.contentShape(Rectangle())` 扩大命中区域。
- 主要按钮使用系统 bordered / borderedProminent 样式，保证 Dynamic Type 与对比度。
