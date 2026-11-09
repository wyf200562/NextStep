# 17: 概览（行动优先）

**What to build:** 概览 tab 首屏回答「今天和未来 7 天要做什么」：日期 overline + 大标题「概览」；「今天」与「接下来 7 天」事件列表；一行三个计数（进行中 / 7 天内截止 / Offer）；「最近更新」前 5。事件来自非终态 Application 的 Deadline 与 pending InterviewRound（offer 的答复截止也算），今天已过去的事件仍显示并标「已过」；合并按时间升序，同时间按 application.id、Deadline 先于面试、轮次 id 兜底；7 天内计数按去重后的 Application 数量。点击事件或最近更新切到申请 tab 并打开详情；点击计数切到申请 tab 并带对应筛选；无事件显示「7 天内没有截止或面试。去 Discover 看看新岗位。」；无申请显示英雄式空状态与两个入口。不做状态分布图、漏斗、环形图。

**Blocked by:** 16（面试轮次与下一节点）

**Status:** ready-for-agent

- [ ] DashboardBuilder 为纯函数，接收 Application 集合、now、Calendar；表驱动测试覆盖今天 / 未来 7 天窗口、合并排序、终态排除、offer deadline、计数去重、最近 5、空数据。
- [ ] 概览变体 A 布局，行动事件优先，计数压缩成一行。
- [ ] 跨 tab 路由：事件 / 最近更新 → 申请详情；计数 → 对应筛选；空状态 → Discover / 新建申请。
- [ ] 今天已过事件标记「已过」；面试事件标题带轮次 label。
- [ ] 空事件与空数据文案正确；不出现 1/2/3 步骤。
