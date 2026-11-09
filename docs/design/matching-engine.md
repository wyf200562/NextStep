# 匹配引擎设计

匹配回答两个问题：这份岗位**是否值得投**（eligibility），以及**为什么**是这个分数（可解释的 `MatchResult`）。全部计算在本地、同步、确定性完成，不依赖网络、LLM 或 embedding。

## 输入与边界

`MatchingEngine` 是 `Domain/Matching` 下的纯 `struct`：无 I/O、无 `ModelContext`、无单例。它接收：

- `UserProfile`（技能、目标方向、偏好地点、时区）；
- `JobPosting`（标题、标签、JD 纯文本、地点、岗位类型）；
- 三份随 App 加载的词典：`SkillDictionary`、`RoleDirectionLexicon`、`LocationLexicon`。

薄 `MatchService`（实现 `MatchProviding`）负责读取画像、执行画像门槛、调用引擎，并暴露 `evaluate(job:)` / `evaluate(jobs:)`。Discover、岗位详情、申请详情只依赖它。

`@Model` 实例直接作为引擎输入，不额外造值类型；匹配结果从不落库。

## 词典

**技能词典**约 50 条核心 + 15 条可选，字段 `id / name / aliases / category`，每条都有中英文别名。覆盖 iOS/Swift、架构、数据、并发、网络、测试、工具、CS 基础、发布/平台；不收软技能，不收 1–2 个字母的歧义别名（`go`、`js`、`os`、`rn`、`fp`、`c`），`OC` 只按独立 token 匹配。

- 缺失必填字段或重复 `id` → 整份词典加载失败，匹配降级为「暂不可用」，浏览/追踪/导入不受影响。
- 跨技能重复别名按词典顺序 first-wins + debug log；未知字段忽略。
- `UserProfile.skills` 存 canonical 名称，解析时大小写不敏感；未知名称忽略 + debug log。

**方向词典**把「iOS 开发实习」「移动端」等目标方向归入方向家族（iOS/mobile、android、backend、frontend、data/ml、qa、algorithm、product、design、devops、security、embedded、game 等），带中英文别名。**地点词典**收录常见国家/地区/区域的中英文别名。两份词典与技能词典一起加载为只读值；任一加载失败都会让匹配降级。

## 管线

1. **归一化**：NFKC 全半角、大小写折叠、去 HTML、标点/空白归一；原文保留用于展示。
2. **技能扫描**：别名按长度从长到短；英文用词边界（`Swift` 不会命中 `SwiftUI` 的一部分），中文用最长子串匹配；记录命中字段（title / tags / description）与命中别名。
3. **技能汇总**：岗位命中的技能集合 = `requiredSkills`；画像也有的 = `matchedSkills`；岗位有而画像没有 = `missingSkills`。
4. **四维评分**：技能 60、方向 20、地点 10、岗位类型 10，总分 0–100。
5. **输出 `MatchResult`**：分数/分档、匹配与缺失技能、四项分项、eligibility、置信度、模板化中文原因、evidence。

## 评分规则

| 维度 | 权重 | 规则摘要 |
|---|---:|---|
| 技能覆盖 | 60 | `round(60 × matched / required)`；所有技能提及等权；`required == 0` 时技能分 0 且低置信度 |
| 方向 | 20 | 目标方向命中标题/标签 20；仅描述命中 15；命中其他方向 0；未知 10 |
| 地点 | 10 | 全球/远程或命中用户区域 10；未知 5；明确不包含用户区域 → ineligible |
| 岗位类型 | 10 | internship 10；未知 5；明确非实习 → 0 且 ineligible |

- 分档：≥75 强匹配 / 50–74 可尝试 / <50 低匹配。
- **低置信度**：描述为空，或未识别到任何技能时，`confidence = .low`，技能分减半后取整；UI 标 `*` 并提示「低置信度 / 信息不足」。
- **ineligible**：`score = nil`、`band = nil`，但仍计算 matched/missing 与分项；UI 不展示假 0 分，只展示不符合原因（如「非实习（全职）」「地点不符（Europe）」）和技能命中数。
- **画像门槛**：至少 3 个能解析到词典的技能 + 至少 1 个目标方向；不足时 `MatchResult = nil`，页面显示「完善画像后查看匹配」，岗位仍可浏览、分组和导入。eligible/ineligible 分组不依赖画像技能，因此画像不足时仍按岗位类型和地点分组。

## 展示层的解释方式

- **列表卡片**：分数 pill（ineligible 显示「不符合」）+ 分档 +「匹配 X/Y」+ 前 3 个匹配技能 + 前 2 个缺失技能 + `+N` + 一句原因。
- **详情**：分数 hero、四项分项条、匹配/缺失标签、模板原因、JD 高亮（matched 绿色、missing 红色，最长优先、非重叠，仅展示不持久化）。
- **申请详情**：关联岗位下现算一版紧凑摘要；JobPosting 已删除则整块隐藏，快照字段仍正常显示。

## 为什么不用 embedding / LLM

- **优点**：确定性、可解释、可单测、零 API 成本、无隐私外发，分数能直接对应到具体技能和规则。
- **代价**：召回受词典覆盖限制，语义泛化弱（同义改写、未收录技能可能漏匹配）。
- **取舍**：v1 选择规则加权；embedding 只作为未来 5–10 分的 tie-breaker 候选，不进入主分。

测试只断言不变量（0–100、分项和、ineligible 无总分、别名/大小写不影响结果、排序与门槛），不写死具体分数，避免词典微调导致大面积红灯。
