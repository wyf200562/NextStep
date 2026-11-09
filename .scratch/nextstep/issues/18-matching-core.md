# 18: 匹配核心：技能词典与 MatchingEngine

**What to build:** 随 App 加载三份数据驱动词典：技能词典（约 50 核心 + 15 可选，字段 id / name / aliases / category，中英文别名）、RoleDirectionLexicon（方向家族与中英文别名）、LocationLexicon（国家 / 地区 / 区域中英文别名）。加载规则：缺失必填字段或重复 id → 加载失败、匹配降级为「暂不可用」，浏览 / 追踪 / 导入不受影响；跨技能重复别名按词典顺序 first-wins + debug log；未知字段忽略。MatchingEngine 是纯结构（无 I/O、无 ModelContext、Sendable）：文本归一化（NFKC、大小写折叠、去 HTML、标点 / 空白归一）、别名扫描（按长度从长到短、英文词边界、中文最长子串，记录命中字段）、技能汇总（required / matched / missing）、四维评分（技能 60、方向 20、地点 10、岗位类型 10）、低置信度（描述为空或未识别技能时技能分减半）、ineligible（明确非实习或地点明确不可行，score / band 为 nil）、MatchResult（score / band / matchedSkills / missingSkills / components / eligibility / confidence / reason / evidence）与模板化中文原因。MatchService（MatchProviding）读取 UserProfile、执行画像门槛（至少 3 个可解析技能 + 至少 1 个 TargetRole），不足返回 nil；UserProfileRepository 提供 fetch-or-create 单例与默认当前时区。本票验证以单测为主，不包含 UI。

**Blocked by:** 12（工程脚手架与领域模型）

**Status:** resolved

- [x] 三份词典可加载；技能词典覆盖 spec 的分类与别名约束（不收软技能、不收 1–2 字母歧义别名、OC 按独立 token）。
- [x] 加载失败 / 重复 id / 缺字段 / 重复别名的处理符合 spec；未知字段忽略。
- [x] 扫描不把 Swift 命中 SwiftUI；大小写 / 全半角 / 中英文别名结果一致；中文 JD 与 HTML 正确处理。
- [x] 四项评分、低置信度、ineligible、总分 0–100、分项和与分档符合 spec；required == 0 时技能分 0 且低置信度。
- [x] 方向与地点规则覆盖 20 / 15 / 0 / 10 与 10 / 5 / ineligible；远程岗位不因城市扣分。
- [x] MatchResult 完整、原因由模板生成、evidence 记录 title / tags / description。
- [x] 画像门槛与 UserProfileRepository 单例、默认时区有测试。
- [x] 表驱动单测覆盖 spec Testing Decisions 的 MatchingEngine 与词典用例；确定性、不联网、不依赖系统时钟。

## Answer

日期：2026-11-09。实现 commit：`f3293ee`（`ticket/18-matching-core`，基于 integration/nextstep-v1 `f9dc04f`）；已合并 integration tip `82843dd`（ticket 13），merge commit `0bfdfa7`。

### 交付内容

- **三份数据驱动词典**：`NextStep/Resources/SkillDictionary.json`（65 条 = 50 核心 + 15 可选；字段 id/name/aliases/category；每条中英文别名；不含软技能、不含 `go/js/os/rn/fp/c` 等 1–2 字母歧义别名；`C++` 保留；`OC` 仅词边界命中）、`RoleDirectionLexicon.json`（13 个方向家族，ios/mobile、android、backend、frontend/web、data/ml/ai、qa/test、algorithm、product、design、devops、security、embedded、game）、`LocationLexicon.json`（15 个国家/地区/区域/远程条目，含可选 parent 层级）。
- **加载器**：`MatchingLexiconLoader` 支持 Bundle 与显式 URL/Data 注入；缺必填字段、空必填字符串或重复 id → typed `MatchingLexiconError`；跨词典重复别名按词典顺序 first-wins + `AppLogger.matching.debug`；未知字段忽略；canonical 名称解析大小写不敏感。JSON 解析失败映射为 typed error。
- **MatchingEngine**：`nonisolated Sendable struct`，无 I/O、无 ModelContext、无单例。归一化（HTML 去标签/实体、NFKC、大小写折叠、标点/空白归一）；别名扫描按长度降序、英文 ASCII 词边界、中文最长子串且非重叠；required/matched/missing 与 evidence 均按词典顺序确定性输出。四维评分（60/20/10/10）、技能分取整、低置信度减半、required == 0 时技能 0 + low、ineligible 时 score/band 为 nil 而组件仍计算、分档 ≥75 / 50–74 / <50、模板中文原因。
- **方向/地点/岗位类型**：方向 20/15/0/10（目标家族命中标题/标签、仅描述、其他方向标题、未知；未映射 TargetRole 退化为字面量 + 拉丁 token）；地点 10/5/ineligible（远程/全球无区域限制 10；匹配 10；未知 5；明确不匹配 ineligible；时区标识拆分区域/城市，Asia→China、Europe→UK 通过祖先关系匹配，US/Canada 兄弟不互配）；岗位类型 10/5/0+ineligible（显式 internship、标题 intern/实习推断、未知 5、明确非实习 ineligible）。
- **MatchService**：`@MainActor`，读取 `UserProfileRepository.fetchOrCreateProfile()`，执行「≥3 个可解析技能 + ≥1 个非空 TargetRole」画像门槛，未达标返回 nil；`evaluate(jobs:)` 每次调用只读一次画像并按 `identityKey` 建字典。
- **组合根**：`AppContainer` 新增 `matchingLexiconLoader` 注入参数（默认加载 Bundle 资源），默认构造 `MatchService` 作为 `matchProvider`；加载失败记录 `AppLogger.matching.error` 并降级为 nil，不崩溃；显式注入的 `matchProvider` 优先。
- **Core**：`HTMLTextNormalizer`（nonisolated；去 script/style、标签、实体解码、段落与空白归一），供 ticket 23 Remotive 源复用；本票未实现 Remotive。
- **测试**：`MatchingLexiconTests`（33 用例）、`MatchingEngineTests`（49）、`MatchServiceTests`（7）、`HTMLTextNormalizerTests`（6）、`AppContainerTests`（6）；表驱动、固定词典/日期、无网络、不依赖系统时钟。合并 integration 后全量 133 个测试函数 / 148 个测试用例通过。

### 关键文件

- `NextStep/Resources/`：`SkillDictionary.json`、`RoleDirectionLexicon.json`、`LocationLexicon.json`
- `NextStep/Data/Matching/MatchingLexiconLoader.swift`
- `NextStep/Domain/Matching/`：`MatchingEngine.swift`、`MatchService.swift`、`MatchingLexicon.swift`、`SkillDictionary.swift`、`RoleDirectionLexicon.swift`、`LocationLexicon.swift`、`MatchingTextNormalizer.swift`、`MatchResult.swift`
- `NextStep/Core/HTMLTextNormalizer.swift`
- `NextStep/App/AppContainer.swift`
- `NextStepTests/Domain/MatchingLexiconTests.swift`、`MatchingEngineTests.swift`、`MatchServiceTests.swift`；`NextStepTests/Core/HTMLTextNormalizerTests.swift`；`NextStepTests/App/AppContainerTests.swift`

### 验证

```bash
xcodebuild -project NextStep.xcodeproj -scheme NextStep \
  -destination 'platform=iOS Simulator,id=17EBAB32-1B3E-418E-8B69-8329F6787CAC' test
```

结果：exit 0，`** TEST SUCCEEDED **`；合并 integration 后 xcresult summary：`totalTestCount 133`（测试函数）、`passedTests 148`（含参数化用例）、`failedTests 0`、`skippedTests 0`。应用 target 编译无 warning（仅 AppIntents 元数据提示）。

### 决策与说明

- **引擎主线程边界**：`MatchingEngine` 本身是 `nonisolated Sendable struct` 且计算纯同步，但 `UserProfile`/`JobPosting` 是 `@Model` 且工程开启 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`，因此公开入口标 `@MainActor` 以合法读取模型属性；无 I/O、无 ModelContext、无单例。
- **方向家族分组**：按 spec 的斜杠写法把 ios/mobile、frontend/web、data/ml/ai、qa/test 各作为一个家族；目标角色可命中家族集合中的任意一个。
- **地点层级**：LocationLexicon 增加可选 `parent` 字段（缺省/未知 parent 忽略 + debug log，不导致加载失败），使时区拆出的 Asia 能匹配 China、Europe 能匹配 UK，同时 US/Canada 兄弟节点不互相匹配；`remote` 作为保留 region id，远程且无区域限制时不扣分。
- **方向优先级**：按 spec 条目顺序 20 > 15 > 0 > 10；目标家族仅描述命中时给 15，即使标题出现其他方向。
- **岗位类型推断**：job_type 缺失或无法识别且标题含 intern/internship/实习时按 internship；显式 full_time/contract/freelance/part_time 覆盖标题推断并 ineligible。少见的 `permanent`/`contractor`/`freelancer` 也按非实习处理。
- **取整**：技能分与低置信度减半均用 `rounded()`（四舍五入、半值远离零）。
- **AppContainer 既有测试更新**：ticket 12 的占位断言 `matchProvider == nil` 改为默认非 nil（`MatchService`），并新增「注入失败 loader → nil」与「显式注入 provider 保留」用例。
- 未实现 UI、未实现 Remotive、未新增协议（`MatchProviding` 与仓库协议沿用 ticket 12 的缝）。
