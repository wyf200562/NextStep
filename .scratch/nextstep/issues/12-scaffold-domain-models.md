# 12: 工程脚手架与领域模型

**What to build:** 一个可启动的 4-tab 应用外壳（概览、申请、发现、我的），每个 tab 有独立 NavigationStack、中文标题和占位页；AppRouter 只负责选中 tab 与待处理路由。工程具备 Swift Testing 单测 target、Swift 6 语言模式、App / Features / Domain / Data / Core 分层与 AppContainer 组合根。5 个领域模型（Application、JobPosting、InterviewRound、StatusChange、UserProfile）及全部枚举进入 VersionedSchema V1，关系、删除规则与唯一约束按规格落定，内存容器可创建并读写。ModelContainer 创建失败时显示阻塞式「本地数据无法打开」错误页 + 重试。LoadState、DateProvider、按层分类的 os.Logger 就位。所有后续切片建立在这张票上。

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] 模拟器启动后可在 4 个 tab 间切换；每 tab 独立导航栈、中文占位标题；根容器/路由无 ViewModel。
- [ ] NextStepTests 使用 Swift Testing 可运行；包含 schema 往返与 in-memory 容器测试。
- [ ] SWIFT_VERSION = 6.0，保留 MainActor 默认隔离；测试/Preview 使用 isStoredInMemoryOnly。
- [ ] 5 个 `@Model` 的字段、枚举 raw value、inverse、cascade/nullify、JobIdentityKey 唯一约束符合 spec 第 2 节；派生值不落库。
- [ ] VersionedSchema V1 与 SchemaMigrationPlan 骨架；主线程单 ModelContext；repository 协议空壳可注入。
- [ ] AppContainer 通过 environment 注入；LoadState、可注入的 DateProvider、os.Logger 分类（app/data/matching/ui）就位。
- [ ] ModelContainer 创建失败显示阻塞错误页并可重试。
- [ ] 依赖方向：Domain 不 import SwiftUI；无第三方依赖。
