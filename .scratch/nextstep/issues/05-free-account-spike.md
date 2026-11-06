# 免费账号能力 spike：App Group / Share Extension / Widget

Type: task
Mode: HITL
Status: resolved
Blocked by:

## Question

免费 Apple Developer 账号下，NextStep 需要的扩展能力是否真的可用？需要在真机上做最小验证：

- 主 App + Share Extension 两个 target，同一个 App Group（例如 `group.<bundleid>`），自动签名，真机运行。
- 主 App 写入 App Group，Share Extension 读取；反向再验证一次。
- 最小 Widget 读取 App Group 数据并显示。
- 记录：签名是否成功、7 天有效期的影响、失败时的降级方案（App 内粘贴 / 静态 Widget）。

输出：一份 spike 结果，决定 Share Extension / Widget 是进 v1、放拓展，还是出局。

## Answer

未执行 spike。v1 决定不纳入 Share Extension / Widget（见 [功能边界与 MVP 验收线](01-feature-boundary.md)），本 ticket 作为 v1 路线外的工作关闭；扩展能力保持未验证状态。未来若要作为加分项，重新开独立 effort，先做本 spike。
