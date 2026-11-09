# 19: 用户画像页

**What to build:** 「我的」tab 可编辑唯一 UserProfile：目标方向（自由文本 chips）、技能（从技能词典多选，支持搜索、按分类分组、canonical 名称、去重、已选计数）、偏好地点（自由文本 chips）、时区（默认当前，可从常见时区选择）、可实习时间（from / until）、毕业年份。编辑使用 draft，点保存才写回；返回有未保存修改时二次确认；空字段不阻塞保存。技能少于 3 个显示「再选 N 个技能后才会计算匹配」，目标方向为空显示对应提示。词典不可用时禁用技能选择并显示「技能词典暂不可用」，其他字段仍可保存。关于区块显示版本号、Remotive 数据来源声明、GitHub 链接。时区、可实习时间、毕业年份在 v1 只展示不参与计分。

**Blocked by:** 18（匹配核心：技能词典与 MatchingEngine）

**Status:** resolved

- [x] 表单字段齐全；技能选择器支持搜索 / 分组 / 多选 / 去重 / canonical 名称 / 已选计数。
- [x] 保存写回 UserProfile；draft 与未保存确认；空画像可保存。
- [x] 技能数 / 目标方向门槛提示实时更新。
- [x] 词典不可用降级，其他字段仍可保存。
- [x] 关于区块含版本号、Remotive 声明、GitHub 链接。
- [x] ProfileViewModel 单测：保存、门槛提示、词典不可用。

## Answer

日期：2026-11-09。实现 commit：`9e84d1b`（`ticket/19-profile`，基于 integration/nextstep-v1 `0829f15`）；已合并 integration tip `4110114`（ticket 14/20），merge commit `aba840a`。

### 交付内容

- **ProfileViewModel**（`@Observable @MainActor`，`NextStep/Features/Profile/ProfileViewModel.swift`）：注入 `UserProfileRepository` 与可选 `MatchingLexicon`；初始化时 fetch-or-create 唯一画像并建立 draft 基线。draft 覆盖 skills / targetRoles / preferredLocations / timeZoneIdentifier / availableFrom / availableUntil / graduationYear。显式「保存」才写回 repository；空字段不阻塞；保存失败显示「保存失败，请重试」、回滚内存模型并保持 dirty。`hasUnsavedChanges` + `discardChanges()` 支撑未保存修改确认。
- **技能处理**：canonical 名称（`SkillDictionary.skill(named:)` 大小写不敏感）；按 dictionary id 去重；`selectedSkillCount` / `resolvableSkillCount`；载入时把历史技能 canonical 化并丢弃未知项（`AppLogger.matching.debug`）；picker 支持 toggle / isSelected / remove，`addSkill(named:)` 对未知或重复名称返回 false。
- **画像门槛提示**：可解析技能 <3 → 「再选 N 个技能后才会计算匹配」（覆盖 0/2/3 边界，N=3/1/0）；目标方向为空 → 「填写目标方向后才会计算匹配」；均随 draft 实时更新。
- **词典降级**：lexicon 为 nil 时技能选择禁用并显示「技能词典暂不可用」，addSkill/toggle 不改变选择；目标方向、地点、时区、可实习时间、毕业年份仍可编辑并保存，已有技能原样保留。`AppContainer` 新增 `matchingLexicon` 属性，与 `MatchService` 复用同一份词典；词典加载失败时 `matchProvider` 与 `matchingLexicon` 同时为 nil。
- **「我的」UI**：Form 分区——目标方向 chips、技能（已选计数 + 选择器 + 门槛提示）、偏好地点 chips、实习安排（常见时区列表、可选 from/until DatePicker、可选毕业年份）、关于入口、保存区（显式保存、dirty 指示、错误内联）。`TagFlowLayout` 自动换行，`TagPillView` 可移除。技能 picker sheet 支持搜索（canonical 名称 + 别名）、按 category 分组、多选 checkmark、canonical 名称、已选计数；无搜索结果时仍保留搜索框。我的 tab 是根页面，离开 tab 且有未保存修改时弹「放弃未保存的修改？」二次确认（放弃修改 / 继续编辑）；关于页为 push，不丢 draft。
- **关于页**：版本号与构建号来自 `Bundle.main`（CFBundleShortVersionString + CFBundleVersion），Remotive 数据来源/版权与回链声明，GitHub 链接。GitHub 地址为 `AppInfo.provisionalGitHubURL`（`https://github.com/`）占位常量；ticket 24 负责替换为正式公开仓库地址。未添加 Debug「清空演示数据」控件（ticket 24）。
- **测试**：`ProfileViewModelTests` 12 个、`TagListTests` 3 个；覆盖 load/save round-trip、canonical 去重与载入规范化、0/2/3 技能与目标方向门槛边界、空画像保存、dirty/discard/save 失败、load 失败、词典不可用降级、自由文本 chips 的 trim/去重/空白拒绝。`AppContainerTests` 增补 `matchingLexicon` 暴露与加载失败降级断言。

### 关键文件

- `NextStep/Features/Profile/ProfileViewModel.swift`、`ProfileDraft.swift`
- `NextStep/Features/Profile/ProfileView.swift`、`ProfileTabView.swift`、`SkillPickerView.swift`、`SkillCatalog.swift`
- `NextStep/Features/Profile/TagList.swift`、`TagFlowLayout.swift`、`TimeZoneCatalog.swift`
- `NextStep/Features/Profile/AppInfo.swift`、`AboutView.swift`
- `NextStep/App/AppContainer.swift`
- `NextStepTests/Features/ProfileViewModelTests.swift`、`TagListTests.swift`、`NextStepTests/App/AppContainerTests.swift`

### 验证

```bash
xcodebuild -project NextStep.xcodeproj -scheme NextStep \
  -destination 'platform=iOS Simulator,id=17EBAB32-1B3E-418E-8B69-8329F6787CAC' test
```

结果：exit 0，`** TEST SUCCEEDED **`；合并 integration 后 xcresult summary：`totalTestCount 194`（测试函数）、设备级 `passedTests 385`（含参数化用例）、`failedTests 0`、`skippedTests 0`（iPhone Air / iOS 27.0）。新增 15 个测试函数（ProfileViewModel 12 + TagList 3）。

### 决策与说明

- **未保存确认的触发点**：我的 tab 是 `NavigationStack` 根页面，没有系统返回按钮；因此「离开编辑器」实现为离开「我的」tab 时拦截并二次确认。push 关于页不会丢 draft，不触发确认。
- **载入时规范化技能**：lexicon 可用时，历史 `UserProfile.skills` 会解析为 canonical 名称并按 id 去重，未知名称丢弃（匹配引擎同样忽略），避免 picker 中显示不可选择的条目；该规范化同步作为保存基线，不会仅因规范化而显示 dirty。
- **保存失败回滚**：`repository.save` 抛错时把 `UserProfile` 恢复为保存前的值，draft 保持 dirty 以便重试，避免 SwiftData 对象停在半写入状态。
- **时区列表**：内置常见时区；若画像当前 identifier 不在列表中则置顶补入，保证 Picker 始终有有效选中项。显示名使用 zh_CN 本地化名称并附 identifier。
- **毕业年份输入**：数字键盘、仅保留最多 4 位数字，空白映射为 nil；不阻塞保存。
- **GitHub 链接**：当前为 `https://github.com/` 占位并已在关于页标注；ticket 24 替换正式 URL。
- **测试环境说明**：scheme 将测试 target 标为 `parallelizable=YES`，开发期间并发 agent 曾导致模拟器 clone 卡死（`Device was allocated but was stuck in creation state`），局部回归一度使用 `-parallel-testing-enabled NO`、私有 `-derivedDataPath` 与 `-collect-test-diagnostics never` 规避设备 clone 和失败的长时间诊断收集；最终验证已用上面的标准命令（共享 DerivedData、默认并行设置）通过，测试代码与断言未做任何环境特化。
- `AppContainer` 现在即使注入自定义 `matchProvider` 也会加载 bundle lexicon 供画像页使用；显式注入的 provider 仍被保留。既有 `AppContainerTests` 语义未变。
