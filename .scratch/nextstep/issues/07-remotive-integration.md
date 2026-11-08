# Remotive 集成约束与数据映射

Type: research
Mode: AFK
Status: resolved
Blocked by:

## Question

把 Remotive 公共 API 作为岗位发现源，需要遵守哪些约束，数据如何映射到 NextStep？

## Answer

> **2026-11-08 复核：`limit` / `search` / `category` 当前全部 no-op，公开 API 仅每日约 10–12 条样本；下列参数可用性与“可作为发现源”结论已过时，修订见文末 Comments 与 [Remotive API 现状复核](09-remotive-api-recheck.md）。**

已核实（2026-11-05，README + 实际请求）：

- 端点：`GET https://remotive.com/api/remote-jobs`；支持 `search`、`category`、`company_name`、`limit`；无需鉴权。
- 速率：建议每天最多 4 次；超过每分钟 2 次会被封；数据延迟 24 小时。
- 合规：必须标注 Remotive 为来源并回链原岗位 URL；不得转投第三方招聘聚合站；不得用岗位列表收集注册/邮箱。
- 字段：`id`、`url`、`title`、`company_name`、`company_logo`、`category`、`tags`、`job_type`（可为 `internship`）、`publication_date`、`candidate_required_location`、`salary`、`description`（HTML）。
- 局限：全球远程岗位，不覆盖中国本地实习；`search` 会搜描述，结果较松，需要客户端过滤/匹配。
- 映射：`JobPosting` 保留 `source=remotive`、`sourceURL`、`title`、`company`、`location`、`jobType`、`tags`、`descriptionPlainText`、`publishedAt`；展示时保留 Remotive 署名与外链。
- 缓存：SwiftData 本地缓存；按 4 次/天上限做刷新节流；离线可读。

## Comments

研究由 2026-11-05 的 WebFetch + curl 完成。

### 2026-11-08 复核修订（Remotive API 现状复核）

见 [Remotive API 现状复核](09-remotive-api-recheck.md) 与 [研究文档](../research/remotive-api-recheck.md)。公开 API 当前只返回每日小样本，逐条修订：

- **参数**：`limit`、`search`、`category` 当前全部 no-op；同一天 8 种查询返回字节级相同的 12 条样本。不要依赖服务端过滤；客户端过滤/匹配从“建议”变为“必须”。`company_name` 未单独测试，同一缓存机制下预计同样无效。
- **数据范围**：公开 API 只暴露每日约 10–12 条样本（`job-count` / `total-job-count` = 12），不是全量岗位库；同一天首页匿名也仅 13 条，完整库走私有付费 API。11-08 样本 0 个 internship（11-06 也为 0）。
- **定位**：仍可作为真实数据/集成演示源；作为“实习岗位发现源”当前不成立。手动粘贴 JD 提升为 Discover 主要兜底，但继续走既有 `ManualJobSource`。
- **字段**：原映射字段仍成立；新增 `total-job-count`（可选，用于样本模式判断）、`company_logo_url`（可选）、顶层 `00-warning`（忽略）；`job_type` 本次 12/12 有值（并非“经常不填”）。
- **仍成立**：端点、无鉴权、≤4 次/天、>2 次/分钟会被封、24h 延迟、署名回链/禁止转投/禁止收集邮箱、全球远程不覆盖中国本地、SwiftData 缓存 + 节流。每日快照下 1 次/日成功刷新即可覆盖 24h 内容；4 次/日是上限不是目标。
