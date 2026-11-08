# Discover 样本模式 UI 与空状态原型

Type: prototype
Mode: HITL
Status: open
Blocked by:

## Question

Remotive 公共 API 现在每日只返回约 10–12 条样本、0 个 internship（见 [Remotive API 现状复核](09-remotive-api-recheck.md)）。在这个前提下，Discover 的列表、详情与空/错状态应该长什么样？

需要覆盖：

- 列表顶部常驻的“样本模式”说明：来源、每日条数、实习稀缺。
- eligible / ineligible 的分组与徽标：沿用 02 的“展示并标 ineligible”，ineligible 不显示 0 分。
- 纯 UI 的“只看实习”开关；开启且无 eligible 时的空状态。
- 手动粘贴 JD 作为主 CTA 的位置：列表顶部、空状态、ineligible 分组旁。
- 缓存优先，以及刷新失败/配额用完时的非阻塞说明。
- 与 08 仪表盘、02 匹配解释的视觉语言一致。

产出：可点的 HTML 原型（链接到本 ticket），选定一个变体后把 UI 决策写回本 ticket 的 Answer；不改 02 的匹配算法，不改 04 的 `JobSource` / `JobRepository` 协议。
