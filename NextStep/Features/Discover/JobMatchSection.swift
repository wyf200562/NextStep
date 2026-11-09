import SwiftUI

/// The job detail match region, inserted between the header and the JD.
///
/// Variant A: four states — profile gate, eligible (score hero), ineligible (danger banner only),
/// and matching unavailable. Everything here is derived from the injected match provider; nothing
/// is persisted.
struct JobMatchSection: View {
    let availability: MatchAvailability
    let match: MatchResult?
    let skillDictionary: SkillDictionary?
    let onOpenProfile: () -> Void

    @ViewBuilder
    var body: some View {
        switch availability {
        case .profileIncomplete:
            ProfileGateCard(onOpenProfile: onOpenProfile)
        case .unavailable:
            MatchUnavailableCard()
        case .ready:
            if let match {
                VStack(alignment: .leading, spacing: 10) {
                    if case .ineligible(let reason) = match.eligibility {
                        IneligibleMatchCard(
                            match: match,
                            reason: reason,
                            skillDictionary: skillDictionary
                        )
                    } else {
                        EligibleMatchCard(match: match, skillDictionary: skillDictionary)
                    }

                    if match.confidence == .low {
                        LowConfidenceBanner()
                    }
                }
            } else {
                MatchUnavailableCard()
            }
        }
    }
}

// MARK: - Eligible

private struct EligibleMatchCard: View {
    let match: MatchResult
    let skillDictionary: SkillDictionary?

    private var matchedTags: [SkillTag] {
        MatchCardPresenter.tags(
            for: match.matchedSkills,
            kind: .matched,
            dictionary: skillDictionary
        )
    }

    private var missingTags: [SkillTag] {
        MatchCardPresenter.tags(
            for: match.missingSkills,
            kind: .missing,
            dictionary: skillDictionary
        )
    }

    var body: some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 14) {
                MatchScoreHero(match: match)

                Divider()

                SkillTagGroup(
                    title: "匹配了哪些",
                    tags: matchedTags,
                    emptyText: "没有命中项"
                )
                SkillTagGroup(
                    title: "缺少哪些",
                    tags: missingTags,
                    emptyText: "没有缺失项"
                )

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("分数怎么来的")
                        .font(.subheadline.weight(.semibold))
                    MatchComponentBars(components: match.components)
                    Text("总分 = 技能 + 方向 + 地点 + 岗位类型；满分 100。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Ineligible

private struct IneligibleMatchCard: View {
    let match: MatchResult
    let reason: IneligibilityReason
    let skillDictionary: SkillDictionary?

    private var matchedTags: [SkillTag] {
        MatchCardPresenter.tags(
            for: match.matchedSkills,
            kind: .matched,
            dictionary: skillDictionary
        )
    }

    private var missingTags: [SkillTag] {
        MatchCardPresenter.tags(
            for: match.missingSkills,
            kind: .missing,
            dictionary: skillDictionary
        )
    }

    var body: some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("岗位不符合")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.red)
                        Text(match.reason)
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("仍展示、不隐藏；不计算总分。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.red.opacity(0.08))
                )

                Text(MatchCardPresenter.skillCountText(for: match))
                    .font(.subheadline.weight(.semibold))

                SkillTagGroup(
                    title: "匹配了哪些",
                    tags: matchedTags,
                    emptyText: "没有命中项"
                )
                SkillTagGroup(
                    title: "缺少哪些",
                    tags: missingTags,
                    emptyText: "没有缺失项"
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("岗位不符合：\(reason.displayName)")
    }
}

// MARK: - Banners and gates

private struct LowConfidenceBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("低置信度")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.orange)
                Text("描述为空或未识别到技能，分数仅供参考。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.09))
        )
    }
}

private struct ProfileGateCard: View {
    let onOpenProfile: () -> Void

    var body: some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    Text("画像还差一点")
                        .font(.headline)
                }

                Text("至少填写目标方向和 3 个技能后显示匹配分。岗位信息仍然可以先看。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 7) {
                    Text("还需要满足")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    condition("目标方向：至少 1 个")
                    condition("技能：至少 3 个")
                }

                Button(action: onOpenProfile) {
                    Text("去完善画像")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color.accentColor)
                        )
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func condition(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.dashed")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
        }
    }
}

private struct MatchUnavailableCard: View {
    var body: some View {
        DetailCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles.slash")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("匹配暂不可用")
                        .font(.subheadline.weight(.semibold))
                    Text("岗位仍可浏览、导入。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Tags

private struct SkillTagGroup: View {
    let title: String
    let tags: [SkillTag]
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            if tags.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                TagFlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(tags) { tag in
                        SkillTagView(tag: tag)
                    }
                }
            }
        }
    }
}
