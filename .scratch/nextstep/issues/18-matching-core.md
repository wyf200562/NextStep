# 18: 匹配核心：技能词典与 MatchingEngine

**What to build:** 随 App 加载三份数据驱动词典：技能词典（约 50 核心 + 15 可选，字段 id / name / aliases / category，中英文别名）、RoleDirectionLexicon（方向家族与中英文别名）、LocationLexicon（国家 / 地区 / 区域中英文别名）。加载规则：缺失必填字段或重复 id → 加载失败、匹配降级为「暂不可用」，浏览 / 追踪 / 导入不受影响；跨技能重复别名按词典顺序 first-wins + debug log；未知字段忽略。MatchingEngine 是纯结构（无 I/O、无 ModelContext、Sendable）：文本归一化（NFKC、大小写折叠、去 HTML、标点 / 空白归一）、别名扫描（按长度从长到短、英文词边界、中文最长子串，记录命中字段）、技能汇总（required / matched / missing）、四维评分（技能 60、方向 20、地点 10、岗位类型 10）、低置信度（描述为空或未识别技能时技能分减半）、ineligible（明确非实习或地点明确不可行，score / band 为 nil）、MatchResult（score / band / matchedSkills / missingSkills / components / eligibility / confidence / reason / evidence）与模板化中文原因。MatchService（MatchProviding）读取 UserProfile、执行画像门槛（至少 3 个可解析技能 + 至少 1 个 TargetRole），不足返回 nil；UserProfileRepository 提供 fetch-or-create 单例与默认当前时区。本票验证以单测为主，不包含 UI。

**Blocked by:** 12（工程脚手架与领域模型）

**Status:** ready-for-agent

- [ ] 三份词典可加载；技能词典覆盖 spec 的分类与别名约束（不收软技能、不收 1–2 字母歧义别名、OC 按独立 token）。
- [ ] 加载失败 / 重复 id / 缺字段 / 重复别名的处理符合 spec；未知字段忽略。
- [ ] 扫描不把 Swift 命中 SwiftUI；大小写 / 全半角 / 中英文别名结果一致；中文 JD 与 HTML 正确处理。
- [ ] 四项评分、低置信度、ineligible、总分 0–100、分项和与分档符合 spec；required == 0 时技能分 0 且低置信度。
- [ ] 方向与地点规则覆盖 20 / 15 / 0 / 10 与 10 / 5 / ineligible；远程岗位不因城市扣分。
- [ ] MatchResult 完整、原因由模板生成、evidence 记录 title / tags / description。
- [ ] 画像门槛与 UserProfileRepository 单例、默认时区有测试。
- [ ] 表驱动单测覆盖 spec Testing Decisions 的 MatchingEngine 与词典用例；确定性、不联网、不依赖系统时钟。
