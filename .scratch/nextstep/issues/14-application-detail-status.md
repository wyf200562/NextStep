# 14: 申请详情与状态流转

**What to build:** 申请详情展示头部（公司 / 职位 / 状态 / 最近更新）、下一节点卡片（Deadline，pending 轮次在 16 合并）、备注与编辑 / 删除工具栏。编辑复用申请表单修改公司、职位、链接、地点、备注、Deadline / 时刻，保存更新 lastModifiedAt，状态不能在编辑器中修改。删除二次确认后级联删除面试轮次与状态历史，JobPosting 保留。状态变更 sheet 只列 ApplicationStateMachine 允许的目标状态，可填备注；活动态回退与 rejected / withdrawn 重新打开需二次确认；offer 为成功终态不可离开；每次变更写 StatusChange、更新 Application.status 与 lastModifiedAt；非法转换抛 typed error，UI 显示「当前状态不能这样变更」。ApplicationStateMachine 为纯结构，无 I/O。

**Blocked by:** 13（申请创建与列表）

**Status:** ready-for-agent

- [ ] 状态机规则与 spec 转换表完全一致（含跳级、活动态回退、终态、reopenTargets、requiresConfirmation）；offer 无出口；表驱动测试覆盖全部转换。
- [ ] 状态变更 sheet 只列合法目标；回退 / 重开二次确认；备注写入 StatusChange。
- [ ] 编辑不改变状态，保存更新 lastModifiedAt；删除 cascade 且 JobPosting 保留。
- [ ] 详情头部与下一节点卡片（Deadline）正确；关联 JobPosting 不存在时快照仍正常显示。
- [ ] 非法转换显示中文错误文案，不展示原始 error。
- [ ] Repository 单测：每次转换写记录、lastModifiedAt、cascade、非法转换抛错。
