# 16: 面试轮次与下一节点

**What to build:** 申请详情可添加 / 编辑 / 删除 InterviewRound，表单含时间（日期 + 时刻）、形式（电话 / 视频 / 现场 / 其他）、名称、联系人、备注、结果（默认待定）。轮次按 scheduledAt 升序、同时间用 id 兜底，过去轮次弱化显示。添加未来轮次后，若 Application 状态是 applied 或 oa，弹出「是否标记为面试中？」；确认后走状态机合法转换到 interview，取消不改；wishlist 不弹；interview / offer 不弹；rejected / withdrawn 不自动重开。编辑轮次或结果只更新 lastModifiedAt，不自动改状态；某轮 failed 不自动 rejected。申请详情的下一节点卡片与申请列表排序同时考虑 Deadline 和 pending 轮次。

**Blocked by:** 14（申请详情与状态流转）

**Status:** ready-for-agent

- [ ] 轮次 CRUD 与表单字段、默认 pending 结果；任何编辑更新 lastModifiedAt。
- [ ] 轮次按 scheduledAt 升序、同时间 id 兜底；过去轮次弱化。
- [ ] 「标记为面试中」提示条件严格：applied / oa + 未来轮次；确认走 changeStatus；取消或其他状态不弹。
- [ ] 轮次结果与失败均不自动改 Application 状态。
- [ ] 下一节点卡片取更早的 Deadline 或 pending 轮次；申请列表排序使用最近 upcoming 节点。
- [ ] 单测覆盖提示条件、下一节点合并与排序。
