# 截止与面试提醒策略

Type: grilling
Mode: HITL
Status: resolved
Blocked by: 03

## Question

本地通知在什么时候触发、提前多久、对哪些节点提醒？需要确定：

- 截止（`Application.deadline`）提前多久提醒：当天 09:00、提前 1 天 / 3 天，还是用户可选？
- 面试（`InterviewRound.scheduledAt`）是否提醒、提前多久？
- 同一申请有多个节点（deadline + 多个面试）时如何合并/去重？
- 已过期/已完成的节点是否还提醒？改期或删除后如何取消旧通知？
- 提醒文案与权限引导：首次何时请求通知权限、被拒后的降级提示。
- 通知调度是否需要持久化（杀进程重开后排）还是每次启动重算。

输出：一套 v1 的提醒规则 + 文案要点，能直接实现本地通知调度。

## Answer

日期：2026-11-08。决定：**本地通知/提醒移出 30 天 v1 范围**，v1 不实现；之后作为独立 effort 重新评估。

- **不做**：不实现 `UNUserNotificationCenter` 调度、不请求通知权限、不定义提醒档位/合并/取消规则、不写通知文案、不建 `NotificationScheduling` 协议缝或 `Data/Notifications` 实现。
- **保留**：`Application.deadline`、`InterviewRound.scheduledAt` 等字段（[领域模型与投递状态机](03-domain-model.md) 已定）；仪表盘「今天 / 接下来 7 天」（[仪表盘原型](08-dashboard-prototype.md) 已定）继续作为 v1 的 P0 展示，不依赖通知。
- **未来实现方式**：需要通知时直接从 `Application`（含 `deadline`、`interviewRounds`）读取数据，再引入调度协议/实现；本 ticket 原列的提醒档位、合并去重、过期/终态取消、权限引导、调度持久化等问题届时重新决策。
- **原因**：通知包含权限、调度、取消、文案与测试的完整闭环；用户决定把 30 天优先投入追踪器/匹配/发现闭环，通知留到 v1 之后。
