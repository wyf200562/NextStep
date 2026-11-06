# NextStep

NextStep 是一个 iOS 实习申请追踪与岗位发现应用：追踪投递状态，并从 Remotive 或手动粘贴的 JD 中发现和匹配岗位。

## Language

### 岗位与申请

**JobPosting（岗位发布）**:
从数据源（Remotive 或手动粘贴）获得的一条岗位信息，包含标题、公司、地点、标签、来源链接和 JD 文本。
_Avoid_: JobDescription（只是其中的 JD 文本）, Job（太泛）

**JD（职位描述）**:
JobPosting 中的职责与要求文本，是 JobPosting 的一部分，不是独立实体。
_Avoid_: 用 JD 指代整个岗位发布

**Application（申请记录）**:
用户针对一个岗位建立的一条投递记录，承载状态、投递日期、截止日期、备注，并可选关联 JobPosting。
_Avoid_: JobApplication, 投递（作为实体名时）

**InterviewRound（面试轮次）**:
Application 下的一轮面试记录，包含日期、形式、备注和结果。
_Avoid_: Interview

**StatusChange（状态变更）**:
Application 状态的一次转换，记录 from、to、changedAt 和可选备注。
_Avoid_: StatusHistory（它是集合概念）

### 匹配

**UserProfile（用户画像）**:
用于匹配的全局用户信息：技能、目标方向、地点/时区、可实习时间和毕业年份。
_Avoid_: Profile, Resume

**Skill（技能词条）**:
技能词典中的一条 canonical 技能，包含 id、名称、中英文别名和分类；用于从岗位文本中识别技能。它是词典数据，不是独立持久化实体。
_Avoid_: SkillEntity（v1 不建实体）, SkillLabel

**MatchResult（匹配结果）**:
由 UserProfile 与 JobPosting 计算出的派生结果，包含分数、匹配技能、缺失技能、分项解释和 eligibility；不持久化在 Application 上。
_Avoid_: MatchScore（只是其中一部分）

**技能标签**:
匹配解释中表示一项技能的小标签，分“已匹配/缺失”两种状态；是展示元素，不是领域实体。
_Avoid_: Chip, SkillLabel
