# 功能边界与 MVP 验收线

Type: grilling
Mode: HITL
Status: resolved
Blocked by: 08

## Question

NextStep v1 到底交付哪些功能，按什么顺序？需要确定：

- 追踪器核心：岗位/申请 CRUD、投递状态流转、提醒、仪表盘/漏斗统计，哪些进 v1，哪些放拓展？
- 发现/匹配：Remotive Discover、手动粘贴 JD、匹配列表与“匹配/缺失”解释，各自进 v1 吗？
- Share Extension / Widget：在免费账号 spike 结果出来前，是否只作为可选加分项？
- MVP 验收线：能演示哪一条端到端路径？真实数据流、分层架构、错误处理、测试分别到什么程度？
- 每日可投入时间与总小时数（尚未确认）：用来校准范围。

输出：一份带优先级和明确“不做”清单的 v1 功能边界。

## Comments

### 2026-11-06 第一轮（已确认）

- 时间预算：30 天 / 约 100 小时有效工时 / 预留 20% 缓冲。
- 发现与匹配 P0 全进 v1：Remotive Discover（缓存、节流、署名回链）、手动粘贴 JD、用户画像编辑、匹配列表 + 匹配/缺失解释、从发现结果一键导入 Application。URL 导入等 P1 之后再评估。
- 云模型：v1 不基于云模型做匹配；之后再评估是否添加。
- Share Extension / Widget：v1 不考虑。
- 仪表盘：形态太模糊，拆出 prototype ticket 08；本 ticket 的仪表盘子问题被 08 阻塞。

### 2026-11-06 第二轮（已确认）

- 主叙事：B 为主（产品与 UX 完整度），C 为支撑（工程架构）。
- v1 匹配：本地规则 + 技能词典 + 可解释输出；匹配是 P0 功能但非主叙事；云模型只作为未来拓展。
- 追踪器核心：用户认为「Application CRUD」等表述仍模糊，待澄清后再定。

### 2026-11-06 第三轮（已确认）

- 追踪器核心 P0：Application 完整 CRUD（列表 + 详情 + 新建/编辑/删除），可选关联 JobPosting，允许纯手动记录；JobPosting 只读/导入；状态流转含合法转换与回退；截止日期 + 本地通知提醒；轻量 InterviewRound（日期/形式/备注/结果）。
- 数据归属：Application 只存投递过程 + 公司/职位/链接快照；JD 全文在 JobPosting；InterviewRound 独立子实体；StatusChange 记录状态历史（v1 就记）；匹配分/提醒/统计均为派生；v1 不建独立 Company / Skill 实体。
- tracker 原型：不做。
- 命名：保留 JobPosting；JD 作为其 `descriptionPlainText` 字段；已写入 GLOSSARY.md。

### 2026-11-06 第四轮（已确认）

- v1 验收路径：空状态 → Discover（Remotive 真实数据，缓存兜底）→ 岗位详情（匹配分 + 匹配/缺失解释）→ 导入 Application → 追踪器改状态/设截止/加面试轮次 → 本地提醒 → 仪表盘 → 杀进程重启后数据仍在。
- 工程深度：View / ViewModel / Domain / Data 分层；`JobSource` 协议；`MatchingEngine` 纯模块；真实 Remotive 数据流 + 缓存/节流 + 用户可见错误处理；核心逻辑单测（匹配、状态机、Repository、解码 fixture），UI 手动验收，不做完整 UI 测试。

### 2026-11-06 第五轮（已确认）

- P0 顺序：领域核心 → 追踪器闭环 → 匹配闭环（手动）→ 发现闭环（Remotive）→ 收尾（仪表盘/空错状态/README/演示）。
- P1：URL 导入、漏斗转化率、状态分布图/独立概览 tab（待 08 确认）。
- v1 不做：账号/登录/云同步/多设备/iCloud/CloudKit/Sign in with Apple/Associated Domains；Push/TestFlight/上架；国内平台抓取/实时聚合/转投 Remotive 数据；真实 JD 入库；云 LLM/向量检索/简历生成/自动投递；Share Extension/Widget；独立 Company/Skill/公司主页/联系人/日历/邮件/简历版本/团队协作；CSV/社交 Feed/薪资分析/公司点评；自建后端/代理/生产级监控/完整 UI 测试/多语言；其他项目方向。
- 术语职责边界：`JobSource` 只负责取数 + 归一化为 `JobPosting`；缓存/节流/持久化归 `JobRepository`；匹配分归 `MatchingEngine`；申请状态归 tracker。

## Answer

### 范围校准

- 时间：30 天，约 100 小时有效工时，预留 20% 缓冲。
- 作品集主叙事：产品与 UX 完整度为主，工程架构为支撑；匹配是 P0 功能，但不是唯一核心。
- 匹配方案：v1 本地、可解释、可测试（NaturalLanguage 分词 + 技能词典 + 规则/加权评分）；不依赖云模型或 Foundation Models。

### P0（必须进 v1 验收线）

1. **领域核心**：`UserProfile`、`JobPosting`、`Application`、`InterviewRound`、`StatusChange`；状态机（wishlist → applied → OA → interview → offer / rejected / withdrawn，含合法转换与回退）+ 单测。
2. **追踪器闭环**：`Application` 完整 CRUD（列表、详情、新建/编辑/删除；可选关联 `JobPosting`，允许纯手动记录）；`JobPosting` 只读/导入；截止日期 + 本地通知提醒；轻量 `InterviewRound`（日期/形式/备注/结果）；每次状态转换写入 `StatusChange`。
3. **匹配闭环（手动）**：`UserProfile` 编辑（技能、目标方向、地点/时区、可实习时间、毕业年份）；手动粘贴 JD → `JobPosting`；`MatchingEngine` + 技能词典 + 匹配/缺失解释 + 单测；导入为 `Application`。
4. **发现闭环（Remotive）**：`JobSource` 协议 + `RemotiveJobSource`；缓存/节流（≤4 次/天）；署名回链；Discover 列表/详情；导入 `Application`；断网/超时/限流/解码失败的可见错误 + 缓存兜底 + 重试。
5. **仪表盘（变体 A，见 [仪表盘原型](08-dashboard-prototype.md)）**：独立「概览」tab +「申请」tab；「今天」+「接下来 7 天」事件列表（截止与面试合并，按最近节点排序）；三个进展计数（进行中 / 7 天内截止 / Offer）；最近更新清单；空状态（添加第一份申请 / 去 Discover）。
6. **工程底线**：View / ViewModel / Domain / Data 分层；`JobSource` 协议；`MatchingEngine` 纯模块；SwiftData repository；真实 Remotive 数据流 + 缓存 + 节流；核心逻辑单测（匹配引擎、状态机、Repository 节流/缓存、Remotive 解码 fixture）；UI 手动验收，不做完整 UI 测试。
7. **数据归属**：`Application` 只存投递过程 + 公司/职位/链接快照；JD 全文在 `JobPosting`；`InterviewRound` 独立子实体；`StatusChange` 记录状态历史；匹配分/提醒/统计派生；v1 不建独立 Company / Skill 实体。

### P1（v1 后、时间允许，不进 v1 验收线）

- URL 导入（公开页面解析）。
- 漏斗转化率（依赖 `StatusChange` 历史）。
- 状态分布图。
- 独立概览 tab 已由 08 变体 A 进 v1，不再放 P1。

### 明确不做（v1）

- 账号/登录、云同步、多设备、iCloud/CloudKit、Sign in with Apple、Associated Domains。
- Push、TestFlight、App Store 上架。
- 抓取国内招聘平台、实时全网聚合、把 Remotive 数据转投第三方聚合站。
- 把真实 JD 全文复制进仓库或演示数据集（演示用虚构数据）。
- 云 LLM / Foundation Models 匹配、向量检索、简历生成/自动投递/自动填表。
- Share Extension / Widget（v1 不排期，未来作为独立 effort 评估）。
- 独立 Company / Skill 实体、公司主页、联系人管理、日历/邮件集成、简历版本管理、团队协作。
- CSV 导入导出、社交/推荐 Feed、薪资分析、公司点评。
- 自建后端/代理、生产级监控、完整 UI 测试、多语言。
- 环形图/多图分析页；无阶段历史的回复率/Offer 率；横向看板作为主追踪界面（来自 08）。
- 其他项目方向（本地音乐/播客播放器等）。

### 端到端验收路径（黄金路径）

1. 首次打开 → 空状态 → 去 Discover。
2. Discover 拉取 Remotive（真实 API；断网/超时用缓存兜底 + 可重试），看到岗位列表。
3. 打开岗位详情 → 看到匹配分 + 匹配/缺失技能 + 解释。
4. 一键导入为 Application；或手动粘贴 JD 创建 Application。
5. 追踪器列表看到它 → 详情改状态（applied → OA → interview）、设截止日期、加面试轮次、写备注。
6. 截止前收到本地通知。
7. 仪表盘显示计数/最近截止/最近更新（变体 A）。
8. 杀进程重启，数据仍在（SwiftData）。

演示数据用虚构公司/虚构 JD；真实 Remotive 数据必须署名并回链。

### P0 实现顺序

1. 领域核心：SwiftData 模型 + 状态机 + 单测。
2. 追踪器闭环：Application CRUD + 列表/详情 + 状态流转 + 截止提醒。
3. 匹配闭环（手动）：UserProfile + 手动粘贴 JD + MatchingEngine + 解释 + 单测 + 导入。
4. 发现闭环（Remotive）：JobSource + Remotive client + 缓存/节流 + 署名 + Discover UI。
5. 收尾：仪表盘 + 空状态/错误状态 + README + 演示。

### 交给后续 ticket 的开放项

- 领域模型细节、状态机转换表、SwiftData 迁移 → [领域模型与投递状态机](03-domain-model.md)。
- 匹配算法、技能词典、解释格式、测试用例 → [匹配算法与技能词典](02-matching-engine.md)。
- 分层、`JobSource` 协议签名、依赖注入、ADR → [混合架构与 JobSource 抽象](04-architecture.md)。
- 四周排期、测试策略、演示脚本、README → [30 天排期、测试与演示方案](06-schedule-demo.md)。

## Comments

### 2026-11-08 范围变更（通知延后）

本地通知移出 v1（见 [截止与面试提醒策略](10-reminder-policy.md)，已关闭）。据此：

- P0 追踪器闭环中的「截止日期 + 本地通知提醒」改为「截止日期 + 仪表盘『今天 / 接下来 7 天』展示」。
- 黄金路径第 6 步「截止前收到本地通知」改为「在概览的『今天 / 接下来 7 天』看到截止/面试」。
- 其余 P0/P1/不做清单不变；`Application.deadline`、`InterviewRound.scheduledAt` 继续保留。
