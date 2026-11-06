# Remotive API 现状复核

Type: research
Mode: AFK
Status: open
Blocked by:

## Question

2026-11-06 实测 `GET https://remotive.com/api/remote-jobs?limit=1500` 只返回 **10 条**岗位；再加 `search=internship` 仍返回同一批 10 条。样本的 `job_type` 只有 `full_time`（6）、`contract`（2）、`freelance`（2），**0 个 `internship`**。这与 07 号研究里“`limit/search/category` 可用、`job_type` 可为 internship”的记录不一致，需要核实：

- `limit`、`search`、`category` 参数当前是否仍生效？10 条是默认上限、分页行为，还是 API 变更/临时降级？
- 按 `category=software-dev`、`search=ios|swift|internship` 查询时，实际返回多少条？其中 internship / 软件相关岗位各多少？
- 如果 internship 极少，Discover 的默认查询和空状态策略应怎么调整？（只影响数据源与 UI，不改 02 的匹配算法。）
- 是否需要换端点/参数，或把“手动粘贴 JD”作为 Discover 的主要兜底？

## 输出

更新 07 的数据源约束；给 04（`JobSource`/`JobRepository` 查询与缓存）和 06（排期/演示脚本）一个明确的 Discover 查询策略。不要把真实 JD 全文复制进仓库。
