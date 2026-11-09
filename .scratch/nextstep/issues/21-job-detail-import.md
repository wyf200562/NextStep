# 21: 岗位详情与导入申请

**What to build:** 点击 Discover 岗位卡片进入岗位详情，展示标题、公司、地点、岗位类型、标签、发布日期、薪资、来源徽标、JD 纯文本、来源与回链（有链接时）。底部导入 CTA：进入页面时按 JobPosting 查已有 Application——有非终态（wishlist / applied / oa / interview）显示「已有进行中的申请」+「查看」，点击切到申请 tab 并打开已有详情，不创建重复记录；只有终态（offer / rejected / withdrawn）显示「再次导入为申请」，确认后新建；无记录显示「导入为申请」。新建时快照公司 / 职位 / 链接 / 地点，初始 wishlist，关联 JobPosting，写初始 StatusChange；成功后切到申请 tab 并 push 新详情。申请详情显示关联岗位摘要（标题、公司、来源、原岗位链接），匹配摘要留到 22。手动粘贴 JD 保存成功后 push 同一详情页。

**Blocked by:** 14（申请详情与状态流转）、20（岗位摄入与手动粘贴 JD）

**Status:** ready-for-agent

- [ ] Discover 卡片可进入 JobDetail；手动粘贴保存后 push 同一详情。
- [ ] 详情字段、JD 纯文本、来源徽标与回链符合 spec 第 9 节。
- [ ] 导入三种状态与去重逻辑正确；终态确认后新建。
- [ ] 导入创建快照、关联、初始 StatusChange；成功后路由到新详情；已有申请路由到已有详情。
- [ ] 申请详情显示关联岗位摘要；JobPosting 不存在时快照仍正常显示。
- [ ] JobDetailViewModel 单测：三种导入状态、快照与关联、去重。
