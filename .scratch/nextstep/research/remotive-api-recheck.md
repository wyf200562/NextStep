# Remotive 公共 API 现状复核

> 范围：NextStep v1 的 Discover 数据源、默认 `JobQuery` 与空状态策略；不改 02 的匹配算法，不改 04 的 `JobSource` / `JobRepository` 协议。
> 核验日期：2026-11-08（API 请求 10:13–10:22 UTC）。
> 方法：只采用 Remotive 官方 API 文档/README 与当天的 8 次真实 API 响应；请求间隔 ≥65 秒，均返回 200，未触发 429/403。原始响应含 JD，仅存放在仓库外（`$CLAUDE_JOB_DIR/tmp/remotive-research/`），本文只保留聚合计数与元数据，不复制 JD 正文。

## 结论

**Remotive 公共 API 当前对所有查询参数实际返回同一份每日缓存样本（本次 12 条，0 个 internship）。** 10 条不是“默认上限”或分页，而是公开 API 只暴露约 10–12 条/日的免费样本；官方文档仍写着“默认返回全部、参数可过滤”，两者已不一致。

- `limit=5`、`limit=1500`、`search=internship`、`category=software-dev`、`search=ios`、`search=swift`、`category=software-dev&search=internship` 与无参数请求的响应**字节级完全相同**（同一 SHA-256，216,489 bytes）。参数在当前边缘缓存下没有生效。
- 响应自报 `job-count=12`、`total-job-count=12`、`jobs.length=12`；`last-modified` 为 2026-11-07 11:11:49 GMT，响应 `age` 约 23 小时，`cf-cache-status: HIT`。这是一份每天生成一次的静态快照。
- 12 条样本中 `job_type`：full_time 6、freelance 3、contract 2、part_time 1、**internship 0**；`Software Development` 5 条，其余为 Writing/All others/AI/Customer Service/Marketing/Sales。`internship` 在 title/tags/description 中均为 0 次命中。
- 同一天 Remotive 首页匿名可见 13 条岗位，12 个 API id 全部在其中（首页另有 1 条更新的 2091045）；首页写着“You're seeing 0.4% of available roles / Unlock 130,000+ jobs”，legal notice 也提供“starting budget is $5k/mo”的私有 API。公开 API 是样本层，不是完整岗位库。
- 因此：**保留 Remotive 作为真实数据/集成演示源，但把手动粘贴 JD 提升为 Discover 的主要兜底。** 默认 `JobQuery` 建议 `keyword: nil, category: "software-dev", limit: 50`，UI 明示“样本模式”，并把 02 的 ineligible 展示策略用于这批非实习岗位。

## 1. 官方文档现状（2026-11-08）

### 1.1 文档入口与更新时间

- 官方 API 页面：<https://remotive.com/remote-jobs/api>，页面 `last-modified: 2026-11-04 00:06:28 GMT`；正文重复署名/回链/24h 延迟/禁止转投第三方等条款，并链接到官方 README。
- 官方 README：<https://github.com/remotive-com/remote-jobs-api>（2026-11-08 读取 raw README）。README 顶部仍提示主域名已从 remotive.io 迁到 remotive.com。
- GitHub API 当天返回 403 rate limit、仓库 HTML 返回 504，**未能取得 README 的提交历史**；只能确认“当前文本”而非“何时改成这样”。

### 1.2 文档声明 vs 实测

| 文档声明 | 官方来源 | 2026-11-08 实测 |
|---|---|---|
| `GET https://remotive.com/api/remote-jobs` | README | 200，无需鉴权 |
| 可选参数 `category`、`company_name`、`search`、`limit` | README | 文档仍列出；实际 8 种查询返回同一响应，参数未生效 |
| `limit` 默认返回全部，传整数限制条数 | README | `limit=5` 仍返回 12 条；`limit=1500` 仍返回 12 条 |
| `search` 大小写不敏感、部分匹配 title 和 description | README | `search=internship/ios/swift` 均返回同样的 12 条；无法验证搜索层级 |
| `category` 接受分类名或 slug | README | `category=software-dev` 返回 12 条，其中 7 条不是 Software Development |
| 无鉴权 | README | 未带任何 key，200 |
| 建议每天最多 4 次；超过 2 次/分钟会被封 | README | 8 次请求、间隔 ≥65 秒，无 429/403 |
| 数据延迟 24 小时 | README / legal notice | `last-modified` 比请求时间早约 23 小时，符合每日快照 |
| 必须标注 Remotive 并回链原岗位；不得转投第三方聚合站；不得用于收集注册/邮箱 | 官方 API 页 + README + `0-legal-notice` | 条款未变，仍适用 |
| `job_type` 可为 `full_time/contract/part_time/freelance/internship`，可选且经常不填 | README | 12 条都有 `job_type`；值只有前四类，**0 个 internship** |
| 未提及分页 | README | 响应无 `next`/`page`/`cursor` 字段；`total-job-count=12` |

补充：官方状态页 <https://status.remotive.com/en/> 在 2026-11-08 10:13 UTC 显示 “Looks like everything is operating normally”，但监控组件只有 Website、Blog、Meilisearch、Helpdesk、Doge，**没有 API 组件**；因此“状态正常”不能证明 API 行为符合文档。

### 1.3 响应结构的新变化

当前响应顶层字段：`0-legal-notice`、`00-warning`、`job-count`、`jobs`、`total-job-count`。单条岗位字段：`id`、`url`、`title`、`company_name`、`company_logo`、`company_logo_url`、`category`、`job_type`、`publication_date`、`candidate_required_location`、`salary`、`tags`、`description`。

- `total-job-count` 是 README 未记录的新字段，本次值为 12，与 `job-count`、`jobs.length` 一致。
- `company_logo_url` 是新增字段；12 条中 10 条有值。
- `00-warning` 仍是 2022 年“remotive.io 将于 2022 年 6 月停止”的旧提示，说明响应模板多年未清理。
- `0-legal-notice` 提到私有付费 API “starting budget is $5k/mo”，与公开 API 的样本化行为互相印证。
- 12 条均有 `tags`；10 条有非空 `salary`；12 条均有 `candidate_required_location`。

## 2. 实测结果

### 2.1 请求矩阵

8 次请求全部 HTTP 200；响应体 SHA-256 均为 `ee4c4e4b1730b83c79d2312f1b9d5967e3120cae2fbd8dce70f48ddd5dae9191`，`content-length` 均为 216,489。

| # | 查询 | HTTP | `job-count` | 返回条数 | 与基线是否同一响应 | `job_type` 分布 | 关键观察 |
|---|---|---:|---:|---:|---|---|---|
| 1 | 无参数（基线） | 200 | 12 | 12 | — | full_time 6 / contract 2 / freelance 3 / part_time 1 / internship 0 | 基线快照 |
| 2 | `limit=5` | 200 | 12 | 12 | 是（字节相同） | 同基线 | `limit` 未生效 |
| 3 | `limit=1500` | 200 | 12 | 12 | 是（字节相同） | 同基线 | 复现“不是 1500 条”，但也不是 10 条上限 |
| 4 | `search=internship` | 200 | 12 | 12 | 是（字节相同） | 同基线，0 internship | 搜索未过滤 |
| 5 | `category=software-dev` | 200 | 12 | 12 | 是（字节相同） | 同基线 | 7 条非 Software Development，分类未过滤 |
| 6 | `search=ios` | 200 | 12 | 12 | 是（字节相同） | 同基线 | 搜索未过滤 |
| 7 | `search=swift` | 200 | 12 | 12 | 是（字节相同） | 同基线 | 搜索未过滤 |
| 8 | `category=software-dev&search=internship` | 200 | 12 | 12 | 是（字节相同） | 同基线 | 组合参数同样无效 |

响应头（8 次一致）：`server: cloudflare`、`cf-cache-status: HIT`、`cache-control: no-store`、`access-control-allow-origin: *`、`last-modified: Sat, 07 Nov 2026 11:11:49 GMT`、`age: 82914–83420`（约 23 小时）、`cf-ray: ...-SIN`（新加坡边缘）。

### 2.2 样本构成（基线 12 条）

| 维度 | 分布 |
|---|---|
| `job_type` | full_time 6、freelance 3、contract 2、part_time 1、internship 0 |
| `category` | Software Development 5、Writing 2、All others 1、Artificial Intelligence 1、Customer Service 1、Marketing 1、Sales 1 |
| `publication_date` | 2026-10-08T21:47:32 ～ 2026-11-06T08:51:01（约 29 天） |
| id 集合 | `1185979, 1680495, 1749306, 2069746, 2086540, 2091134, 2091135, 2091158, 2091161, 2091165, 2091166, 2091168` |
| 字段完整性 | `job_type` 12/12、`tags` 12/12、`candidate_required_location` 12/12、`salary` 10/12 |

关键词命中（按“包含该关键词的岗位数”计，不复制描述）：

| 关键词 | title | tags | description | 任一字段 | 说明 |
|---|---:|---:|---:|---:|---|
| internship | 0 | 0 | 0 | 0 | 样本中没有实习岗位 |
| `\bios\b` | 0 | 2 | 2 | 2 | 命中的是 Content Reviewer 与 Senior Back-end Developer，均为标签堆砌，不是 iOS 岗位 |
| swift | 0 | 1 | 1 | 1 | 仅 Senior Back-end Developer 的标签/描述出现 |
| swiftui | 0 | 0 | 0 | 0 | 无 |
| software | 1 | 0 | 5 | 5 | 标题仅 1 条，描述 5 条 |

这说明：即使客户端做关键词筛选，当前样本也只能得到 1–2 条“提到 iOS/Swift”的岗位，且都不是 iOS 实习；Remotive 的 `tags` 存在明显的堆砌噪声，不能直接当作岗位方向。

### 2.3 证据判定：参数被忽略，不是默认上限/分页/数据集变小

| 假设 | 证据 | 判定 |
|---|---|---|
| 参数被忽略 | `limit=5` 返回 12 条；`search=internship` 返回 12 条且 0 条含 internship；`category=software-dev` 返回 7 条非软件岗位；8 个响应字节级相同 | **成立（强）** |
| 默认上限 10 | 文档写 `limit` 默认 all；`limit=5` 未被遵守；`total-job-count=12`；11-06 是 10 条、11-08 是 12 条，更像每日快照大小变化 | **不成立** |
| 分页行为 | 文档无分页参数；响应无 `next/page/cursor`；`job-count=total-job-count=jobs.length=12` | **不成立** |
| 数据集临时变小 | 首页仍宣传 130,570 条、22,532 条/周新增；同一天首页匿名可见 13 条，API 12 条全在其中；API 自报 total 12 | **不是“全站数据集变小”，而是公开 API 只暴露小样本** |
| 鉴权/API 变更 | 无鉴权也能 200；文档未改；legal notice 明示付费私有 API；响应模板仍含 2022 年旧提示 | **是公开 API 的样本化/降级，不是鉴权失败** |
| 临时故障 | 状态页“正常”但不监控 API；无官方公告；连续 8 次稳定返回同一快照 | **无法证明是临时故障；更像有意限制的样本层（中等置信）** |

机制上，`cf-cache-status: HIT` + `age≈23h` + `last-modified` 说明客户端拿到的是 Cloudflare 边缘的每日缓存对象；`cache-control: no-store` 与 HIT 并存，可能是缓存规则覆盖了源站头，也可能是源站直接返回静态快照。受请求预算限制，**没有做 cache-busting 验证**，因此无法区分“CDN 缓存键忽略 query string”与“源站本身忽略参数”；但对 App 而言，二者的可观察行为相同：**同一天内，任何参数都拿同一份样本**。

## 3. 对 Discover 的查询与空状态建议

### 3.1 默认 `JobQuery`

按 `GLOSSARY.md` 的 `JobQuery` 语义（关键字、分类、数量），建议默认值：

```swift
JobQuery(keyword: nil, category: "software-dev", limit: 50)
```

理由：

- `keyword: nil`：服务端 `search` 当前是 no-op，且 07 已记录它“搜描述、结果松”；方向匹配交给本地 `MatchingEngine`，避免服务端搜索恢复后反而过度收窄。
- `category: "software-dev"`：官方 README 示例使用的 slug，语义上就是目标方向；当前被忽略也无害。
- `limit: 50`：防御性上限。当前 API 忽略它并返回 12 条；若将来恢复，50 条约 0.9 MB（按本次 12 条 216 KB 估算），符合 04 的 4 次/日节流与主线程匹配预算，也不会因 1500 这种值造成无谓负载。
- 每次刷新只发**一个**查询，不要为了“多试几个参数”消耗 4 次/日配额；当前一次请求就能拿到整份样本。
- 把 `job-count` / `total-job-count` 用于日志或“样本模式”判断，不要当作“全量数据”的保证。

客户端保护：当 `total-job-count` 存在且 ≤ 50（或返回条数明显小于常规岗位库）时，把本次结果标记为“样本模式”，在 UI 显示来源说明；不要因为条数少就判定为解码失败或空数据。

### 3.2 internship 稀缺的呈现（不改 MatchingEngine）

02 已定“不符合也展示并标 ineligible”，本 ticket 不改变该策略，只调整数据源说明与 UI 呈现：

- **不硬过滤**：12 条样本中 0 条 internship，若按 `job_type` 硬过滤会直接得到空列表；应继续把岗位交给 `MatchingEngine`，由 `MatchResult.eligibility` 标记 ineligible。
- **排序与分组**：eligible 岗位在前；ineligible 岗位放在“其他岗位（不符合实习/地点）”分组或折叠区，仍可点进详情看匹配解释。
- **徽标**：ineligible 卡片显示原因（如“非实习”“地点不符”），不显示 0 分；这与 02 的“ineligible 不给总分”一致。
- **样本横幅**：列表顶部常驻一条轻量说明：“Remotive 公共 API 目前每日仅返回约 10–12 条样本，实习岗位很少。”当天 0 条 internship 时可补充：“今天样本中没有实习岗位。”
- **筛选开关**：可提供客户端“只看实习”开关（纯 UI 过滤，不进入 `MatchingEngine`）。开启后若无 eligible 岗位，走 3.3 的空状态，而不是显示“暂无岗位”。
- **文案方向**：诚实说明数据源限制 + 立即给出替代动作；不要用“暂无数据”“加载失败”掩盖样本问题，也不要把 ineligible 说成“匹配失败”。示例：
  - 横幅：“Remotive 公共 API 每日只提供约 10–12 条样本，实习岗位很少。”
  - 空状态：“今天的 Remotive 样本里没有实习岗位。粘贴你找到的 JD，NextStep 会用同一套匹配解释帮你判断。”
  - CTA 主按钮：“粘贴 JD”；次按钮：“查看样本岗位”；第三：“稍后重试”（受配额限制）。

### 3.3 空状态与缓存优先

沿用 04 的“先读缓存再刷新、失败不阻塞浏览”，并针对“样本可能为 0”增加状态：

| 场景 | 首屏 | 刷新结果 | UI | CTA |
|---|---|---|---|---|
| 有缓存 | 立即显示缓存列表，按 `publication_date` 降序 | 后台刷新（4 次/24h、60s 间隔） | 顶部“更新于 X”+ Remotive 署名；刷新中不阻塞列表 | 下拉刷新；粘贴 JD |
| 无缓存，刷新成功且有岗位 | loading → 列表 | 本次 12 条样本 | 样本横幅；ineligible 分组 | 粘贴 JD（主）；查看岗位 |
| 无缓存，刷新成功但 0 条 | 空状态 | 0 条 | 说明“今天没有拉到岗位”+ 样本限制 | 粘贴 JD（主）；稍后重试（次） |
| 有缓存，刷新失败 | 列表 + 非阻塞 banner | offline / timeout / rateLimited / server | “显示的是上次缓存；更新失败：<原因>”+ 上次更新时间 | 重试；粘贴 JD |
| 无缓存，刷新失败 | 全屏错误 | 同上 | 错误原因 + 说明 | 重试；粘贴 JD |
| 配额用完/太频繁 | 缓存列表 | `.skipped(reason:)` | “今日刷新次数已用完/稍后再试”+ 上次更新时间 | 粘贴 JD；明天再试 |

补充：

- 当前 API 是每日快照，**每天 1 次成功刷新即可覆盖 24 小时内容**；4 次/日是上限，不是目标，不要为了“多拿几条”反复请求。
- 缓存按 `identityKey` upsert，不自动删除旧岗位（04 的既定决策）。样本每天约 12 条，30 天约 360 条，SwiftData 体量可接受；Discover 默认只展示最近 N 条（如 50）并按发布时间排序，更早的缓存可留在库中供已关联的 `Application` 使用。
- 断网/失败时缓存优先；手动粘贴不依赖网络，应始终可用。

### 3.4 手动粘贴 JD 的定位

**建议把手动粘贴提升为 Discover 的主要兜底，但不替换 Remotive。** 理由：

- Remotive 仍能提供真实岗位、真实外链和署名，是 `JobSource` / `JobRepository` 集成与“ineligible 展示”的最佳真实数据；完全移除会让 Discover 闭环失去数据源演示。
- 但公开 API 只有每日 10–12 条样本、0 个 internship，无法满足“找 iOS 实习”的真实发现需求；手动粘贴是当前唯一可靠的实习 JD 入口。
- 具体做法：Discover 顶部/空状态/ineligible 分组旁都放“粘贴 JD”主 CTA；Remotive 列表保留为“样本岗位”；`ManualJobSource` 与 `RemotiveJobSource` 继续统一走 `JobRepository.importManual` / `refreshDiscover`（04 已定，不改协议）。
- 如果产品必须做“真实实习岗位发现”，那已经是**换数据源/接付费 API**的决策，超出本 map 的 destination；本 ticket 只标记为待重新决策事项，不改地图、不擅自换源。

### 3.5 对 04（`JobSource` / `JobRepository`）的影响

- `JobQuery` 形状不变；只确定默认值：`keyword: nil`、`category: "software-dev"`、`limit: 50`。
- `JobRepository.refreshDiscover(query:)` 协议不变；一次刷新只发一个查询，不做多参数 fan-out。
- `RefreshOutcome` 不变：200 + 12 条样本是 `.refreshed`，不是 `.failed`；UI 不应把“条数少”当错误。
- DTO 解码需容忍/保留新字段：`total-job-count`（可选，用于样本模式）、`company_logo_url`（可选）、`00-warning`（忽略或仅日志）；`salary`、`job_type`、`company_logo_url` 按可选处理。
- 缓存、节流、错误映射、离线策略均不变；`429/403` 仍未观察到，但 `rateLimited` 映射保留。
- 不需要改 `JobSourceFactory`、`JobPostingDraft` 或 `identityKey`（仍为 `remotive:<id>`）。

### 3.6 对 06（演示脚本）的影响

06 §6 的预案是“若 internship 仍稀缺，按真实数据 + ineligible + 手动虚构实习 JD 演示，不伪造数据”。本次确认 **0/12 internship**，该预案应保留并去掉“若”：

- Discover 演示：加载真实 Remotive 样本（12 条，署名 + 回链），展示匹配解释与 ineligible 徽标；明确说明“这是公共 API 的每日样本，不是全量岗位库”。
- 实习匹配演示：手动粘贴一条**虚构**的 iOS 实习 JD（不复制真实 JD），展示 eligible、技能命中/缺失与分数解释；这同时演示 `ManualJobSource` 路径。
- 不得把 12 条真实岗位伪造成“实习岗位”，也不得把虚构 JD 标成 Remotive 来源。
- 演示前预热一次缓存；现场网络失败时用缓存样本 + 手动粘贴仍可走完流程。
- README 的“已知限制”增加一条：Remotive 公共 API 当前每日仅返回约 10–12 条样本，查询参数不生效，实习岗位可能为 0；手动粘贴 JD 是可靠兜底。
- 06 的“不做视频、现场演示、不伪造数据”不变。

## 4. 对 07 的逐条复核

| 07 的约束/结论 | 状态 | 证据与修订建议 |
|---|---|---|
| 端点 `GET https://remotive.com/api/remote-jobs` | **仍成立** | 2026-11-08 8 次请求均 200；域名已从 remotive.io 迁到 remotive.com（README 顶部警告） |
| 支持 `search`、`category`、`company_name`、`limit` | **需修订** | 文档仍列出，但实测 8 种查询返回同一响应；`limit=5` 不生效、`search/category` 不过滤。不要再依赖服务端参数，客户端自行过滤/匹配；`company_name` 未单独测试，但同一缓存机制下大概率同样无效 |
| 无需鉴权 | **仍成立** | 未带 key，200 |
| 每天最多 4 次；超过 2 次/分钟会被封 | **仍成立** | README 未变；本次 8 次、间隔 ≥65 秒，无 429/403 |
| 数据延迟 24 小时 | **仍成立（有新证据）** | `last-modified` 比请求早约 23 小时；响应是每日快照 |
| 必须标注 Remotive 并回链；不得转投第三方；不得收集注册/邮箱 | **仍成立** | 官方 API 页、README、`0-legal-notice` 均重复该条款 |
| 字段 `id/url/title/company_name/company_logo/category/tags/job_type/publication_date/candidate_required_location/salary/description` | **需修订（字段有增补）** | 字段都在；新增 `company_logo_url`、顶层 `00-warning`、`total-job-count`；`job_type` 12/12 有值（本次并非“经常不填”） |
| `job_type` 可为 `internship` | **已有新事实** | 文档仍写可为 internship，但 11-06（10 条）与 11-08（12 条）两次样本均为 0 个 internship；不能把演示/验收建立在“能拉到实习”上 |
| 局限：全球远程，不覆盖中国本地实习 | **仍成立** | 样本地点为 Worldwide/USA/Europe 等，无中国本地岗位 |
| `search` 会搜描述，结果较松，需要客户端过滤/匹配 | **需修订** | 文档说搜 title+description；实测搜索完全不过滤，连“搜索层级”都无法验证。客户端过滤从“建议”升级为“必须” |
| 映射：`JobPosting` 保留 `source=remotive`、`sourceURL`、`title`、`company`、`location`、`jobType`、`tags`、`descriptionPlainText`、`publishedAt` | **仍成立** | 字段可映射；`total-job-count` 不需要进入 `JobPosting`，可作为 DTO 元数据 |
| 缓存：SwiftData 本地缓存；4 次/天节流；离线可读 | **仍成立（更重要）** | 每日快照使缓存优先更关键；4 次/日是上限，1 次/日即可覆盖 |
| 07 的总体结论“可作为发现源” | **需修订** | 可作为**真实数据/集成演示源**；作为“实习岗位发现源”当前不成立（0 internship、样本 10–12 条），手动粘贴是主要兜底 |

## 5. 是否需要换端点/参数

- **不需要换端点**：`/api/remote-jobs` 仍可用、无需鉴权、返回真实岗位；问题不在端点，而在公开 API 的样本层与参数 no-op。
- **参数不值得再试**：`limit/search/category` 当前全部无效；`company_name` 未测试，但在同一缓存对象下预计同样无效。不要为参数组合消耗 4 次/日配额。
- **官方另提供 RSS Feeds**（README 链接到 `remotive-io/remote-jobs-feed`），但本 ticket 未在预算内验证；若未来要评估替代端点，应另开 ticket，不要在本 map 内擅自换源。
- **手动粘贴 JD：提升为 Discover 的主要兜底**（见 3.4），但不替换 Remotive 的真实数据演示。
- **完全换数据源/接付费 API**：超出本 map 的 destination；若“真实实习发现”成为硬需求，只标记为需要重新决策的事项，不改地图。

## 6. 局限与置信度

| 局限 | 影响 | 置信度处理 |
|---|---|---|
| 单日采样（2026-11-08），仅 8 次请求，且 8 次都命中同一缓存对象 | 不能证明长期行为；不能观察 cache miss 时参数是否生效 | “参数 no-op”对当天是**高置信**；“长期如此”是**中置信** |
| 未做 cache-busting | 无法区分 Cloudflare 缓存键忽略 query string 与源站忽略参数 | 机制判断**中置信**；客户端可观察行为**高置信** |
| 仅一个出口（Cloudflare SIN 边缘） | 其他地区/边缘可能缓存策略不同 | 地区差异**低置信/未知** |
| 11-06 只有聚合记录（10 条、job_type 分布），没有 id 列表 | 无法计算两日样本重叠率 | 只能确认“两次都 0 internship” |
| 状态页不监控 API | “all systems healthy”不能证明 API 正确 | 不作为 API 健康证据 |
| GitHub API 403、仓库 HTML 504 | 无法确认 README 何时改成当前文本 | 只能确认 2026-11-08 的当前文本 |
| 未抓取岗位详情 HTML、categories 端点、RSS | 不扩大抓取面，符合合规约束 | 相关结论不外推 |

**总体置信度**：

- 高：8 种查询返回字节级相同响应；`limit/search/category` 当天无效；样本 12 条、0 internship；公开 API 只暴露小样本（`total-job-count=12`、首页 0.4% 样本、12 个 id 全在首页 13 条中）。
- 中：这是有意的公开 API 样本化/付费墙策略，而非临时故障；长期保持。
- 低/未知：其他地区边缘、cache miss 时的源站行为、RSS/付费 API 的实际数据范围、未来是否恢复。

## 7. 引用

- Remotive 官方 API 文档页：<https://remotive.com/remote-jobs/api>（访问 2026-11-08 10:13 UTC；`last-modified: 2026-11-04 00:06:28 GMT`）
- Remotive 官方 API README：<https://github.com/remotive-com/remote-jobs-api>（访问 2026-11-08；raw README）
- Remotive 公共 API 端点：<https://remotive.com/api/remote-jobs>（2026-11-08 10:13–10:22 UTC，8 次请求，均 200）
- Remotive 官方状态页：<https://status.remotive.com/en/>（访问 2026-11-08 10:13 UTC）
- Remotive 首页（匿名样本/付费墙文案）：<https://remotive.com/>（访问 2026-11-08 10:13 UTC）
- RSS Feeds（README 链接，未在本次验证）：<https://github.com/remotive-io/remote-jobs-feed>
- 原始响应（含 JD，仓库外）：`$CLAUDE_JOB_DIR/tmp/remotive-research/`；本文只保留聚合计数与元数据。

注：本文不复制任何真实 JD 正文；岗位标题/公司/分类仅用于说明样本构成。请求全部遵守 ≤8 次、间隔 ≥65 秒的预算，未触发 429/403。
