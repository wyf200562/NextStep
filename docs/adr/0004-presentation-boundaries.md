# 表现层边界：MVVM 为主，只读列表用 @Query，状态历史用 UIKit/MVC

SwiftUI 页面中，有异步加载、错误态、表单校验或多步操作的页面使用 `@Observable @MainActor` ViewModel；概览和申请列表这类只读页面直接用 SwiftData `@Query` + 纯函数派生，不强行加 VM；写操作一律走 Repository/ViewModel。唯一 UIKit 页面是申请详情的「状态历史」，用 `UIViewController` + `UITableViewDiffableDataSource` 的 MVC，由 sheet 内嵌 `UINavigationController` 承载，不设 ViewModel。这样 MVVM 仍是主形态，同时保留一个真实、低风险的 UIKit/MVC 展示点。

## Considered Options

- 每个 SwiftUI 页面都配 VM。形式统一，但只读页面会多绕一层。
- Discover 网格用 UIKit 实现。更炫，但重复主流程、风险和工作量更高。
- 申请详情整页 UIKit。风险最高，影响黄金路径。

## Consequences

- 「MVVM 为主」不是「每页都有 VM」；review 时要防止只读页面里长出业务逻辑。
- UIKit 页与 SwiftUI 只通过 `UIViewControllerRepresentable` + 注入的 repository 交互。
- 如果未来更多页面转 UIKit，需要重新评估是否仍保持单一 MVC 边界。
