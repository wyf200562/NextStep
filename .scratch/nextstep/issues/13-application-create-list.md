# 13: 申请创建与列表

**What to build:** 用户可以从空状态新建第一份申请，填写公司、职位、初始状态（7 选 1）、状态日期、Deadline（日期 + 可选时刻）、岗位链接、地点、备注；保存时写入初始 StatusChange（fromStatus = nil）并出现在申请列表。列表支持全部 / 进行中 / 临近截止 / Offer / 已结束筛选，按最近 upcoming 节点（Deadline 或 pending InterviewRound）升序、无节点按 lastModifiedAt 降序排序，同时间用 id 兜底；顶部显示「N 份申请 · M 份进行中」摘要；筛选无结果时显示对应空状态与两个入口。点击行进入只读详情壳（公司、职位、状态、Deadline、备注），完整详情在 14 补齐。数据杀进程重启后仍在。

**Blocked by:** 12（工程脚手架与领域模型）

**Status:** ready-for-agent

- [ ] 空状态含「添加第一份申请」「去 Discover 看看」，不出现 1/2/3 步骤说明。
- [ ] 新建表单字段完整；初始状态可选全部 7 种；非 wishlist 时显示状态日期，默认今天、可补录过去。
- [ ] Deadline 为日期 + 可选 HH:mm，缺省 09:00；岗位链接填写时必须是合法 URL；公司、职位 trim 后非空；校验失败内联显示。
- [ ] 保存写初始 StatusChange，changedAt 使用状态日期；Application 快照字段与 lastModifiedAt 正确。
- [ ] 列表五筛选规则、排序与 tie-breaker 符合 spec；行显示公司、职位、状态徽标、最近节点、最近更新时间。
- [ ] 摘要与各筛选空状态；保存或点击行进入只读详情壳（14 起为完整详情）。
- [ ] 杀进程重启后数据仍在。
- [ ] 单测覆盖筛选规则、排序、初始 StatusChange 与表单校验（repository 层）。
