# 单 app target + 分层目录，不拆 SPM 模块

NextStep v1 只保留一个 app target，代码按 `App / Features / Domain / Data / Core` 目录分层，依赖方向为 Features → Domain ← Data，跨层依赖通过协议在组合根注入。没有拆成本地 SPM 包：在 30 天、约 100 小时的预算里，包配置、资源加载和 Preview 的成本高于编译器强制边界带来的收益；目录、协议和 review 已经能表达架构，未来要抽包时 `Domain/` 可以原样搬走。

## Considered Options

- 单 target + 一个 `NextStepCore` 本地包（只放 Domain/Matching）。
- 多包全模块化。

两者都因构建与维护成本被推迟，不是被否定；如果项目继续演进，优先抽 `Domain/`。

## Consequences

- 层间边界靠约定而非编译器；review 时检查 import 方向。
- 单测 target `NextStepTests` 通过 `@testable import NextStep` 访问 internal 类型。
- 新增文件放进对应目录即可，不需要改包清单。
