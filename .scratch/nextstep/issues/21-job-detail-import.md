# 21: 岗位详情与导入申请

**What to build:** 点击 Discover 岗位卡片进入岗位详情，展示标题、公司、地点、岗位类型、标签、发布日期、薪资、来源徽标、JD 纯文本、来源与回链（有链接时）。底部导入 CTA：进入页面时按 JobPosting 查已有 Application——有非终态（wishlist / applied / oa / interview）显示「已有进行中的申请」+「查看」，点击切到申请 tab 并打开已有详情，不创建重复记录；只有终态（offer / rejected / withdrawn）显示「再次导入为申请」，确认后新建；无记录显示「导入为申请」。新建时快照公司 / 职位 / 链接 / 地点，初始 wishlist，关联 JobPosting，写初始 StatusChange；成功后切到申请 tab 并 push 新详情。申请详情显示关联岗位摘要（标题、公司、来源、原岗位链接），匹配摘要留到 22。手动粘贴 JD 保存成功后 push 同一详情页。

**Blocked by:** 14（申请详情与状态流转）、20（岗位摄入与手动粘贴 JD）

**Status:** resolved

- [x] Discover 卡片可进入 JobDetail；手动粘贴保存后 push 同一详情。
- [x] 详情字段、JD 纯文本、来源徽标与回链符合 spec 第 9 节。
- [x] 导入三种状态与去重逻辑正确；终态确认后新建。
- [x] 导入创建快照、关联、初始 StatusChange；成功后路由到新详情；已有申请路由到已有详情。
- [x] 申请详情显示关联岗位摘要；JobPosting 不存在时快照仍正常显示。
- [x] JobDetailViewModel 单测：三种导入状态、快照与关联、去重。

## Answer

日期：2026-11-09。实现 commit：`04b66bf`（`ticket/21-job-detail-import`，基于 integration/nextstep-v1 `4110114`）。

### 交付内容

- **JobDetailViewModel**（`@Observable @MainActor`，注入 `JobRepository` / `ApplicationRepository` / `DateProvider` / `jobID`，不持有 ModelContext、不做导航）：`load()` 经 `JobRepository.cachedJobs()` 按 id 查找；找不到时进入 typed `JobDetailLoadError.notFound`，其他读取失败保留原始 typed error，UI 分别显示「岗位不存在或已被删除」与「加载失败，请稍后重试」。加载时用 `ApplicationRepository.applications(for:)` 分类 CTA：任一非终态（wishlist/applied/oa/interview）→ `.viewExisting(applicationID:)`（已有进行中，绝不重复创建）；仅终态（offer/rejected/withdrawn）→ `.importAgain`；无记录 → `.importNew`。`importApplication(confirmed:)` 以快照创建申请：companyName/roleTitle 取岗位 title/company，jobURL/location 取岗位字段，初始 `.wishlist`，statusDate 取 `dateProvider.now`，deadline/notes 为 nil，`jobPosting` 关联岗位，返回新申请 id；终态重导入在 `confirmed == false` 时不写库，保存失败映射「保存失败，请重试」且不展示原始 error。
- **JobDetail UI**（替换占位页）：标题、公司、地点、岗位类型、标签、发布日期、薪资、来源徽标；JD 归一化纯文本（可选中，空时「暂无 JD 正文」）；来源区 Remotive 显示「数据来源 Remotive · 本机样本之一」+「打开原岗位」（有 URL 时），手动导入显示「手动导入」+ 可选原链接。底部 safe-area CTA 三种状态：「已有进行中的申请」+「查看」、终态时「再次导入为申请」（先 confirmationDialog）、无记录时「导入为申请」；成功后 `router.openApplication(id)` 切到申请 tab 并 push 新详情，已有申请同样路由到已有详情；失败用中文 alert。匹配区域在 header 与 JD 之间留出 ticket 22 的明确插入点，本票不渲染匹配 UI。
- **两条入口**：Discover 卡片沿用既有 `DiscoverRoute.jobDetail`；手动粘贴保存仍以 `path = [.jobDetail(jobID:)]` push 同一详情页（ticket 20 行为），两处都使用同一个 `JobDetailView`。
- **申请详情关联岗位摘要**：新增纯展示 helper `ApplicationJobPostingSummary`（标题、公司、来源 displayName、原链接），详情页追加一个「关联岗位」Section，仅在 `application.jobPosting != nil` 时出现；`JobPosting` 为 nil 时快照区照常显示，不出现额外区块。匹配摘要留给 ticket 22。
- **测试**：`JobDetailViewModelTests` 覆盖三种 CTA、活动态优先于终态、无记录导入的快照/关联/初始状态、确认门禁、活动态零重复、加载失败两种中文文案、保存失败文案与错误清除，以及 in-memory SwiftData 端到端验证「导入后申请关联岗位且写入初始 StatusChange」；`ApplicationJobPostingSummaryTests` 覆盖 Remotive/手动来源、有无链接与 nil 情形。

### 关键文件

- `NextStep/Features/Discover/JobDetailViewModel.swift`、`JobDetailView.swift`
- `NextStep/Features/Applications/ApplicationJobPostingSummary.swift`、`ApplicationDetailView.swift`（仅追加关联岗位 Section）
- `NextStepTests/Features/Discover/JobDetailViewModelTests.swift`、`NextStepTests/Features/ApplicationJobPostingSummaryTests.swift`、`NextStepTests/Support/FakeApplicationRepository.swift`（`applications(for:)` 支持配置返回值）

### 验证

```bash
xcodebuild -project NextStep.xcodeproj -scheme NextStep \
  -destination 'platform=iOS Simulator,id=34F2F13F-FBED-46E6-BC02-C59C545FDF2C' \
  -derivedDataPath /tmp/nextstep-t21-dd -collect-test-diagnostics never \
  -parallel-testing-enabled NO test
```

结果：exit 0，`** TEST SUCCEEDED **`；193 个测试函数 / 389 个参数化用例全部通过，0 失败 0 跳过（新增 14 个测试函数 / 19 个用例）。App 在同一模拟器安装并启动成功（4 个中文 tab 正常，无崩溃）。

合并 `integration/nextstep-v1`（`ad3af0f`，含 tickets 15/19）后重跑同一套件：exit 0，`** TEST SUCCEEDED **`，211 个测试函数 / 412 个参数化用例全部通过，0 失败 0 跳过。合并仅一处冲突在 `ApplicationDetailView.swift`（保留关联岗位 Section 与 ticket 15 状态历史入口 Section）。

### 决策与说明

- 确认门禁放在 ViewModel（`importApplication(confirmed:)`）而不是只靠 View 弹窗，使「终态需确认才创建」可单测；View 依据 `importRequiresConfirmation` 弹 confirmationDialog 后传 `confirmed: true`。导航仍由 View 调 `router.openApplication`，VM 不持有 router。
- `applications(for:)` 读取失败时记录 ui 日志并退化为 `.importNew`（岗位仍可浏览/导入）；spec 未定义该路径，选择不阻塞详情页。
- 同一岗位存在多条进行中申请时取 repository 返回顺序中的第一条非终态；spec 未规定选择规则。
- 导入成功跨 tab 后 Discover 栈仍停在该岗位详情（未主动清栈）；spec 只要求切 tab 并 push 新详情。
- 申请详情摘要通过纯 helper 生成展示输入，便于测试；关联区块追加在备注 Section 之后，尽量减少与并行 ticket 15/16 对 `ApplicationDetailView.swift` 的冲突面。
- 未实现：匹配解释/分组/JD 高亮（22）、Remotive 刷新与 ledger（23）、概览 dashboard（17）、状态历史与面试轮次（15/16）。
