# Discover 样本模式 UI 与空状态原型

Type: prototype
Mode: HITL
Status: resolved
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

## Comments

### 2026-11-08 原型（选定 C）

原型文件：[`11-discover-sample-ui.html`](../prototypes/11-discover-sample-ui.html)（单文件，双击打开；或在本仓库根目录执行 `open .scratch/nextstep/prototypes/11-discover-sample-ui.html`）。

- **三个结构变体**：A 样本卡 + 分组列表 / B 样本条 + 分页签 / C 每日样本 digest。`?variant=A|B|C`；底栏 `←`/`→` 或键盘方向键切换。
- **页面**：列表 / 详情 / 不符合详情（`?screen=list|detail|blocked`）。
- **数据状态**：默认样本（2 条手动导入 eligible + 12 条 Remotive ineligible）/ 只看实习（空，首次打开无手动导入）/ 刷新失败（有缓存 + 非阻塞 banner）/ 无缓存（全屏错误）。`?state=default|internships|failure|nocache`。
- **覆盖**：顶部样本模式说明（来源、每日条数、0 实习）、eligible / ineligible 分组与徽标（ineligible 不显示 0 分）、纯 UI「只看实习」开关与空状态、粘贴 JD 在顶部 / 空状态 / ineligible 分组旁、缓存优先与刷新失败 / 配额用完、08 与 02 的视觉语言。
- 详情沿用 02 变体 A，只补充来源 / 样本说明；不改 02 算法、04 协议。

反馈：**C 可以**。以此为准，A / B 留在原型里仅作探索；具体 UI 决策见下方 Answer。

## Answer

日期：2026-11-08。采用原型变体 **C「每日样本 digest」**。原型：[`11-discover-sample-ui.html`](../prototypes/11-discover-sample-ui.html)（C 默认；A/B 仅作对比，不进入实现）。

### 结论

Discover 以「每日样本」组织：顶部深色样本头图常驻说明 Remotive 公共 API 的限制与来源；「只看实习」是纯 UI 开关；eligible 岗位在前，ineligible 仍展示但不显示 0 分；手动粘贴 JD 是主 CTA，出现在顶部、空状态和 ineligible 分组旁；缓存优先，刷新失败/配额用完只做非阻塞提示。

### IA 与首屏

- **顶部**：日期 overline + `Discover` 大标题 + 一句 deck（今天的 Remotive 样本与 iOS 实习画像）。
- **样本头图（常驻）**：显示实际返回的样本条数、其中 internship 条数、手动导入条数；正文说明「公共 API 每天只放出一小份样本，不是全部岗位；今天没有实习。条数少不是加载失败」；底部署名 `数据来源 Remotive`、更新时间、回链原岗位。条数以 API 实际返回 / `total-job-count` 判断，不写死 12。
- **只看实习**：样本头图下方的纯 UI 开关，只过滤当前列表的 `jobType == internship`；不改 02 的匹配算法，不改变 eligibility，也不把筛选写进 `MatchResult`。
- **粘贴 JD**：样本头图下方第一块是虚线「粘贴一份 JD」卡片（说明不消耗 Remotive 配额）；空状态主按钮、ineligible 分组头/尾部再出现同一入口。覆盖列表顶部、空状态、ineligible 分组旁三个位置。

### 列表与分组

- **eligible**：所有符合 02 规则的岗位（原型 demo 中为 2 条手动导入）按 02 变体 A 展示——分数 pill、匹配/缺失技能标签、一句话原因；按匹配分降序，放在「适合你」段。
- **ineligible**：所有不符合 02 规则的岗位（原型 demo 中为 Remotive 样本）放在分隔线后的「不符合 · N 条」段；分组按 eligibility，不按来源，手动导入若不符合也进入此段并标来源。默认显示前 4 条，其余折叠，展开可看全部。仍展示、不参与排序、不显示 0 分；每行给「不符合」徽标 + 原因（如「非实习」「仅限欧洲时区」）+ 技能命中数。
- **详情**：沿用 02 变体 A。eligible 详情有分数 hero、技能标签、分项条、JD 高亮；ineligible 详情没有分数 hero / 分项条，只保留不符合原因与技能匹配解释。
- **来源**：列表与详情区分「Remotive」与「手动导入」；Remotive 详情注明「今天 N 条样本之一」、样本不代表全量，并回链原岗位。

### 空 / 错状态

- **只看实习且无 eligible**：空状态标题「今天的样本里没有实习」；正文说明样本条数与 0 实习，不是加载失败；主按钮「粘贴 JD」，次按钮「查看全部样本」（关闭筛选）；备注手动导入的岗位会出现在这里、明天有新样本。
- **刷新失败 / 配额用完（有缓存）**：样本头图下加琥珀色非阻塞提示「今天没能刷新 · 显示 11-07 的缓存」+「重试」；列表、详情、粘贴入口保持可用，不弹窗、不挡路。
- **无缓存**：全屏错误「暂时拿不到岗位」，说明可能是配额或网络；主按钮「重试」，次按钮「粘贴 JD」；提示手动粘贴不依赖 Remotive、配额明天恢复。
- **缓存优先**：先展示缓存再刷新；`RefreshOutcome` 的 `.skipped` / `.failed` 只映射到上述非阻塞提示或全屏错误，不改 04 的协议。

### 范围

- **P0**：样本头图与来源署名、只看实习开关 + 空状态、eligible / ineligible 分组与「不显示 0 分」、ineligible 默认折叠 + 展开、粘贴 JD 三处入口、缓存优先 + 刷新失败/无缓存状态、详情来源与样本说明。
- **P1（不在本轮）**：来源筛选（Remotive / 手动）、样本头图日期切换动效、粘贴 JD 的完整表单细节、ineligible 折叠动画。
- **不做**：改 02 匹配算法或 `MatchResult`；改 04 `JobSource` / `JobRepository` / `RefreshOutcome`；服务端过滤（Remotive 参数当前 no-op）；隐藏 ineligible；把「只看实习」做成匹配规则或硬过滤；伪造 Remotive 数据 / 把虚构 JD 标为 Remotive；后台自动刷新。

### 交接

- `DiscoverViewModel` 继续从 `JobRepository` 读缓存并触发 `refreshIfNeeded`；样本模式元数据由实际返回条数 / `total-job-count`（可选）判断，不新增协议。
- 手动粘贴继续走 `ManualJobSource` + `JobRepository.importManual`；UI 只负责入口。
- 视觉沿用 08 的卡片 / 导航 / 底栏与 02 的分数 pill / 技能标签 / 详情信息层级；术语用「样本模式」「适合你」「不符合条件」「只看实习」「粘贴 JD」。
- 原型：`.scratch/nextstep/prototypes/11-discover-sample-ui.html`（C 默认；A/B 仅作对比）。
- 原始提交：throwaway branch `worktree-discover-sample-ui-11`（commit `a83c4f1`，不合并）；主工作区保留可打开副本。
