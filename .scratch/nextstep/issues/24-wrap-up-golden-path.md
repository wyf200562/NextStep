# 24: 收尾与黄金路径验收

**What to build:** 交付可重复演示的 v1。Debug 构建提供「清空演示数据」，删除全部 SwiftData 记录（Application、JobPosting、InterviewRound、StatusChange、UserProfile）并清空 RefreshLedger，回到首次启动状态；Release 不包含入口。中文 README 覆盖项目简介、功能、技术栈、架构分层、三个关键取舍、运行方式（Xcode 27 / 模拟器 / 免费账号说明）、测试命令、Remotive 数据来源与合规声明、已知限制与 P1 Roadmap、设计文档链接。补齐 `docs/design/`、MIT License，巡检全局中文文案与空 / 错状态，按黄金路径手动验收。

**Blocked by:** 17（概览）、23（Remotive 来源与刷新闭环）

**Status:** resolved

- [x] Debug 清空演示数据可用（含 RefreshLedger），Release 不含入口。
- [x] README 结构与内容符合 spec；不复制真实 JD 全文；含 Remotive 署名 / 回链 / 合规与已知限制。
- [x] `docs/design/`、MIT License 就位；对外材料不依赖 `.scratch/` 原始记录。
- [x] 全局中文文案、空状态、错误提示巡检；无 print；无第三方依赖。
- [ ] 黄金路径手动走通：空状态 → Discover（真实样本或缓存兜底）→ 岗位详情匹配解释 → 导入 → 状态流转 / Deadline / 面试 → 概览事件 → 重启数据仍在。（自动化环境无 UI 交互能力：已完成真实安装/启动/杀进程重启与数据留存验证、端到端集成测试；Discover → 导入 → 状态 → 面试的 UI 点击走查仍需人工在模拟器完成，见 Answer。）
- [x] 断网时用缓存 + 粘贴虚构 iOS 实习 JD 仍能完成流程；测试全绿。（离线/缓存/手动粘贴路径由单测与 VM 测试覆盖；UI 全流程同上一项留待人工走查。）

## Answer
日期：2026-11-09。实现 commit：`73ba200`（debug 清空演示数据）、`2138284`（中文文案与空状态巡检）、`d0d96aa`（README / docs/design / LICENSE / 截图）、`c3a91b0`（黄金路径端到端集成测试）、`ceac889`（状态历史完成按钮改用非弃用 API），分支 `ticket/24-wrap-up`（基于 integration/nextstep-v1 `131ffd4`）。

### 交付内容

- **Debug 清空演示数据**：新增 `DemoDataResetter`（`@MainActor`，注入 `ModelContext` + `RefreshLedger`）。按 InterviewRound → StatusChange → Application → JobPosting → UserProfile 顺序删除全部五类记录（先删子记录，避免 cascade 二次触发；JobPosting 的 nullify 不会破坏申请快照），save 成功后调用 `RefreshLedger.reset()`；save 失败时 `context.rollback()` 并保留刷新配额以便重试。「我的 → 关于」新增 `#if DEBUG` 的「调试」区块，二次确认后清空并显示成功/失败中文提示；Release 构建编译期移除该入口。清空后提示需重启 App 才完全回到首次启动状态（运行中的 ProfileViewModel 等对象可能仍持有旧引用）。
- **中文 README**：按 spec Further Notes 2 的结构落地——项目简介 + 截图、功能、技术栈、架构图与分层、三个关键取舍（规则匹配 vs embedding/LLM；JobSource/JobPostingDraft/JobRepository 摄入缝；`@Model` 兼作领域模型 + 纯 MatchingEngine）、运行方式（Xcode 27 / iOS 27 模拟器 / 免费账号 7 天签名说明）、测试命令、Remotive 数据来源与合规声明、已知限制 + P1 Roadmap、设计文档与 License。未复制任何真实 JD 全文；无伪造 Remotive 数据集。
- **截图**：`docs/images/overview-empty.png` 与 `overview-seeded.png` 为 iPhone 18 Pro Max（iOS 27.0）模拟器真实截图；后者使用虚构公司「星河科技（虚构）」与虚构 iOS 实习岗位，验证杀进程重启后概览仍显示面试/截止事件与计数。Discover、岗位详情匹配、申请详情三张为明确标注的 SVG 占位图（`*-placeholder.svg`），不是伪造截图。
- **docs/design/**：5 篇精选中文设计说明——架构与分层、匹配引擎、岗位摄入与数据流、申请生命周期与概览派生、表现层与界面决策；不引用 `.scratch/` 原始记录，链接 ADR/GLOSSARY。
- **LICENSE**：MIT，`Copyright (c) 2026 wyf`（holder 字符串可随时按需修改）。
- **全局巡检**：修复概览空状态「会在截止前提醒你」的误导文案（v1 无通知）；技能搜索空状态与状态历史「完成」按钮改为显式中文，避免跟随系统语言出现英文；删除未使用的 `PlaceholderPage` 脚手架；全仓库无 `print`、无第三方依赖。
- **黄金路径集成测试**：`GoldenPathIntegrationTests` 用临时 on-disk SwiftData store 走通「画像门槛 → 粘贴虚构 iOS 实习 JD → 手动导入 → 匹配解释 → 导入申请 → wishlist→applied→interview → deadline + 面试轮次 → 概览事件」，并用第二个 `ModelContainer` 重新打开同一 store 验证重启后画像、岗位、申请、状态历史（3 条）和轮次仍在。

### 关键文件

- `NextStep/Data/Persistence/DemoDataResetter.swift`
- `NextStep/Features/Profile/AboutView.swift`
- `NextStepTests/Data/DemoDataResetterTests.swift`
- `NextStepTests/GoldenPathIntegrationTests.swift`
- `README.md`、`LICENSE`
- `docs/design/architecture.md`、`matching-engine.md`、`ingestion.md`、`application-lifecycle.md`、`presentation.md`
- `docs/images/overview-empty.png`、`overview-seeded.png`、`*-placeholder.svg`
- 巡检涉及：`NextStep/Features/Overview/OverviewView.swift`、`OverviewTabView.swift`、`NextStep/Features/Profile/SkillPickerView.swift`、`NextStep/Features/StatusHistory/StatusHistoryViewController.swift`

### 验证

```bash
xcodebuild -project NextStep.xcodeproj -scheme NextStep \
  -destination 'platform=iOS Simulator,id=34F2F13F-FBED-46E6-BC02-C59C545FDF2C' \
  -derivedDataPath /Users/wuyifan/.claude/jobs/82faab4c/tmp/t24-dd \
  -collect-test-diagnostics never -parallel-testing-enabled NO test
```

结果：exit 0，`** TEST SUCCEEDED **`；340 个测试函数 / 36 个 suite、设备级 `passedTests 570`、`failedTests 0`、`skippedTests 0`（iPhone 18 Pro Max / iOS 27.0）。新增 4 个测试函数（DemoDataResetter 3 + GoldenPath 1），既有测试未弱化。

- **Release 入口验证**：`xcodebuild -configuration Release -destination 'generic/platform=iOS Simulator' build` 成功；Release 可执行文件中 grep 不到「清空演示数据」「清空全部本地数据」，Debug `.debug.dylib` 中可找到 → Release 不含入口。
- **模拟器实测**：Debug 构建安装并启动成功；截图见 `docs/images/overview-empty.png`。通过一次性、未提交的临时测试向 App 真实 on-disk store 写入虚构演示数据后，`simctl terminate` 再 `launch`，概览正常显示「明天 · 面试 · 一面」「后天 · 截止」、进行中/7 天内截止计数与最近更新，截图见 `docs/images/overview-seeded.png` → 启动/重启与数据留存已在真实 App 中验证。
- **未能手动验证的部分（如实说明）**：当前环境没有 Simulator.app / DeviceHub 可交互窗口，System Events 无辅助功能权限，`simctl` 也不提供 tap 注入，因此无法在模拟器里实际点击 tab、粘贴 JD、导入申请或走状态/面试表单。Discover → 岗位详情匹配 → 导入 → 状态流转 → 面试的 UI 点击走查仍需人工完成；对应逻辑由 repository / ViewModel / MatchingEngine 测试与新增的黄金路径集成测试覆盖。三张占位截图也需在人工走查时替换。

### 决策与说明

- **删除顺序与回滚**：先删子记录再删父记录，避免 Application cascade 与显式删除同一对象；save 失败 rollback，ledger 只在 save 成功后重置。
- **清空后建议重启**：SwiftData `@Query` 页面会立即更新为空，但已存在的 ViewModel（如 ProfileViewModel）可能持有已删除模型；提示文案明确要求重启以完全回到首次启动状态，避免在旧引用上继续保存。
- **截图诚实性**：只把真实模拟器画面标为截图；无法驱动的三屏使用明确标注的占位 SVG，并在 README 与 Answer 中说明，不伪造。
- **GitHub 地址**：仓库无 remote、用户 GitHub 账号未知，继续保留中性占位 `AppInfo.provisionalGitHubURL = https://github.com/`，README 使用同一占位；不虚构用户名或仓库 URL。
- **剩余人工步骤**：① **必须的发布步骤**：仓库没有 remote、GitHub 账号未知，需由用户替换 `AppInfo.provisionalGitHubURL` 与 README 中的中性占位 `https://github.com/`，然后 push / 公开仓库（如需 `v1.0` tag 一并打）；② **验收建议**：在模拟器人工点击走一遍 UI 黄金路径，并用真实截图替换 3 张占位图——这是自动化环境无法替代的人工验收，不影响代码、文档、License、测试的完成状态。
