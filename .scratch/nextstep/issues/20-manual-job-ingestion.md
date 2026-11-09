# 20: 岗位摄入与手动粘贴 JD

**What to build:** Discover tab 展示本机缓存的手动导入岗位，并提供常驻「粘贴一份 JD」入口。粘贴表单字段：岗位标题、公司、JD 正文（多行）、地点、岗位链接、岗位类型（实习 / 全职 / 合同 / 自由职业 / 兼职 / 未知）、标签（逗号分隔）；未手动选类型且标题含 intern / 实习时保存为 internship；标签 trim / 去空 / 去重；必填为空或 URL 非法时内联报错；保存中禁用按钮，失败保留表单内容并显示中文错误。保存走统一的 JobSource → JobPostingDraft → JobRepository 摄入缝：ManualJobSource 生成 `manual:<uuid>` identityKey，校验失败抛 `.invalidInput`，不消耗 Remotive 配额；JobRepository 是唯一写入口，按 identityKey upsert，cachedJobs 按 createdAt 降序、同时间用 id 兜底，不删除旧岗位。Discover 显示常驻样本头图（本机手动导入 K 条；Remotive 的 N / M 暂为 0）、虚线粘贴卡片、只看实习开关（纯 UI 过滤）、缓存岗位列表与空状态。本票不包含岗位详情与匹配展示（21、22）。

**Blocked by:** 12（工程脚手架与领域模型）

**Status:** resolved

- [x] JobSource / JobPostingDraft / JobQuery / JobSourceFactory 协议就位；ManualJobSource 校验、identityKey、async throws；手动导入不耗配额、不写 RefreshLedger。
- [x] 表单字段、intern 推断、标签处理、内联错误、保存中禁用、失败保留内容。
- [x] JobRepository 的 importManual / cachedJobs / upsert 正确；identityKey 去重；排序正确；重启后仍在。
- [x] Discover 样本头图、粘贴入口、缓存列表、只看实习过滤、空状态。
- [x] 保存成功返回 Discover 并立即看到新岗位。
- [x] 单测：ManualJobSource 校验 / identityKey / 配额；JobRepository upsert / 排序。

## Answer

日期：2026-11-09。实现 commit：`d6a0e46`（`ticket/20-manual-job-ingestion`，基于 integration/nextstep-v1 `f9dc04f`）。

### 交付内容

- **手动来源**：`ManualJobSource`（nonisolated Sendable）校验 trim 后的 title/company/JD 非空、URL 若填写必须是带 host 的 http(s) 绝对地址，否则抛 `JobSourceError.invalidInput`；tags trim、去空、按首次出现去重；`jobType` 显式值时小写保存，nil/空白且标题含 `intern`/`实习` 时推断为 `"internship"`；生成 `manual:<uuid-lowercased>` identityKey，`intakeMethod = .manual`，externalJobID/publishedAt 为 nil，`loadJobs()` 返回恰好一条 draft。不触碰 RefreshLedger（本票无 ledger）。
- **仓库**：`SwiftDataJobRepository`（@MainActor，注入 ModelContext + DateProvider + JobSourceFactory）。`importManual` 经 `makeManual` 取 draft，按 identityKey 查已有行：命中则更新字段并保留 id/createdAt，未命中则用 `dateProvider.now` 作为 createdAt 插入；保存后返回 `JobPosting`。`cachedJobs()` 按 createdAt 降序、同时间 id 升序；`lastRefreshAt` 返回 nil；`refreshDiscover` 返回 `.failed(RepositoryError.unavailable, cachedCount:)` 并注释由 ticket 23 替换。
- **组合根**：`AppContainer` 默认注入 `JobSourceFactory`（`makeManual` → `ManualJobSource`，`makeRemote` → `PlaceholderRemoteJobSource`，后者抛 `.offline`，ticket 23 替换）和 `SwiftDataJobRepository`，并把工厂以非可选 `let` 暴露；初始化参数仍可注入。`UnavailableJobRepository` 不再被默认路径使用，已删除。
- **Discover**：`DiscoverViewModel`（@Observable @MainActor，注入 JobRepository + DateProvider）持有缓存 `LoadState`、`onlyInternships`、从缓存计算的 Remotive N / 其中实习 M / 手动导入 K、中文缓存错误文案；不包含刷新/TTL/配额逻辑。页面为常驻样本头图（样本模式徽标、日期 overline、大标题 `Discover`、一句 deck、N/M/K、样本说明、来源行），虚线「粘贴一份 JD」卡片（本地匹配，不消耗 Remotive 配额），只看实习开关，缓存岗位卡片（标题/公司/地点/类型/标签/来源徽标），按仓库顺序（createdAt 降序）。无岗位时显示「还没有岗位」+ 样本说明 + 粘贴 JD；筛选后为空时显示「今天的样本里没有实习」+ 说明 + 粘贴 JD + 查看全部；缓存读取失败显示中文错误卡 + 重新加载。
- **手动表单**：`ManualImportViewModel` + `ManualImportView` 提供岗位标题*、公司*、JD 正文*（多行）、地点、岗位链接、岗位类型（实习/全职/合同/自由职业/兼职/未知 → `internship`/`full_time`/`contract`/`freelance`/`part_time`/nil）、标签（中英文逗号分隔），内联校验必填与 URL，保存中禁用按钮并显示「保存中…」，失败保留全部输入并显示中文错误（如「保存失败，请重试」），成功后以新岗位 id 替换表单路由为 `JobDetailView`（现有占位，ticket 21 接入内容）；返回 Discover 时 `onAppear` 重新读取缓存，立即看到新岗位。
- **未实现（按票范围）**：Remotive source/DTO/RefreshLedger/TTL、匹配分组与 JobDetail 内容/导入 CTA、Application 导入。`JobDetailView` 保持原占位。

### 关键文件

- `NextStep/Data/Sources/ManualJobSource.swift`、`NextStep/Data/Sources/PlaceholderRemoteJobSource.swift`
- `NextStep/Data/Repositories/SwiftDataJobRepository.swift`（删除 `UnavailableJobRepository.swift`）
- `NextStep/App/AppContainer.swift`
- `NextStep/Features/Discover/DiscoverViewModel.swift`、`DiscoverView.swift`、`DiscoverTabView.swift`
- `NextStep/Features/Discover/ManualImportViewModel.swift`、`ManualImportView.swift`
- 测试：`NextStepTests/Data/ManualJobSourceTests.swift`、`NextStepTests/Data/SwiftDataJobRepositoryTests.swift`、`NextStepTests/Features/Discover/DiscoverViewModelTests.swift`、`NextStepTests/Features/Discover/ManualImportViewModelTests.swift`、更新 `NextStepTests/App/AppContainerTests.swift`

### 验证

```bash
xcodebuild -project NextStep.xcodeproj -scheme NextStep \
  -destination 'platform=iOS Simulator,id=34F2F13F-FBED-46E6-BC02-C59C545FDF2C' test
```

结果：exit 0，`** TEST SUCCEEDED **`；61 个测试用例（46 个测试函数，含参数化用例）全部通过，0 失败。新增覆盖：ManualJobSource 校验/URL/标签/身份键/异步、intern 推断；SwiftDataJobRepository 导入持久化、identityKey upsert 幂等且保留 createdAt、缓存排序与 id 兜底、refreshDiscover 占位与 lastRefreshAt；DiscoverViewModel 缓存加载、N/M/K 计数、只看实习过滤、错误中文映射；ManualImportViewModel 内联校验、URL 校验、成功保存的输入归一化、失败保留内容与中文错误、岗位类型映射。App 已在同一模拟器安装并启动成功（概览 tab 与 4 个中文 tab 正常显示）。

合并前先把 integration/nextstep-v1 `3f090ae`（tickets 13/14/18）合入本分支，merge commit `513025c`；冲突仅出现在 `AppContainer` / `AppContainerTests`（组合根与默认仓库），已同时保留匹配服务、ApplicationRepository 与 JobSourceFactory/SwiftDataJobRepository 的默认装配。合并后再次运行同一命令：exit 0，370 个测试用例（179 个测试函数）全部通过，0 失败。

### 决策与说明

- 排序兜底方向：spec 只写「同时间 id 兜底」，本实现取 **id 升序**并在测试中固定，避免未来实现歧义。
- URL 合法性定义为「带 host 的 http/https 绝对地址」；VM 与 source 都做同一校验（VM 负责内联提示，source 仍是最终防线）。
- 显式岗位类型优先于标题推断；仅当类型为 nil/空白时才用标题推断，避免覆盖用户选择。
- deck 文案与空状态细节 spec 未固定，取「今天的 Remotive 样本，和你手动粘贴的岗位。」；「今天 N 条里 0 条实习」的筛选空状态按 spec §8 落地，刷新横幅/全屏错误留给 ticket 23。
- Discover 的 ViewModel 在 `.task` 创建并读缓存，返回页面时 `.onAppear` 重读，满足「保存后立即看到新岗位」且不引入刷新逻辑。
- `AppContainer.jobSourceFactory` 由 `var JobSourceFactory?` 改为 `let JobSourceFactory`；默认 `jobRepository` 改为 `SwiftDataJobRepository`，`AppContainerTests` 相应更新。ticket 23 只需替换 `PlaceholderRemoteJobSource` 并把刷新/ledger 接入 `SwiftDataJobRepository`。
- `/tmp` 下截图仅用于本票手动验收，未提交仓库。

