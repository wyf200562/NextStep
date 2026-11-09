# 12: 工程脚手架与领域模型

**What to build:** 一个可启动的 4-tab 应用外壳（概览、申请、发现、我的），每个 tab 有独立 NavigationStack、中文标题和占位页；AppRouter 只负责选中 tab 与待处理路由。工程具备 Swift Testing 单测 target、Swift 6 语言模式、App / Features / Domain / Data / Core 分层与 AppContainer 组合根。5 个领域模型（Application、JobPosting、InterviewRound、StatusChange、UserProfile）及全部枚举进入 VersionedSchema V1，关系、删除规则与唯一约束按规格落定，内存容器可创建并读写。ModelContainer 创建失败时显示阻塞式「本地数据无法打开」错误页 + 重试。LoadState、DateProvider、按层分类的 os.Logger 就位。所有后续切片建立在这张票上。

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] 模拟器启动后可在 4 个 tab 间切换；每 tab 独立导航栈、中文占位标题；根容器/路由无 ViewModel。
- [x] NextStepTests 使用 Swift Testing 可运行；包含 schema 往返与 in-memory 容器测试。
- [x] SWIFT_VERSION = 6.0，保留 MainActor 默认隔离；测试/Preview 使用 isStoredInMemoryOnly。
- [x] 5 个 `@Model` 的字段、枚举 raw value、inverse、cascade/nullify、JobIdentityKey 唯一约束符合 spec 第 2 节；派生值不落库。
- [x] VersionedSchema V1 与 SchemaMigrationPlan 骨架；主线程单 ModelContext；repository 协议空壳可注入。
- [x] AppContainer 通过 environment 注入；LoadState、可注入的 DateProvider、os.Logger 分类（app/data/matching/ui）就位。
- [x] ModelContainer 创建失败显示阻塞错误页并可重试。
- [x] 依赖方向：Domain 不 import SwiftUI；无第三方依赖。

## Answer

日期：2026-11-09。实现 commit：`bf4c361`（`ticket/12-scaffold-domain-models`，基于 integration/nextstep-v1 `2acdc90`）。

### 交付内容

- **App 外壳**：4 个 tab（概览 / 申请 / 发现 / 我的），每个 tab 独立 `NavigationStack` + 独立 typed route（`OverviewRoute` / `ApplicationsRoute` / `DiscoverRoute` / `ProfileRoute`），中文占位页；`AppRouter`（`@Observable @MainActor`）只持有选中 tab 与单条 pending cross-tab route，已建模 openApplication、openApplications(filter:)、openDiscover、openProfile；各 tab 通过 `takePendingRoute(for:)` 消费属于自己的路由。根容器与路由均无 ViewModel。模拟器启动截图确认 4 个 tab 与概览占位页正常显示。
- **工程**：按已验证 recipe 应用 `project.pbxproj` patch（SHA-256 `afffacf3d7711b5adb34b4262728d9a43097d1078403cb9ebd40e20596552f3f`），新增 `NextStepTests` Swift Testing target 与 shared scheme；app 与 tests 均 `SWIFT_VERSION = 6.0`、`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`。未添加任何 per-file PBX 条目。
- **领域模型**：5 个 `@Model final class`（Application、JobPosting、InterviewRound、StatusChange、UserProfile），显式 `UUID` id；枚举统一 raw String 存储 + computed enum + 中文 displayName；Application → InterviewRound/StatusChange cascade，JobPosting → Application nullify；所有关系显式 inverse；`JobPosting.identityKey` 为 `@Attribute(.unique)`；不存 appliedAt/fetchedAt/MatchResult 等派生值；`SchemaV1`（1.0.0）与空 `SchemaMigrationPlan` 骨架就位。
- **持久化与组合根**：`ModelContainerFactory` 支持 `isStoredInMemoryOnly`；`AppContainer` 持有唯一的 `modelContainer.mainContext`、repositories、`DateProvider`、`AppRouter`，并预留 `jobSourceFactory` / `matchProvider` 槽位，通过 `.environment` 注入。容器创建失败显示阻塞式「本地数据无法打开」页 +「重试」。
- **Core**：`LoadState<Value>`（idle/loading/loaded/failed）、`DateProvider` + `SystemDateProvider` + `FixedDateProvider`、`AppLogger`（app/data/matching/ui 四个 `os.Logger` category）。
- **协议缝**：`ApplicationRepository`、`UserProfileRepository`、`JobRepository`、`JobSource`、`JobSourceFactory`、`MatchProviding`，以及 `JobPostingDraft` / `JobQuery` / `ManualJobInput` / `JobSourceError` / `RefreshOutcome`。`SwiftDataUserProfileRepository` 已完整实现 fetch-or-create 单例与保存；`UnavailableApplicationRepository` / `UnavailableJobRepository` 是显式 typed 占位（抛 `RepositoryError.unavailable`，不崩溃），由 13/14/16/20/23 替换。

### 关键文件

- `NextStep/App/`：`NextStepApp`、`AppRootView`（启动/错误页）、`RootTabView`、`AppRouter`、`AppTab`、`AppContainer`
- `NextStep/Domain/Models/`：5 个 `@Model`；`NextStep/Domain/`：`ApplicationStatus`、`JobIntakeMethod`、`InterviewEnums`、`JobIdentityKey`
- `NextStep/Domain/Jobs/`、`NextStep/Domain/Matching/`、`NextStep/Domain/Repositories/`
- `NextStep/Data/Persistence/`：`SchemaV1`、`NextStepMigrationPlan`、`ModelContainerFactory`
- `NextStep/Data/Repositories/`：`SwiftDataUserProfileRepository`、typed 占位 repositories
- `NextStep/Features/`：每个 tab 的 TabView / 占位页 / typed route
- `NextStepTests/`：`Domain/`、`Data/`、`Core/`、`App/` 共 9 个测试文件（31 个 Swift Testing 用例）

### 验证

```bash
xcodebuild -project NextStep.xcodeproj -scheme NextStep \
  -destination 'platform=iOS Simulator,id=430CDEBB-8ABA-4F35-A1D3-954C3E39EC81' test
```

结果：exit 0，`** TEST SUCCEEDED **`，31 个测试全部通过（schema 往返、in-memory 容器、identityKey 唯一性、cascade/nullify、UserProfile fetch-or-create、AppRouter、AppContainer 注入、enums/DateProvider/LoadState、JobSource seam）。`Integration` 合并为 no-op（integration/nextstep-v1 仍在 `2acdc90`）。

### 决策与说明

- `MatchProviding` 需要返回类型，因此本票提前声明了 spec §6 的 `MatchResult` 及配套值类型（`MatchBand`/`MatchComponents`/`Eligibility`/`Confidence`/`SkillEvidence`/`SkillID`）；`MatchingEngine`/`MatchService` 仍由 ticket 18 实现。
- `JobPosting.tags` 与 `UserProfile.preferredLocations` 以非可选空数组落库（spec 标为可选数组），标量可选性保持不变；空数组等价于“无值”，避免 SwiftData 可选数组的额外分支。
- 申请列表筛选是申请 tab 根视图的 `@State`（`ApplicationListFilter`），cross-tab `.applicationsList(filter:)` 只设置根筛选并回到根，不额外 push 一层列表。
- `ApplicationRepository`/`JobRepository` 的实现是显式 typed 空壳，符合本票“协议空壳可注入”；`UserProfileRepository` 因 fetch-or-create 便宜且 ticket 18 依赖，直接实现并测试。
- 未新增格式化/设计 token 文件：当前占位 UI 没有消费者，等 13/17 的 UI 切片再按需加入。

