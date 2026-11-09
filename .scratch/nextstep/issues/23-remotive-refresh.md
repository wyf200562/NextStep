# 23: Remotive 来源与刷新闭环

**What to build:** Discover 从 Remotive 公共 API 拉取真实每日样本，同时保持缓存优先和清晰的失败态。RemotiveJobSource 默认无关键字、category = software-dev、上限 50，每次刷新一个请求，15 秒超时；DTO 解码容错（缺 id / title / company 的条目跳过、缺 description 按空、坏日期置 nil、HTML 归一化、200 + 0 条或 12 条都算成功、忽略 total-job-count / 00-warning / 未知字段）；HTTP 错误映射为 offline / timedOut / rateLimited / server(code) / decoding。JobRepository.refreshDiscover 按 identityKey upsert，added / updated 语义为本次 touch 到的数量；RefreshLedger 持久化滚动 24 小时最多 4 次网络尝试、两次至少间隔 60 秒、6 小时自动刷新 TTL（以最近成功刷新为准）；下拉刷新忽略 TTL 但仍受配额与间隔限制；手动导入不计入配额。Discover 首次先读缓存；6 小时内成功且有缓存不自动刷新；刷新成功更新样本计数与更新时间；失败 / 配额用尽 / 太频繁时有缓存显示琥珀色非阻塞提示 + 重试，无缓存显示全屏「暂时拿不到岗位」+ 重试 + 粘贴 JD；取消不显示错误。样本头图从缓存计算 Remotive 样本 N、internship M、手动 K，并显示 Remotive 署名与「打开原岗位」回链；详情注明「本机 N 条样本之一」。

**Blocked by:** 22（匹配解释展示）

**Status:** resolved

- [x] RemotiveJobSource + DTO 解码容错、字段映射、错误映射、15 秒超时；URLSession 可注入，URLProtocol stub 测试不联网。
- [x] refresh 的 identityKey upsert、added / updated、滚动 24h ≤4 次、60 秒间隔、跨启动持久化（临时 UserDefaults suite）、lastRefreshAt 只记成功、不删除旧岗位。
- [x] Discover 刷新流程、缓存优先、所有提示 / 全屏错误 / 取消行为、样本计数、更新时间、署名回链。
- [x] 手动导入不写 ledger。
- [x] 测试：DTO / HTTP 用例、repository 节流 / upsert / 降级、DiscoverViewModel 的 refreshed / skipped / failed 处理与错误映射。

## Answer

日期：2026-11-09。实现 commit：`6b74c4b`（`feat: add Remotive source and refresh loop`，`ticket/23-remotive-refresh`，基于 integration/nextstep-v1 `147ae61`）。

### 交付内容

- **RemotiveJobSource**：`GET https://remotive.com/api/remote-jobs`，URLSession 可注入（生产用 `.shared`），请求 `timeoutInterval = 15`，每次 `loadJobs()` 只发一个请求。查询参数由 `JobQuery` 映射为 `search` / `category` / `limit`；默认 `keyword: nil`、`category: "software-dev"`、`limit: 50`，空白参数省略。HTTP 映射：2xx 成功；429 → `.rateLimited`；其余非 2xx → `.server(code)`；`URLError.timedOut` → `.timedOut`；网络不可用（未联网、连接丢失、无法解析/连接主机等）→ `.offline`；`URLError.cancelled` → `CancellationError`；JSON 解码失败 → `.decoding`。
- **RemotiveDTO**：顶层容忍 `job-count` / `total-job-count` / `0-legal-notice` / `00-warning` / 未知字段（元数据只记日志，不进入任何协议或 UI 判断）。单条按字段容错解码：`id` 支持数字或数字字符串；缺 `id` / `title` / `company_name`（trim 后为空同样算缺）的条目跳过并记 debug log，其余条目照常返回；`description` 缺失按空串；`publication_date` 容忍带/不带时区与小数秒的 ISO 8601，坏日期置 nil 且不影响整批；`url` / `company_logo_url` 必须是带 host 的 http(s) 绝对地址，否则 nil。映射：`identityKey = remotive:<id>`、`externalJobID = String(id)`、`descriptionPlainText` 经 `HTMLTextNormalizer`、`jobType` 原样小写、`tags` 原样、地点/薪资/发布时间/logo 按字段；200 + 0 条与 200 + 12 条都返回草稿数组（空数组也是成功）。
- **RefreshLedger**（`NextStep/Data/Throttling/RefreshLedger.swift`）：按 `JobIntakeMethod` 分源维护，UserDefaults 持久化（测试注入临时 suite 并在结束时 `removePersistentDomain`）。滚动 24 小时最多 4 次**网络尝试**；两次尝试至少间隔 60 秒；尝试在请求发起前记账，因此失败、超时、离线、解码失败与被取消的请求都消耗配额；`lastSuccess` 只在整批草稿全部落库后更新；`reset()` 清空所有来源，供组合根/后续 debug 清数据使用。
- **SwiftDataJobRepository**：`refreshDiscover(query:)` 先查 ledger（配额优先于 60 秒间隔），被拦时返回 `.skipped(.quotaExhausted/.tooSoon)` 且不发请求；否则记账、经 `JobSourceFactory.makeRemote` 拉取一次、按 `identityKey` 逐条 upsert。`added` 为本次新增行数，`updated` 为本次 touch 到的已有行数（同一响应内重复 identityKey 按「一次新增 + 一次更新」计），二者之和等于本次草稿数；不删除任何旧岗位。成功（含 0 条）后写 `lastSuccess`；失败返回 typed error + 当前 `cachedCount`；`CancellationError` 单独透传。`lastRefreshAt(for:)` 只读 ledger。`importManual` 不写 ledger。
- **DiscoverViewModel**：新增 `RefreshState`（idle / refreshing / refreshed / skipped / failed）与 `RefreshPrompt`。`loadAndRefreshIfNeeded()` 先读缓存；仅当缓存非空且最近成功刷新在 6 小时内时返回 `.skipped(.fresh)` 不自动刷新；否则调用 `refresh()`。`refresh()`（下拉刷新、重试、超 TTL 自动刷新共用）忽略 TTL，由 repository 继续执行配额与间隔限制。`.refreshed` → 重读缓存、重算匹配、更新「更新于」并给出「本次刷新 N 条」；`.failed` → 中文错误映射；取消 → 回到 `.idle`，不显示任何错误。有缓存时 `refreshNotice` 为琥珀色非阻塞提示（失败 / 配额 / 太频繁，带重试），无缓存时 `blockingRefreshPrompt` 为全屏「暂时拿不到岗位」（说明网络/配额/太频繁，重试 + 粘贴 JD，并说明手动粘贴不依赖 Remotive、配额明天恢复）。`lastRefreshAt` / `lastRefreshText` / `isInitialLoading` 供头图与首屏 loading 使用。
- **DiscoverView / JobDetail**：`.task` 改为异步并调用 `loadAndRefreshIfNeeded()`，ScrollView 加 `.refreshable`；样本头图增加「本次刷新 N 条」与「更新于 <日期时间>」来源行；新增琥珀色 `RefreshNoticeCard`、全屏 `BlockingRefreshState`，空状态补「重试」次按钮。JobDetail 从缓存计算 Remotive 样本数，来源区显示「数据来源 Remotive · 本机 N 条样本之一」并保留「打开原岗位」回链。
- **组合根**：`AppContainer` 默认 `makeRemote` 改为 `RemotiveJobSource(query:)`，删除 `PlaceholderRemoteJobSource`；创建并注入 `RefreshLedger`（默认 `.standard`，可注入），并以只读属性暴露给后续 ticket 24 的 debug 清数据。

### 关键文件

- `NextStep/Data/Sources/RemotiveJobSource.swift`、`RemotiveDTO.swift`
- `NextStep/Data/Throttling/RefreshLedger.swift`
- `NextStep/Data/Repositories/SwiftDataJobRepository.swift`
- `NextStep/Features/Discover/DiscoverViewModel.swift`、`DiscoverView.swift`
- `NextStep/Features/Discover/JobDetailViewModel.swift`、`JobDetailView.swift`
- `NextStep/App/AppContainer.swift`
- 测试：`NextStepTests/Data/RemotiveDTOTests.swift`、`RemotiveJobSourceTests.swift`、`RefreshLedgerTests.swift`、`SwiftDataJobRepositoryTests.swift`、`NextStepTests/Features/Discover/DiscoverViewModelTests.swift`、`JobDetailViewModelTests.swift`、`NextStepTests/App/AppContainerTests.swift`、`NextStepTests/Support/URLProtocolStub.swift`

### 验证

```bash
xcodebuild -project NextStep.xcodeproj -scheme NextStep \
  -destination 'platform=iOS Simulator,id=34F2F13F-FBED-46E6-BC02-C59C545FDF2C' \
  -derivedDataPath /Users/wuyifan/.claude/jobs/82faab4c/tmp/t23-dd \
  -collect-test-diagnostics never -parallel-testing-enabled NO test
```

结果：exit 0，`** TEST SUCCEEDED **`；336 个测试函数 / 34 个 suite，设备级 `passedTests 566`、`failedTests 0`、`skippedTests 0`（iPhone 18 Pro Max / iOS 27.0）。全部网络用例通过注入的 `URLSession` + `URLProtocolStub` 完成，未联网；节流与 TTL 用 `MutableDateProvider`、`FixedDateProvider` 与临时 UserDefaults suite 保证确定性。

### 决策与说明

- **ledger 记账时机**：按 spec「一次尝试在发起时记账」，repository 在调用 source 之前 `recordAttempt`，所以失败与被取消的尝试都消耗配额；`lastSuccess` 只在全部 upsert 成功后写入，保存失败不更新「更新于」。
- **拦截顺序**：先判 4 次/24h 配额，再判 60 秒间隔；两者同时命中时返回 `.skipped(.quotaExhausted)`，文案更贴近「今天次数已用完」。
- **TTL 只在有缓存时生效**：`loadAndRefreshIfNeeded()` 明确要求缓存非空才可能 `.skipped(.fresh)`；缓存为空即使刚刷新成功也会再尝试（仍受 repository 配额/间隔保护），避免首次启动只剩空列表。
- **取消的两层处理**：source 把 `URLError.cancelled` 映射为 `CancellationError`；repository 保留 `.failed(CancellationError)`（仍可通过 `RefreshOutcome` 观察），ViewModel 将其折叠为 `.idle`，不产生提示或全屏错误。
- **错误映射范围**：429 单独保留为 `.rateLimited`，403/404/5xx 均按 spec 归入 `.server(code)`；UI 统一显示「服务器暂时不可用（HTTP code）」。
- **URL 校验**：`url` / `company_logo_url` 仅接受带 host 的 http(s) 绝对地址，非法值置 nil 而不是让整条岗位失败或产生不可点击链接。
- **added / updated 语义**：逐条 upsert 计数，`updated` 表示本次 touch 到的已有 identityKey（不是字段变化数）；同一响应内重复 identityKey 也按 touch 次数计，保证 `added + updated == drafts.count`。
- **样本计数与更新时间**：N/M/K 始终从缓存重算；「更新于」用 ledger 的最近成功时间；「本次刷新 N 条」只反映最近一次 `.refreshed`，其他结果清空。
- **日期展示确定性**：头图与提示中的日期用注入的 `DateProvider.calendar` 取月/日/时/分，不依赖系统时区或 `formatted` 的隐式时区，测试可断言固定文案。
- **组合根暴露 ledger**：`AppContainer.refreshLedger` 为只读属性，ticket 24 的 debug「清空演示数据」可直接 `reset()`；本票未实现任何 debug 清理/README 等 ticket 24 内容。
- **未实现（按票范围）**：后台刷新、来源筛选、样本头图日期切换动效、ineligible 折叠动画（P1）；未改 02 匹配算法、`JobSource` / `JobRepository` / `RefreshOutcome` 协议，也未持久化任何匹配数据。UI 仅做代码接入，未新增 XCUITest。
