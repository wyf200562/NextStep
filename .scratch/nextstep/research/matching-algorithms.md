# 岗位匹配算法：可复用开源与数据调研

> 范围：NextStep v1（本地、可解释、无 LLM/后端；SwiftUI/iOS 26+）。核验日期 2026-11-06。
> 方法：只以仓库 LICENSE、README、Package.swift 和官方文档为准；活动时间取 GitHub API 的 `pushed_at`。
>
> 后续：ticket 02 最终采用**别名扫描（不用 NLTokenizer）**，并对不符合岗位**展示 + 标 ineligible**而非硬过滤；差异与理由见 [02 Answer](../issues/02-matching-engine.md#answer)。

## 结论

**推荐：技能词典 + 规则/加权评分（hybrid-lite，词典为主、TF-IDF/词重叠只做兜底）。** 不把 TF-IDF/余弦或嵌入作为主分数。

- 可解释性是产品需求：必须输出“匹配了哪些技能、缺哪些、各维度为什么加分”。
- 本地没有稳定语料：Remotive 每天最多 4 次刷新，IDF 会随样本剧烈波动。
- 中文 JD 的分词噪声大；词典 + 别名 + 正则比词袋余弦更可控、更可测试。
- 30 天/100 小时预算下，自写评分器约 250–350 行 Swift，比引入 Python 服务或模型便宜得多。

## 1. 简历/岗位匹配开源项目

| Name | Link | License | Language/approach | Explainable skill-level? | Portable to Swift? | Verdict |
|---|---|---|---|---|---|---|
| Resume-Matcher (srbhr) | https://github.com/srbhr/Resume-Matcher | Apache-2.0 | Python/FastAPI + Next.js；LLM 定制 + 确定性 ATS 评分：关键词 40%、技能覆盖 20%、标题 15%、章节 15%、日期 10% | 部分：共享/缺失关键词与技能覆盖，非逐技能权重 | 否：服务端 Python + LLM harness | 只借鉴权重和“缺失项”展示；不搬代码 |
| ats-resume-analyzer | https://github.com/Anshum77/ats-resume-analyzer | 无 LICENSE（GitHub API `license: null`） | Python/Flask + spaCy；TF-IDF + 余弦；正则/规则技能抽取；输出 matched/missing skills | 是：技能级 matched/missing | 否：Python | 设计参考；代码不可复用（默认版权保留） |
| AI-Resume-Job-Matcher | https://github.com/Parthshewale18/AI-Resume-Job-Matcher | README 称 MIT，但无 LICENSE 文件（API null） | Python/Streamlit；TF-IDF / Transformer / Hybrid 三档；技能抽取与 gap 分析 | 部分 | 否：Python | 不采用：许可不清、1 star、3 commits |
| ai-job-matcher (woshikros) | https://github.com/woshikros/ai-job-matcher | MIT | Python 本地应用；rule-first 证据加权：方向 30、职责 25、技术 20、业务 10、经验/学历 10、地点/薪资 5；LLM 仅可选补充 | 是：维度级证据 + 待核对项 | 否：Python；但权重模型可直接照搬 | 最值得借鉴的评分/解释设计（中文场景） |
| SkillNER | https://github.com/AnasAito/SkillNER | MIT | Python/spaCy；规则 + EMSI 技能库做技能抽取，输出 skill span/ID | 是：技能实体级 | 否；EMSI 数据许可另算 | 只看抽取思路；不要用其 EMSI 数据 |

活动/热度：srbhr 29.2k stars（pushed 2026-11-02）、Anshum77 1 star（2026-01-16）、Parth 1 star/3 commits（2026-01-04）、woshikros 21 stars（2026-11-02）、SkillNER 215 stars（2024-01-28）。GitHub topics `resume-matcher`、`job-matching` 下的项目多为小体量 Python/JS 应用，且大量没有 LICENSE；上表只保留可核验的代表，未列出的同类项目不应默认可复用。

## 2. Swift / Apple 端上组件

| Name | Link | License | Language/approach | Explainable skill-level? | Portable to Swift? | Verdict |
|---|---|---|---|---|---|---|
| NaturalLanguage `NLTokenizer` | https://developer.apple.com/documentation/naturallanguage/tokenizing-natural-language-text | Apple 系统框架（随 iOS 提供，非开源） | Swift；`.word` 分词，官方明确支持中文/日文等无空格语言 | 不适用（只做分词） | 是：第一方、零依赖 | **必用**：中文 + 英文技术词的基础分词 |
| FuzzyMatchingSwift | https://github.com/seanoshea/FuzzyMatchingSwift | Apache-2.0（LICENSE 文件；GitHub API 识别为 NOASSERTION） | Swift 6.0，iOS 16+，SwiftPM；String 模糊匹配/置信度 | 否 | 是 | 可选：别名拼写容错；非必需 |
| FuzzyMatch (ordo-one) | https://github.com/ordo-one/FuzzyMatch | Apache-2.0 | Swift 6.0，iOS 17+，SwiftPM；Levenshtein + Smith-Waterman，性能好 | 否 | 是 | 可选：比手写更快的模糊匹配 |
| SwiftTfIdf | https://github.com/aziyan99/SwiftTfIdf | MIT | Swift 5.5，iOS 12+，SwiftPM；只做单词 TF-IDF 排序，无文档向量/余弦 | 否 | 是，但能力不足 | 不建议：1 star、2022 年后未更新 |
| SwiftyStringScore | https://github.com/yichizhang/SwiftyStringScore | MIT | Swift；StringScore 的 Swift 移植，0–1 相似度 | 否 | 是（需手动集成，无 Package.swift） | 不优先：无 SwiftPM、约 4 年未更新 |
| swift-string-similarity | https://github.com/atacan/swift-string-similarity | MIT | SwiftPM；Levenshtein/Jaro-Winkler/Jaccard 等 | 否 | 是 | 可选但仅 2 stars，低成熟度 |
| SimilaritySearchKit | https://github.com/ZachNagengast/similarity-search-kit | Apache-2.0 | Swift，iOS 16+，SwiftPM；NLEmbedding/CoreML 向量 + 余弦/点积 | 否：语义相似，非技能级 | 是，但需模型且不透明 | 不推荐 v1：增加模型/性能负担，解释性差 |
| iosjieba | https://github.com/yanyiwu/iosjieba | 无 LICENSE（API null） | C++/ObjC++；结巴中文分词 iOS 版；无 SwiftPM | 不适用 | 否：需桥接，2018 年后未更新 | 不采用：许可与维护都不适合 |
| huipengo/jieba | https://github.com/huipengo/jieba | MIT | ObjC++ 包装 iosjieba；仅 CocoaPods，4 stars | 不适用 | 否：无 SwiftPM、年久 | 不采用；NLTokenizer + 自建词典足够 |

活动/热度：FuzzyMatchingSwift 61 stars（pushed 2026-04-08）、FuzzyMatch 163 stars（2026-09-23）、SwiftTfIdf 1 star（2022-08-25）、SwiftyStringScore 152 stars（约 4 年未更新）、swift-string-similarity 2 stars、SimilaritySearchKit 534 stars、iosjieba 173 stars（2018-10-05）、huipengo/jieba 4 stars。
说明：`NLTokenizer` 没有自定义词典，长串英文/型号可能被合并或拆错；因此还要用正则抽取 `[A-Za-z][A-Za-z0-9+#.]*` 这类技术 token，再与词典/别名匹配。Apple 文档原文：“neither Chinese nor Japanese uses spaces to delimit words.” 未发现可用的 SwiftPM 版 Jieba；`NLTagger` 可做词性/词形标注，但“技能别名命中”不是必需，v1 用 tokenizer + 正则即可。

## 3. 技能词典 / 分类法

| Name | Link | License | Language/approach | Explainable skill-level? | Portable to Swift? | Verdict |
|---|---|---|---|---|---|---|
| O*NET 31.0 | https://www.onetcenter.org/license_db.html | CC BY 4.0 | 数据集：CSV/Excel/JSON/SQL/RDF/API；英文/西语，无中文；职业+技能/技术工具全量库，季度更新 | 提供技能名，无匹配逻辑 | 可抽取所需字段打包为 JSON | 有 Swift（Hot Technology）；SwiftUI/UIKit 未出现在 Hot Tech 列表（技术技能粒度偏通用）；作通用技能名参照，需署名+修改说明 |
| ESCO v1.2 | https://esco.ec.europa.eu/en/use-esco/download | CC BY 4.0（EC 复用政策/官方材料；下载页需接受条款，建议下载时再确认） | 数据集：RDF/TTL/ODS/CSV/XML/JSON-LD；28 语言，无中文；全量库按需抽取 | 提供技能概念/URI，无匹配逻辑 | 可抽取英文标签/URI 打包 | 有 “Swift (computer programming)”；SwiftUI/UIKit 检索结果为 0；中文别名自建，需署名+修改说明 |
| roadmap.sh | https://github.com/kamranahmedse/developer-roadmap/blob/master/license | 自定义限制性：仅个人使用，禁止发布/复用内容 | Markdown/JSON；英文 iOS roadmap（大列表） | 技能主题列表，无评分 | 否（许可禁止复制） | **不要复制内容**；只作灵感；371k stars，pushed 2026-11-05 |
| awesome-ios | https://github.com/vsouza/awesome-ios | MIT | Markdown；英文 iOS 库/框架/工具目录（大列表） | 库名，无技能级评分 | 可摘录框架名（保留版权声明） | 补框架名/分类；53.9k stars，pushed 2026-08-27 |
| TeamStuQ/skill-map | https://github.com/TeamStuQ/skill-map | CC-BY-NC-SA 4.0（README 声明，无 LICENSE 文件） | Markdown+PNG/XMind；中文；含“移动开发/iOS”技能图 | 技能主题图，无评分 | 否（NC+SA） | 仅参考，不打包；22.1k stars |
| Stack Overflow 数据转储 | https://archive.org/details/stackexchange | CC BY-SA 4.0 | XML 转储（含 Tags）；英文标签 | 标签，无技能级评分 | 否（ShareAlike+噪声） | 不采用；标签不是技能体系 |
| GitHub topics | https://github.com/topics/ios | 无许可/非数据集 | HTML 标签页；英文 | 无 | 否 | 不采用 |
| 中文 iOS 技能清单 | https://github.com/LuckyXYJ/ios_skill_tree ; https://github.com/uzi-yyds-code/IOS-programmer-all-resources | 两者均无 LICENSE | Markdown 笔记/资源目录；中文 | 主题清单，无评分 | 否（默认版权保留） | 仅参考，不能直接复制 |

说明：没有找到“许可宽松 + 中文别名 + iOS 技能粒度”的现成词典。最稳妥的路线是自建约 50 条 canonical skill（英文名 + 中文名 + 别名），把 ESCO/O*NET 只当英文名/URI 的参照。

## 4. 建议

### 4.1 复用什么

- **Apple NaturalLanguage**：`NLTokenizer(unit: .word)` 做中英混排分词；这是唯一必用的“代码”。
- **O*NET（CC BY 4.0）**：借用通用技能名/技术工具名做参照；若把派生字段写入 app，附上 O*NET 31.0 署名、CC BY 4.0 链接和“已修改”声明。
- **ESCO（CC BY 4.0）**：借用 `Swift (computer programming)` 等 canonical 名称/URI；使用时写 “This service uses the ESCO classification of the European Commission”，并标注修改。中文标签需自建。
- **awesome-ios（MIT）**：只用来核对框架/工具名，保留 MIT 版权声明。
- **可选**：`FuzzyMatchingSwift`（iOS 16+，Apache-2.0）或 `FuzzyMatch`（iOS 17+，Apache-2.0）做拼写容错；50 条词典用精确别名通常已够，先不引入依赖。
- **只借鉴思路、不复制代码/数据**：Resume-Matcher 的 ATS 权重（40/20/15/15/10）、woshikros 的六维证据评分（30/25/20/10/10/5）。
- **明确不要用**：roadmap.sh 内容（限制性许可）、TeamStuQ（CC-BY-NC-SA）、无 LICENSE 的 Python 匹配器、EMSI 数据（SkillNER 内置库）。

### 4.2 自己写什么

- **词典 JSON**：约 50 条，字段 `id / name / aliases[] / category / parents[] / weight`；别名含英文缩写与中文，例如 `swiftui: ["swiftui", "swift ui", "声明式ui", "声明式 UI"]`，`objective-c: ["objective-c", "objc", "oc", "obj-c"]`。约 10–15 KB。
- **归一化**：`.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive])` 处理全角/大小写；保留原文用于展示。
- **匹配器**：最长别名优先，英文用词边界正则（避免 `Swift` 命中 `SwiftUI`），中文用归一化子串/分词序列；`parents` 做蕴含（SwiftUI ⇒ Swift，反向不成立）。
- **评分器 + 解释模型**：约 250–350 行 Swift；`MatchResult(score, matchedSkills, missingSkills, reasons)`。
- **测试**：约 150–200 行 Swift Testing；用虚构 JD/画像覆盖空描述、同义词、Swift/SwiftUI 子串陷阱、地点/时区、非实习、毕业年份。

### 4.3 评分设计（建议）

| 维度 | 权重 | 说明 |
|---|---:|---|
| 技能覆盖 | 55 | 必备技能权重 3、加分技能权重 1；`matchedWeight / totalWeight`；缺失的必备项单列 |
| 方向/标题 | 20 | 目标方向 vs 标题/tags（iOS、移动端、Swift 等） |
| 地点/时区 | 10 | 远程/城市/时区是否兼容 |
| 可实习时间 | 10 | 用户可实习窗口是否覆盖岗位要求 |
| 毕业年份 | 5 | 不匹配则扣分并标记原因 |
| 硬过滤 | — | 非实习（job_type/标题明确非实习）或地点完全不可行 ⇒ `ineligible`，不返回 0 分糊弄 |

可解释输出示例（不要放真实 JD）：“匹配 8/10 项技能；缺少 SwiftData、单元测试；方向匹配；时区匹配；可实习时间覆盖”。每条原因带 evidence（命中的别名/原文片段）。

### 4.4 为什么不用 TF-IDF/嵌入做主评分

- TF-IDF 需要文档集合估 IDF；本地岗位样本少且每天只刷新 4 次，分数不稳定。
- 余弦分数无法回答“缺哪项技能”，与产品的可解释目标冲突。
- 中文分词 + 技术缩写（C++、.NET、SwiftUI）会让词袋失真；词典别名更可控。
- 嵌入模型增加体积/性能/许可负担，且仍不能给出技能级证据。
- 如果以后要 hybrid：只把标题/描述的词重叠（Jaccard 或 TF-IDF 余弦）作为**封顶 5–10 分的 tie-breaker**，不进入主分。

### 4.5 工作量估算

- 词典：0.5–1 天（50 条 × 中英别名，人工校对）。
- 归一化/分词/匹配/评分/解释：1–1.5 天，约 250–350 行 Swift。
- 测试与虚构样例：0.5–1 天。总计约 2–3 天，符合 30 天预算。

## 5. 核验来源

- https://github.com/srbhr/Resume-Matcher ; LICENSE: https://cdn.jsdelivr.net/gh/srbhr/Resume-Matcher@main/LICENSE ; API: https://api.github.com/repos/srbhr/Resume-Matcher
- https://github.com/Anshum77/ats-resume-analyzer ; https://api.github.com/repos/Anshum77/ats-resume-analyzer
- https://github.com/Parthshewale18/AI-Resume-Job-Matcher ; https://api.github.com/repos/Parthshewale18/AI-Resume-Job-Matcher
- https://github.com/woshikros/ai-job-matcher ; https://api.github.com/repos/woshikros/ai-job-matcher
- https://github.com/AnasAito/SkillNER ; https://api.github.com/repos/AnasAito/SkillNER
- https://github.com/seanoshea/FuzzyMatchingSwift ; LICENSE: https://cdn.jsdelivr.net/gh/seanoshea/FuzzyMatchingSwift@develop/LICENSE ; Package.swift: https://cdn.jsdelivr.net/gh/seanoshea/FuzzyMatchingSwift@develop/Package.swift
- https://github.com/ordo-one/FuzzyMatch ; Package.swift: https://cdn.jsdelivr.net/gh/ordo-one/FuzzyMatch@main/Package.swift
- https://github.com/aziyan99/SwiftTfIdf ; Package.swift: https://cdn.jsdelivr.net/gh/aziyan99/SwiftTfIdf@main/Package.swift ; API: https://api.github.com/repos/aziyan99/SwiftTfIdf
- https://github.com/yichizhang/SwiftyStringScore ; https://github.com/atacan/swift-string-similarity
- https://github.com/ZachNagengast/similarity-search-kit
- https://github.com/yanyiwu/iosjieba ; https://api.github.com/repos/yanyiwu/iosjieba ; https://github.com/huipengo/jieba
- https://developer.apple.com/documentation/naturallanguage/tokenizing-natural-language-text ; https://developer.apple.com/documentation/naturallanguage/nltokenizer
- https://www.onetcenter.org/license_db.html ; https://www.onetcenter.org/database.html ; https://www.onetonline.org/search/hot_tech/example?e=Swift
- https://esco.ec.europa.eu/en/use-esco/download ; https://ec.europa.eu/esco/api/search?text=swift&language=en ; https://ec.europa.eu/esco/api/search?text=swiftui&language=en ; https://ec.europa.eu/esco/api/search?text=uikit&language=en
- https://github.com/kamranahmedse/developer-roadmap/blob/master/license ; https://api.github.com/repos/kamranahmedse/developer-roadmap
- https://github.com/vsouza/awesome-ios ; https://api.github.com/repos/vsouza/awesome-ios
- https://github.com/TeamStuQ/skill-map
- https://archive.org/details/stackexchange ; https://github.com/topics/ios
- https://github.com/LuckyXYJ/ios_skill_tree ; https://github.com/uzi-yyds-code/IOS-programmer-all-resources

注：GitHub API 的 `license: null` 只表示未检测到 LICENSE，不表示代码可自由使用；无许可项目默认保留全部权利。本次未发现需要用到的 GPL/AGPL 项目；主要许可风险是无 LICENSE 与 NC/SA 内容。
