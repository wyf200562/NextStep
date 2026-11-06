# 领域模型与投递状态机

Type: grilling
Mode: HITL
Status: open
Blocked by: 01

## Question

NextStep 的核心领域对象和状态流转是什么？

- Application / JobPosting / Company / InterviewRound / UserProfile / Skill 之间的关系。
- 投递状态：wishlist → applied → OA/笔试 → interview → offer / rejected / withdrawn；允许的转换与回退。
- 面试轮次如何记录（时间、形式、联系人、备注、结果）。
- 哪些字段必填/可选，哪些是派生（匹配分、截止提醒、漏斗统计）。
- SwiftData 模型与迁移策略的初步边界。
