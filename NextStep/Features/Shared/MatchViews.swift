import SwiftUI

// MARK: - Skill tags

/// One matched (green) or missing (red) skill tag.
struct SkillTagView: View {
    let tag: SkillTag

    private var tint: Color {
        switch tag.kind {
        case .matched: .green
        case .missing: .red
        }
    }

    var body: some View {
        Text(tag.name)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.14)))
            .foregroundStyle(tint)
            .accessibilityLabel("\(tag.name)，\(tag.kind == .matched ? "已匹配" : "缺失")")
    }
}

/// Wrapping skill tags plus the compact card's "+N" overflow markers.
struct MatchSkillTagFlow: View {
    let tags: [SkillTag]
    var extraMatchedCount = 0
    var extraMissingCount = 0

    var body: some View {
        TagFlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(tags) { tag in
                SkillTagView(tag: tag)
            }
            if extraMatchedCount > 0 {
                overflowTag("+\(extraMatchedCount)")
            }
            if extraMissingCount > 0 {
                overflowTag("+\(extraMissingCount) 缺")
            }
        }
    }

    private func overflowTag(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
    }
}

// MARK: - Score

extension MatchBand {
    var tint: Color {
        switch self {
        case .strong: .green
        case .medium: .orange
        case .low: .red
        }
    }
}

/// The small score capsule used by cards and compact summaries.
struct MatchScorePill: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.15)))
            .foregroundStyle(tint)
            .accessibilityLabel("匹配分 \(text)")
    }
}

/// The large detail-screen hero: score out of 100, band, confidence and match count.
struct MatchScoreHero: View {
    let match: MatchResult

    private var band: MatchBand? { match.band }
    private var tint: Color { band?.tint ?? .secondary }
    private var scoreText: String { MatchCardPresenter.scoreText(for: match) ?? "—" }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(scoreText)
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                    Text("/100")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    if let band {
                        Text(band.displayName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(band.tint)
                    }
                    if match.confidence == .low {
                        Text("低置信度")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange.opacity(0.15)))
                            .foregroundStyle(Color.orange)
                    }
                }
                Text(MatchCardPresenter.matchCountText(for: match))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(match.reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Four component bars: 技能 60 / 方向 20 / 地点 10 / 岗位类型 10.
struct MatchComponentBars: View {
    let components: MatchComponents

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row("技能", value: components.skills, maximum: 60)
            row("方向", value: components.direction, maximum: 20)
            row("地点", value: components.location, maximum: 10)
            row("岗位类型", value: components.jobType, maximum: 10)
        }
        .accessibilityElement(children: .contain)
    }

    private func row(_ label: String, value: Int, maximum: Int) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            ProgressView(value: Double(value), total: Double(maximum))
                .tint(value == 0 ? Color.secondary : Color.accentColor)
            Text("\(value)/\(maximum)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value) / \(maximum)")
    }
}

// MARK: - JD highlighting

/// Renders plain JD text with matched skills green and missing skills red.
struct JDHighlightedText: View {
    let segments: [JDHighlightSegment]

    private var attributedText: AttributedString {
        var result = AttributedString()
        for segment in segments {
            var piece = AttributedString(segment.text)
            switch segment.kind {
            case .matched:
                piece.foregroundColor = .green
                piece.backgroundColor = Color.green.opacity(0.13)
            case .missing:
                piece.foregroundColor = .red
                piece.backgroundColor = Color.red.opacity(0.11)
            case nil:
                break
            }
            result.append(piece)
        }
        return result
    }

    var body: some View {
        Text(attributedText)
            .font(.body)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Compact application summary

/// Compact match summary under an application's associated posting (recomputed, never persisted).
struct CompactMatchSummary: View {
    let match: MatchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if case .ineligible(let reason) = match.eligibility {
                HStack(spacing: 8) {
                    MatchScorePill(text: "不符合", tint: .secondary)
                    Text(reason.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.red)
                }
            } else {
                HStack(spacing: 8) {
                    MatchScorePill(
                        text: MatchCardPresenter.scoreText(for: match) ?? "—",
                        tint: match.band?.tint ?? .secondary
                    )
                    if let band = match.band {
                        Text(band.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(band.tint)
                    }
                    Text(MatchCardPresenter.matchCountText(for: match))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(match.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }
}
