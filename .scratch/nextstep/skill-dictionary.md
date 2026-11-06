# 技能词典初稿（ticket 02）

> 状态：规划初稿，用于 review 覆盖范围；实现时转成 App 内的 JSON/plist 资源。
> 原则：约 50 条核心 + 可选扩展；每条含中英文别名；只收可验证的技能，不收软技能。

## 数据结构

每条 canonical skill：

```json
{
  "id": "swiftui",
  "name": "SwiftUI",
  "aliases": ["swiftui", "swift ui", "声明式ui"],
  "category": "ui"
}
```

实现约定：

- `id` 用 kebab-case，稳定不改；改名只改 `name` / `aliases`。
- 别名统一小写；匹配前做 NFKC、大小写、全半角、HTML 和标点归一化。
- 英文别名用词边界匹配（避免 `Swift` 命中 `SwiftUI`）；中文别名用最长子串匹配。
- 不收录 1–2 个字母的歧义别名（`go`、`js`、`os`、`rn`、`fp`、`c`）；`C++` 可以。
- `OC` 只按独立 token 匹配，避免误伤英文单词。
- v1 不做 `parents` / 技能蕴含（如 SwiftUI ⇒ Swift）；P1 再评估。
- 不收软技能（沟通、团队协作、学习能力等）。

## 核心技能（50 条）

| 分类 | id | 名称 | 别名（英文 / 中文） |
|---|---|---|---|
| 语言 | `swift` | Swift | swift, swift语言 |
| 语言 | `objective-c` | Objective-C | objective-c, objective c, objc, obj-c, oc |
| UI | `swiftui` | SwiftUI | swiftui, swift ui, 声明式ui |
| UI | `uikit` | UIKit | uikit, ui kit |
| UI | `autolayout` | Auto Layout | autolayout, auto layout, 自动布局, 约束布局 |
| UI | `core-animation` | Core Animation | core animation, coreanimation, 核心动画 |
| UI | `storyboard` | Storyboard / XIB | storyboard, story board, xib, nib |
| 架构 | `mvvm` | MVVM | mvvm, model-view-viewmodel |
| 架构 | `mvc` | MVC | mvc, model-view-controller |
| 架构 | `design-patterns` | 设计模式 | design pattern, design patterns, 设计模式 |
| 架构 | `modularization` | 模块化 | modularization, modularisation, 模块化, 组件化 |
| 数据 | `swiftdata` | SwiftData | swiftdata, swift data |
| 数据 | `core-data` | Core Data | core data, coredata, core-data |
| 数据 | `sqlite` | SQLite | sqlite, sqlite3 |
| 数据 | `userdefaults` | UserDefaults | userdefaults, user defaults, nsuserdefaults |
| 数据 | `codable` | Codable | codable, json编解码 |
| 并发 | `async-await` | async/await | async/await, async await, async-await, 结构化并发 |
| 并发 | `gcd` | GCD | gcd, grand central dispatch, dispatch queue |
| 并发 | `combine` | Combine | combine, combine框架 |
| 并发 | `rxswift` | RxSwift | rxswift, rx swift, reactivecocoa |
| 网络 | `urlsession` | URLSession | urlsession, url session, nsurlsession |
| 网络 | `rest` | REST | rest, restful, rest api, restful api |
| 网络 | `http` | HTTP | http, https, http/2 |
| 网络 | `websocket` | WebSocket | websocket, web socket |
| 网络 | `json` | JSON | json, json解析 |
| 测试 | `xctest` | XCTest | xctest, xc test, 单元测试, unit test |
| 测试 | `ui-testing` | UI Testing | ui testing, xcuitest, uitest, ui测试 |
| 测试 | `tdd` | TDD | tdd, test-driven, 测试驱动 |
| 工具 | `xcode` | Xcode | xcode |
| 工具 | `git` | Git | git, github, gitlab, 版本控制 |
| 工具 | `ci-cd` | CI/CD | ci/cd, cicd, continuous integration, 持续集成, 持续交付, github actions, jenkins |
| 工具 | `fastlane` | Fastlane | fastlane |
| 工具 | `cocoapods` | CocoaPods | cocoapods, cocoa pods, podfile |
| 工具 | `spm` | Swift Package Manager | swift package manager, spm, swiftpm |
| 工具 | `instruments` | Instruments | instruments, xcode instruments |
| 工具 | `lldb` | LLDB | lldb, 调试器, debugger |
| 工具 | `swiftlint` | SwiftLint | swiftlint, lint, 代码规范 |
| CS | `data-structures` | 数据结构 | data structure, data structures, 数据结构, dsa |
| CS | `algorithms` | 算法 | algorithm, algorithms, 算法, leetcode |
| CS | `operating-systems` | 操作系统 | operating system, operating systems, 操作系统 |
| CS | `computer-networks` | 计算机网络 | computer network, computer networks, 计算机网络, tcp/ip |
| CS | `database` | 数据库 / SQL | database, databases, 数据库, sql, mysql, postgresql |
| CS | `oop` | 面向对象 | oop, object-oriented, object oriented, 面向对象 |
| CS | `memory-management` | 内存管理 | memory management, 内存管理, arc, 引用计数 |
| CS | `performance-optimization` | 性能优化 | performance optimization, performance tuning, 性能优化, 性能调优, 启动优化 |
| CS | `debugging` | 调试 | debugging, debug, 调试, 排错 |
| 平台 | `app-store` | App Store / TestFlight | app store, testflight, app store connect, 上架 |
| 平台 | `push-notifications` | 推送通知 | push notification, push notifications, apns, 远程推送, 本地通知 |
| 平台 | `storekit` | StoreKit | storekit, store kit, 内购, iap |
| 平台 | `cloudkit` | CloudKit | cloudkit, cloud kit |

## 可选扩展（15 条，时间允许再加）

| 分类 | id | 名称 | 别名（英文 / 中文） |
|---|---|---|---|
| UI | `widgetkit` | WidgetKit | widgetkit, widget kit, 小组件 |
| 平台 | `core-location` | Core Location | core location, corelocation, 定位 |
| 平台 | `mapkit` | MapKit | mapkit, map kit, 地图 |
| 平台 | `avfoundation` | AVFoundation | avfoundation, av foundation, 音视频 |
| 网络 | `graphql` | GraphQL | graphql |
| 工具 | `firebase` | Firebase | firebase, firestore |
| 工具 | `alamofire` | Alamofire | alamofire |
| 工具 | `kingfisher` | Kingfisher | kingfisher |
| 工具 | `snapkit` | SnapKit | snapkit |
| 相邻 | `python` | Python | python |
| 相邻 | `javascript` | JavaScript / TypeScript | javascript, typescript |
| 相邻 | `flutter` | Flutter | flutter, dart |
| 相邻 | `react-native` | React Native | react native, react-native |
| 相邻 | `kotlin` | Kotlin | kotlin |
| 相邻 | `cpp` | C++ | c++, cpp |
