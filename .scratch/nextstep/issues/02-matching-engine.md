# 匹配算法与技能词典

Type: grilling
Mode: HITL
Status: resolved
Blocked by: 01

## Question

岗位匹配怎么做，才能既在 30 天内完成、又能在面试里讲清楚？

- 输入：用户画像（技能、目标方向、城市/时区、可实习时间、毕业年份）与岗位（标题、标签、描述、地点、job_type）。
- 算法：技能词典 + 加权评分 vs TF-IDF/余弦相似度 vs 混合；权重如何定？
- 中文 JD：NaturalLanguage 分词 + 自建技能词典/别名表 + 正则后处理；需要覆盖哪些 iOS 技能词（Swift、SwiftUI、UIKit、MVVM、SwiftData、网络、算法等）？
- 可解释性：如何展示“匹配了哪些、缺哪些、为什么是这个分数”？
- 测试：用哪些虚构 JD/画像做单元测试，边界情况是什么（描述为空、技能同义词、地点不匹配、非实习岗位）？

## Answer

### 结论

v1 采用**技能词典 + 规则加权**的 hybrid-lite 匹配：本地、确定性、可解释、可测试；TF-IDF / embedding / LLM 不作为主分。解释展示采用[原型](../prototypes/02-match-explanation.html)的**变体 A**：列表卡片直接给分数 + 技能标签；详情长滚动给匹配/缺失、分项、一句话原因和 JD 高亮。所有公司、岗位、JD 均为虚构。

### 输入与前置

- UserProfile：技能（词典多选，二值）、目标方向、地点/时区、可实习时间、毕业年份。
- JobPosting：标题、标签、描述、地点、`job_type`。
- **画像门槛**：至少 3 个技能 + 目标方向才计算；否则 `MatchResult` 为 nil，UI 显示“完善画像后查看匹配”，岗位仍可浏览。
- 匹配是派生数据：不写入 `Application` / `JobPosting`；每次读取时计算。

### 技能词典

- 约 50 条核心 + 15 条可选；数据驱动（JSON/plist）；字段 `id / name / aliases[] / category`。
- 覆盖：iOS/Swift 核心、架构、数据、并发、网络、测试、工具、CS 基础、发布/平台；**不含软技能**。
- 每个词条配中英文别名；英文用词边界，中文用别名最长匹配。
- 初稿：[技能词典初稿](../skill-dictionary.md)。
- v1 不建独立 `Skill` 实体，不做 `parents` 技能蕴含；都留 P1。

### 匹配管线

1. **归一化**：NFKC 全半角、大小写、去 HTML、标点/空白归一；保留原文用于展示。
2. **词典扫描**：别名按长度从长到短；英文用词边界（避免 `Swift` 命中 `SwiftUI`），中文用子串/最长匹配；记录命中的字段（标题/标签/描述）和别名。
3. **汇总**：岗位命中的技能集合 = `requiredSkills`；画像也有的 = `matchedSkills`；岗位有但画像没有 = `missingSkills`。
4. **不做**：`NLTokenizer`（已知别名的精确扫描不需要分词，减少一个变量）、否定词、必备/加分区分。
5. **输出**：`MatchResult`（见下）。

### 评分

| 维度 | 权重 | 规则 |
|---|---:|---|
| 技能覆盖 | 60 | `60 * matched / required`；所有技能提及等权；`required == 0` 时技能分 0 且标低置信度 |
| 方向 | 20 | 目标方向 vs 标题/标签：命中 20；仅描述命中 15；明确其他方向 0；未知 10 |
| 地点 | 10 | 全球/用户所在区域 10；明确不包含用户区域 0；未知 5；远程岗位不因城市扣分 |
| 岗位类型 | 10 | internship 10；未知 5；full_time / contract / freelance 0 |

- **总分**：四项之和，0–100；分档 ≥75 强匹配 / 50–74 可尝试 / <50 低匹配。
- **不符合（ineligible）**：`job_type` 明确非实习，或地点明确不可行。此时不展示总分，只展示 `ineligible(reason)` 和技能匹配；岗位仍展示并排在 eligible 之后，不隐藏、不给假 0 分。
- **低置信度**：描述为空或未识别到任何技能时，技能分乘 0.5，分数带 `*`，UI 显示“低置信度 / 信息不足”。
- **可实习时间、毕业年份**：v1 只展示，不计分（岗位侧没有结构化字段，正则猜不可靠）；P1 再评估。
- **必备/加分**：v1 等权；P1 再做 3:1。
- `job_type` 缺失时，标题含 “intern / 实习” 视为 internship，否则 unknown。

### 解释模型

```swift
struct MatchResult {
    let score: Int?                 // ineligible 时为 nil
    let band: MatchBand?            // strong / medium / low；ineligible 时为 nil
    let matchedSkills: [SkillID]
    let missingSkills: [SkillID]
    let components: MatchComponents // skills / direction / location / jobType
    let eligibility: Eligibility    // .eligible | .ineligible(reason)
    let confidence: Confidence      // .high | .low
    let reason: String              // 模板生成的一句话
    let evidence: [SkillEvidence]   // skillID + field + matchedAlias
}
```

- `SkillEvidence.field` 至少记录 `title / tags / description`；字符范围 P1。
- 一句话原因由模板生成，不手写，例如：“匹配 6/8 项技能；缺少 Combine、SwiftData；远程全球，实习岗位。”
- UI 不持久化 `MatchResult`；Application 详情如需展示，重新计算。

### 展示（变体 A）

- **列表**：分数 pill + 匹配/缺失数量 + 前 3 个匹配标签 + 前 2 个缺失标签 + `+N`；不符合岗位标 `ineligible` 并排在最后；低置信度带 `*`。
- **详情**：分数 hero、匹配标签、缺失标签、四项分项条、JD 摘要（匹配绿色 / 缺失红色高亮）、不符合/低置信度 banner；画像不足显示 gate。
- **原型**：[匹配解释展示原型](../prototypes/02-match-explanation.html)（变体 A 胜出；B/C 作为探索保留）。
- **命名**：UI/文档叫“技能标签”；Swift 类型 `SkillTag` / `SkillTagView`；不用 `SkillLabel`（与 SwiftUI `Label` 冲突）、不用 `Chip`。

### 测试

- 纯函数 `MatchingEngine` + Swift Testing 表驱动；fixture 全虚构，不把真实 JD 入库。
- 用例：空描述、无技能命中、同义词/别名、大小写/全半角、中文 JD、HTML、`Swift`/`SwiftUI` 子串陷阱、零重叠、全匹配、重复提及、地点不符、非实习、低置信度、画像门槛、分数边界/确定性。
- 断言：`0...100`、排序、分项和、`ineligible` 不给总分、大小写/别名不影响结果；**不写死具体分数**（避免词典微调导致大面积红灯）。
- 工作量：词典 0.5–1 天 + 匹配/评分 1–1.5 天 + 测试 0.5–1 天，约 2–3 天。

### 明确不做（v1）

- TF-IDF / embedding / LLM 主分（P1 只允许封顶 5–10 分 tie-breaker）；`NLTokenizer`；否定词；必备/加分权重；可实习时间/毕业年份计分；自由文本技能；软技能；Skill/Company 实体；把 `MatchResult` 持久化；隐藏 ineligible 岗位；“只看实习”筛选（P1）。

### 交接

- **03**：`UserProfile.skills` 用 `[SkillID]`；`JobPosting` 字段按 07；`MatchResult` 派生不持久化；技能标签不是实体。
- **04**：`MatchingEngine` 纯模块，接收 `(UserProfile, JobPosting, SkillDictionary)`；词典从 JSON/plist 注入；`JobSource` 不负责匹配。
- **06**：匹配器 + 词典 + 测试约 2–3 天；排期放在“追踪器闭环”之后、“Remotive”之前。
- **09**：Remotive API 当前样本异常（10 条、0 internship），另开 research 复核；不影响本 ticket 的算法。

### 资产

- [可复用开源调研](../research/matching-algorithms.md)
- [匹配解释展示原型](../prototypes/02-match-explanation.html)
- [技能词典初稿](../skill-dictionary.md)
