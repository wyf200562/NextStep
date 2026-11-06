# Remotive 集成约束与数据映射

Type: research
Mode: AFK
Status: resolved
Blocked by:

## Question

把 Remotive 公共 API 作为岗位发现源，需要遵守哪些约束，数据如何映射到 NextStep？

## Answer

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
