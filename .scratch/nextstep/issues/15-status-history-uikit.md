# 15: 状态历史 UIKit 页

**What to build:** 申请详情的「状态历史」入口打开 sheet，内部由 UINavigationController 承载唯一的 UIKit/MVC 页面，无 ViewModel。页面用 UITableViewDiffableDataSource 展示该申请的 StatusChange：按 changedAt 降序、同时间用 id 兜底；row 显示 from → to、时间、备注；初始记录显示「创建 → X」；状态名用中文。空状态「还没有状态记录」、加载失败「加载失败」+ 重试、导航栏 Done 关闭。状态变化后重新打开会重新拉取。

**Blocked by:** 14（申请详情与状态流转）

**Status:** ready-for-agent

- [ ] 详情页入口打开 sheet；sheet 内嵌 UINavigationController 与 StatusHistoryViewController。
- [ ] diffable data source 排序正确；格式化逻辑为纯 helper；cell 只负责展示。
- [ ] 初始记录、普通记录、备注、中文状态名正确。
- [ ] 空状态 / 错误重试 / Done 行为正确；页面无 ViewModel。
- [ ] ApplicationRepository 提供按 application 读取 StatusChange 的能力，页面通过注入的 repository 访问，不直接碰 ModelContext。
