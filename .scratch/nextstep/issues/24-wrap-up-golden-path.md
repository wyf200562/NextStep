# 24: 收尾与黄金路径验收

**What to build:** 交付可重复演示的 v1。Debug 构建提供「清空演示数据」，删除全部 SwiftData 记录（Application、JobPosting、InterviewRound、StatusChange、UserProfile）并清空 RefreshLedger，回到首次启动状态；Release 不包含入口。中文 README 覆盖项目简介、功能、技术栈、架构分层、三个关键取舍、运行方式（Xcode 27 / 模拟器 / 免费账号说明）、测试命令、Remotive 数据来源与合规声明、已知限制与 P1 Roadmap、设计文档链接。补齐 `docs/design/`、MIT License，巡检全局中文文案与空 / 错状态，按黄金路径手动验收。

**Blocked by:** 17（概览）、23（Remotive 来源与刷新闭环）

**Status:** ready-for-agent

- [ ] Debug 清空演示数据可用（含 RefreshLedger），Release 不含入口。
- [ ] README 结构与内容符合 spec；不复制真实 JD 全文；含 Remotive 署名 / 回链 / 合规与已知限制。
- [ ] `docs/design/`、MIT License 就位；对外材料不依赖 `.scratch/` 原始记录。
- [ ] 全局中文文案、空状态、错误提示巡检；无 print；无第三方依赖。
- [ ] 黄金路径手动走通：空状态 → Discover（真实样本或缓存兜底）→ 岗位详情匹配解释 → 导入 → 状态流转 / Deadline / 面试 → 概览事件 → 重启数据仍在。
- [ ] 断网时用缓存 + 粘贴虚构 iOS 实习 JD 仍能完成流程；测试全绿。
