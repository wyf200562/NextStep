# 20: 岗位摄入与手动粘贴 JD

**What to build:** Discover tab 展示本机缓存的手动导入岗位，并提供常驻「粘贴一份 JD」入口。粘贴表单字段：岗位标题、公司、JD 正文（多行）、地点、岗位链接、岗位类型（实习 / 全职 / 合同 / 自由职业 / 兼职 / 未知）、标签（逗号分隔）；未手动选类型且标题含 intern / 实习时保存为 internship；标签 trim / 去空 / 去重；必填为空或 URL 非法时内联报错；保存中禁用按钮，失败保留表单内容并显示中文错误。保存走统一的 JobSource → JobPostingDraft → JobRepository 摄入缝：ManualJobSource 生成 `manual:<uuid>` identityKey，校验失败抛 `.invalidInput`，不消耗 Remotive 配额；JobRepository 是唯一写入口，按 identityKey upsert，cachedJobs 按 createdAt 降序、同时间用 id 兜底，不删除旧岗位。Discover 显示常驻样本头图（本机手动导入 K 条；Remotive 的 N / M 暂为 0）、虚线粘贴卡片、只看实习开关（纯 UI 过滤）、缓存岗位列表与空状态。本票不包含岗位详情与匹配展示（21、22）。

**Blocked by:** 12（工程脚手架与领域模型）

**Status:** ready-for-agent

- [ ] JobSource / JobPostingDraft / JobQuery / JobSourceFactory 协议就位；ManualJobSource 校验、identityKey、async throws；手动导入不耗配额、不写 RefreshLedger。
- [ ] 表单字段、intern 推断、标签处理、内联错误、保存中禁用、失败保留内容。
- [ ] JobRepository 的 importManual / cachedJobs / upsert 正确；identityKey 去重；排序正确；重启后仍在。
- [ ] Discover 样本头图、粘贴入口、缓存列表、只看实习过滤、空状态。
- [ ] 保存成功返回 Discover 并立即看到新岗位。
- [ ] 单测：ManualJobSource 校验 / identityKey / 配额；JobRepository upsert / 排序。
