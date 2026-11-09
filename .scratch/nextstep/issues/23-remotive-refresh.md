# 23: Remotive 来源与刷新闭环

**What to build:** Discover 从 Remotive 公共 API 拉取真实每日样本，同时保持缓存优先和清晰的失败态。RemotiveJobSource 默认无关键字、category = software-dev、上限 50，每次刷新一个请求，15 秒超时；DTO 解码容错（缺 id / title / company 的条目跳过、缺 description 按空、坏日期置 nil、HTML 归一化、200 + 0 条或 12 条都算成功、忽略 total-job-count / 00-warning / 未知字段）；HTTP 错误映射为 offline / timedOut / rateLimited / server(code) / decoding。JobRepository.refreshDiscover 按 identityKey upsert，added / updated 语义为本次 touch 到的数量；RefreshLedger 持久化滚动 24 小时最多 4 次网络尝试、两次至少间隔 60 秒、6 小时自动刷新 TTL（以最近成功刷新为准）；下拉刷新忽略 TTL 但仍受配额与间隔限制；手动导入不计入配额。Discover 首次先读缓存；6 小时内成功且有缓存不自动刷新；刷新成功更新样本计数与更新时间；失败 / 配额用尽 / 太频繁时有缓存显示琥珀色非阻塞提示 + 重试，无缓存显示全屏「暂时拿不到岗位」+ 重试 + 粘贴 JD；取消不显示错误。样本头图从缓存计算 Remotive 样本 N、internship M、手动 K，并显示 Remotive 署名与「打开原岗位」回链；详情注明「本机 N 条样本之一」。

**Blocked by:** 22（匹配解释展示）

**Status:** ready-for-agent

- [ ] RemotiveJobSource + DTO 解码容错、字段映射、错误映射、15 秒超时；URLSession 可注入，URLProtocol stub 测试不联网。
- [ ] refresh 的 identityKey upsert、added / updated、滚动 24h ≤4 次、60 秒间隔、跨启动持久化（临时 UserDefaults suite）、lastRefreshAt 只记成功、不删除旧岗位。
- [ ] Discover 刷新流程、缓存优先、所有提示 / 全屏错误 / 取消行为、样本计数、更新时间、署名回链。
- [ ] 手动导入不写 ledger。
- [ ] 测试：DTO / HTTP 用例、repository 节流 / upsert / 降级、DiscoverViewModel 的 refreshed / skipped / failed 处理与错误映射。
