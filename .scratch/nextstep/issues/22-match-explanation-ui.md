# 22: 匹配解释展示

**What to build:** 浏览岗位时把 MatchResult 变成可读解释。Discover 列表按 eligibility 分组：「适合你」为 eligible 岗位，按 score 降序、同分按 matchedSkills.count、publishedAt（nil 最后）、identityKey；卡片含分数 pill（低置信度带 `*`）、band、「匹配 X/Y」、前 3 个匹配技能标签、前 2 个缺失技能标签 +N、一句原因（最多两行）。「不符合条件 · N 条」为 ineligible 岗位，按 createdAt 降序、identityKey 兜底，默认显示前 4 条可展开，每行「不符合」徽标 + 原因 + 技能命中数，不显示 0 分；分组按 eligibility 不按来源。画像不足或词典不可用时仍按 eligibility 分组：eligible 组不显示分数，显示「完善画像后查看匹配」或「匹配暂不可用」，按 publishedAt 降序、identityKey；ineligible 组仍显示原因，画像不足时不显示技能命中数。岗位详情：eligible 显示分数 hero、band、低置信度 `*`、匹配 / 缺失技能标签、四项分项条、一句话原因、JD 绿 / 红高亮；ineligible 显示危险 banner + 原因 + 技能匹配，不显示分数 hero 和分项条；低置信度显示 banner；画像不足显示 gate + 两个条件 +「去完善画像」；词典不可用显示提示。申请详情在关联岗位下现算紧凑匹配摘要，画像不足时隐藏并提示。所有 MatchResult 现算，不持久化。

**Blocked by:** 18（匹配核心）、19（用户画像页）、21（岗位详情与导入申请）

**Status:** ready-for-agent

- [ ] Discover 分组、排序、卡片信息、展开与来源标记符合 spec；eligible / ineligible 不混排。
- [ ] 画像不足与词典不可用两种降级状态正确；「只看实习」只影响显示，不改变匹配与排序。
- [ ] JobDetail 四种匹配状态（gate / eligible / ineligible / 词典不可用）与低置信度展示正确。
- [ ] JD 高亮非重叠、最长优先，matched 绿 / missing 红，不持久化。
- [ ] 申请详情紧凑匹配摘要现算；画像不足时隐藏并提示。
- [ ] 「适合你」为空时显示内联空状态 + 粘贴 JD，ineligible 分组保留。
- [ ] 单测：分组 / 排序规则、gate、低置信度、ineligible 展示条件。
