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

**JobIntakeMethod（岗位获取方式）**:
JobPosting 进入本机的渠道：Remotive API 或手动粘贴；未来可扩展 URL 导入。
_Avoid_: source, fetchedMethod（易与 HTTP 请求方法混淆）

**JobIdentityKey（岗位身份键）**:
JobPosting 的稳定身份字符串，由获取方式与外部 ID（或本地 UUID）组成，如 `remotive:12345`；用于刷新时 upsert 去重，不同于本机主键 `id`。
_Avoid_: dedupeKey（偏实现）, externalKey（手动录入并不 external）

**Application（申请记录）**:
用户针对一个岗位建立的一条投递记录，承载状态、状态历史、截止日期、备注，并可选关联 JobPosting。
_Avoid_: JobApplication, 投递（作为实体名时）

**Deadline（关键截止）**:
Application 的下一个关键节点时间（投递、OA、offer 回复等）；面试时间不属于 Deadline，记录在 InterviewRound。
_Avoid_: DueDate, ApplyBy（比 Deadline 更窄）

**InterviewRound（面试轮次）**:
Application 下的一轮面试记录，包含日期、形式、备注和结果。
_Avoid_: Interview

**StatusChange（状态变更）**:
Application 状态的一次转换，记录 from、to、changedAt 和可选备注。
_Avoid_: StatusHistory（它是集合概念）

### 申请状态

**wishlist（想投）**:
Application 尚未提交申请时的初始状态，表示用户想投、先占位。
_Avoid_: Saved, Bookmark

**applied（已投）**:
申请已提交、等待公司回复的状态。
_Avoid_: Submitted

**OA（在线笔试/测评）**:
公司发出的在线笔试或测评阶段，是申请流程中的一个状态，不是 InterviewRound。
_Avoid_: Assessment, 笔试（英文枚举名统一用 OA）

**interview（面试）**:
申请进入面试流程的状态；具体轮次由 InterviewRound 记录。
_Avoid_: Interviewing

**offer（录用）**:
公司给出录用意向的状态；v1 视为成功终态。
_Avoid_: Accepted（v1 不区分接受/拒绝）

**rejected（被拒）**:
公司拒绝申请的状态；v1 终态，可通过显式「重新打开」回到流程中。
_Avoid_: Failed, Declined

**withdrawn（主动撤回）**:
用户主动撤回或放弃申请的状态；v1 终态，可通过显式「重新打开」恢复。
_Avoid_: Cancelled, Abandoned

### 匹配

**UserProfile（用户画像）**:
用于匹配的全局用户信息：技能、目标方向、地点/时区、可实习时间和毕业年份。
_Avoid_: Profile, Resume

**TargetRole（目标方向）**:
UserProfile 中用于匹配的岗位方向列表，例如「iOS 开发实习」「移动端」；匹配时与 JobPosting 的 title/tags 比对。
_Avoid_: TargetDirection（代码与文档统一用 TargetRole）

**Skill（技能词条）**:
技能词典中的一条 canonical 技能，包含 id、名称、中英文别名和分类；用于从岗位文本中识别技能。它是词典数据，不是独立持久化实体。
_Avoid_: SkillEntity（v1 不建实体）, SkillLabel

**MatchResult（匹配结果）**:
由 UserProfile 与 JobPosting 计算出的派生结果，包含分数、匹配技能、缺失技能、分项解释和 eligibility；不持久化在 Application 上。
_Avoid_: MatchScore（只是其中一部分）

**技能标签**:
匹配解释中表示一项技能的小标签，分“已匹配/缺失”两种状态；是展示元素，不是领域实体。
_Avoid_: Chip, SkillLabel
