# NextStep：30 天 iOS 实习作品 v1 规格

## Destination

一份 30 天内可交付的 NextStep v1 规格与演示方案：实习申请追踪 + 岗位发现/匹配（Remotive API + 手动导入），包含功能边界、领域模型、混合架构、匹配算法、测试策略与演示/README 方案。达到后可以直接开始编码，不再有需要产品/技术决策才能动手的空白。执行按 P0 依赖顺序推进，不排具体日历。

## Notes

**项目背景**
- 用户已学 SwiftUI / UIKit 基础，目标是找 iOS 实习；周期约 1 个月；GitHub 作品集交付。
- 项目名 NextStep，路径 `/Users/wuyifan/repo/NextStep`；已有 Xcode 项目骨架（NextStep.xcodeproj，初始 SwiftUI 页面）。
- 无付费 Apple Developer 账号，只有免费账号：7 天签名，不能 TestFlight/上架。

**已确定的方向**
- 产品：实习申请追踪器 + 岗位发现/匹配。Tracker 管理手动添加的申请；Discover 展示 Remotive 岗位并做本地匹配。
- 数据源：Remotive 公共 API（无鉴权；每天最多 4 次刷新，超过 2 次/分钟会被封；数据延迟 24 小时；必须署名 Remotive 并回链原岗位；只覆盖全球远程岗位）+ 手动粘贴 JD。
- 技术：SwiftUI 为主，UIKit 用于局部页面；MVVM 为主，UIKit 页面用 MVC；SwiftData 持久化；Swift Testing；iOS 26/27、Xcode 27.0。
- 匹配：本地、可解释、可测试。自建技能词典（中英别名）+ 规则/加权评分；不上 NLTokenizer；不依赖 LLM。
- 免费账号能力：App Groups、Share Extension、Widgets、后台 URLSession、本地通知可用（App Group 需真机 spike 验证）；Push、iCloud/CloudKit、Sign in with Apple、Associated Domains 不可用。

**执行与交付偏好**
- 不做日历/周计划/小时级排期；时间充足，不砍 P0 功能。
- 不做视频演示；中文 README + 公开仓库 + 现场打开 App 演示。
- 简历呈现等 v1 雏形出来后再定。

**合规与边界**
- 不抓取 BOSS直聘/实习僧/牛客/拉勾/智联/前程无忧等平台；不做实时岗位聚合。
- 演示数据使用虚构公司/虚构 JD；不把真实 JD 全文复制进仓库。
- Remotive 数据必须标注来源并回链；不转投第三方招聘聚合站。
- Foundation Models 在中国区当前不可用，不作为依赖。
- URL 导入仅解析用户主动提供的公开页面，作为可选增强。

**每个 session 应参考的技能**
- grilling、domain-modeling、codebase-design、prototype、tdd、research。

## Decisions so far

- [Remotive 集成约束与数据映射](issues/07-remotive-integration.md): 可作为发现源；无鉴权、≤4 次/天、需署名回链、仅远程岗位；本地缓存 + 节流。
- [仪表盘首屏结构](issues/08-dashboard-prototype.md): 采用变体 A「行动优先」；独立概览 tab，首屏为「接下来 7 天」+ 三个进展计数 + 最近更新；空状态不放 1/2/3 步骤说明；状态分布与漏斗留 P1。
- [功能边界与 MVP 验收线](issues/01-feature-boundary.md): v1 = Application 追踪闭环 + 本地可解释匹配 + Remotive/手动发现；P0 顺序 领域→追踪器→匹配→Remotive→收尾；P1 为 URL 导入/漏斗/状态分布图；Share/Widget、云 LLM、账号/云同步等明确不做。
- [匹配算法、技能词典与解释展示](issues/02-matching-engine.md): 技能词典 + 规则加权（技能 60/方向 20/地点 10/岗位类型 10）；中英别名、无 NLTokenizer；不符合岗位展示但标 ineligible；画像 ≥3 技能才计分；解释展示采用变体 A（列表技能标签 + 详情长解释）。
- [领域模型与投递状态机](issues/03-domain-model.md): 5 个实体（Application/JobPosting/InterviewRound/StatusChange/UserProfile）；七态状态机允许跳级与回退，rejected/withdrawn 可显式重开（rejected→offer 覆盖 HR 捞回），offer 终态；OA 仅为状态、不记轮次；skills 存技能词典 canonical 名称（[String]），枚举存 raw String + computed enum，identityKey 唯一 upsert，VersionedSchema V1 + 轻量迁移；派生值不落库。
- [混合架构与 JobSource 抽象](issues/04-architecture.md): 单 target 分层 + 协议缝；MVVM 为主、两个只读 @Query 页、状态历史 UIKit/MVC；统一 JobSource + JobPostingDraft + JobRepository（滚动 24h ≤4 次、60s 间隔、缓存优先）；MatchingEngine 纯 + MatchService；4 条 ADR。
- [30 天排期、测试与演示方案](issues/06-schedule-demo.md): 不做日历/时间规划；执行按 01 的 P0 顺序，只定完成标准；测试沿用基线；不做视频，中文 README + 现场演示；面试讲匹配/JobSource/SwiftData 三个取舍；简历呈现等雏形后再定。

## Not yet specified

- 视觉与信息架构（仪表盘 08、匹配解释组件 02 已定稿）：追踪器页面、Discover 其余布局、空状态/错误状态、动效。
- 品牌细节（图标、配色、文案语气）：不影响技术决策，可最后定。
- 简历呈现与项目叙事：等 v1 雏形出来后，按实际实现决定简历 bullet、演示重点和面试叙事。

## Out of scope

- 抓取国内招聘平台或实时聚合全网岗位：无公开 API，协议禁止，合规风险高。
- 客户端直连 LLM / 依赖 Foundation Models：v1 不用；中国区当前不可用，密钥与成本不可控；未来单独评估。
- Push、iCloud/CloudKit、Sign in with Apple、Associated Domains：免费账号不支持。
- App Store 上架 / TestFlight：免费账号不支持。
- 账号/登录、云同步、多设备、社交/推荐 Feed、通用记账：超出 30 天 v1 范围。
- Share Extension / Widget：v1 不纳入，[免费账号能力 spike](issues/05-free-account-spike.md) 已关闭；未来如需要，作为独立 effort 重新评估。
- 把真实 JD 全文复制进仓库或演示数据集：著作权风险。
- 向量检索、简历生成/自动投递/自动填表、独立 Company/Skill 实体、公司主页、联系人/日历/邮件集成、简历版本管理、团队协作、CSV 导入导出、薪资分析、公司点评、自建后端/代理、生产级监控、完整 UI 测试、多语言：超出 v1 范围。
- P1（v1 后、时间允许，不进 v1 验收线）：URL 导入、漏斗转化率、状态分布图。
- 日历、周计划、小时级排期：用户明确不做；执行按 P0 顺序与完成标准推进（[30 天排期、测试与演示方案](issues/06-schedule-demo.md) 已关闭）。
- 视频演示：v1 不做；用中文 README + 现场演示替代（[30 天排期、测试与演示方案](issues/06-schedule-demo.md) 已关闭）。
- 本地音乐播放器、播客播放器等其他项目方向：已评估并放弃，当前终点是 NextStep。
