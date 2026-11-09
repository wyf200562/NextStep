import Foundation

/// Whether a skill tag represents a skill the profile has or one the posting requires but lacks.
nonisolated enum SkillTagKind: Sendable, Equatable {
    case matched
    case missing
}

/// One display-ready skill tag. `id` is the dictionary skill id.
nonisolated struct SkillTag: Identifiable, Sendable, Equatable {
    let id: SkillID
    let name: String
    let kind: SkillTagKind
}

/// What an eligible Discover card shows for the current match availability.
///
/// `fallbackMessage` is set exactly when no score is shown (profile gate or unavailable matching);
/// otherwise `scoreText`, `bandText`, and `matchCountText` carry the variant-A explanation.
nonisolated struct MatchCardPresentation: Sendable, Equatable {
    let scoreText: String?
    let bandText: String?
    let matchCountText: String?
    let matchedTags: [SkillTag]
    let missingTags: [SkillTag]
    let extraMatchedCount: Int
    let extraMissingCount: Int
    let reason: String?
    let fallbackMessage: String?
    let isLowConfidence: Bool
}

/// What an ineligible Discover row shows: the reason badge, optional skill hit count, and source.
nonisolated struct IneligibleCardPresentation: Sendable, Equatable {
    let reasonText: String
    let skillCountText: String?
    let sourceText: String
}

/// Pure display rules shared by the grouped Discover cards and compact summaries.
enum MatchCardPresenter {
    static let matchedTagLimit = 3
    static let missingTagLimit = 2

    static func eligible(
        match: MatchResult?,
        availability: MatchAvailability,
        dictionary: SkillDictionary?
    ) -> MatchCardPresentation {
        guard let match else {
            return MatchCardPresentation(
                scoreText: nil,
                bandText: nil,
                matchCountText: nil,
                matchedTags: [],
                missingTags: [],
                extraMatchedCount: 0,
                extraMissingCount: 0,
                reason: nil,
                fallbackMessage: availability.fallbackMessage,
                isLowConfidence: false
            )
        }

        let scoreText = scoreText(for: match)

        return MatchCardPresentation(
            scoreText: scoreText,
            bandText: match.band?.displayName,
            matchCountText: matchCountText(for: match),
            matchedTags: limitedTags(
                match.matchedSkills,
                kind: .matched,
                limit: matchedTagLimit,
                dictionary: dictionary
            ),
            missingTags: limitedTags(
                match.missingSkills,
                kind: .missing,
                limit: missingTagLimit,
                dictionary: dictionary
            ),
            extraMatchedCount: max(0, match.matchedSkills.count - matchedTagLimit),
            extraMissingCount: max(0, match.missingSkills.count - missingTagLimit),
            reason: match.reason,
            fallbackMessage: nil,
            isLowConfidence: match.confidence == .low
        )
    }

    static func ineligible(
        job: JobPosting,
        match: MatchResult?,
        eligibility: Eligibility,
        availability: MatchAvailability
    ) -> IneligibleCardPresentation {
        let reason: IneligibilityReason?
        if case .ineligible(let storedReason) = eligibility {
            reason = storedReason
        } else {
            reason = nil
        }

        let countText: String?
        if availability == .ready, let match {
            countText = skillCountText(for: match)
        } else {
            countText = nil
        }

        return IneligibleCardPresentation(
            reasonText: reason?.displayName ?? "不符合条件",
            skillCountText: countText,
            sourceText: job.intakeMethod.displayName
        )
    }

    /// Display score, starred when confidence is low. `nil` for ineligible or unscored results.
    static func scoreText(for match: MatchResult) -> String? {
        match.score.map { score in
            match.confidence == .low ? "\(score)*" : "\(score)"
        }
    }

    /// "匹配 X/Y" where Y is the number of required (identified) skills.
    static func matchCountText(for match: MatchResult) -> String {
        let requiredCount = match.matchedSkills.count + match.missingSkills.count
        return "匹配 \(match.matchedSkills.count)/\(requiredCount)"
    }

    /// "技能匹配 X/Y" for ineligible rows; required skills are matched plus missing.
    static func skillCountText(for match: MatchResult) -> String {
        let requiredCount = match.matchedSkills.count + match.missingSkills.count
        return "技能匹配 \(match.matchedSkills.count)/\(requiredCount)"
    }

    /// Display names for every skill id (no limit), used by the detail screen and app summaries.
    static func tags(
        for skillIDs: [SkillID],
        kind: SkillTagKind,
        dictionary: SkillDictionary?
    ) -> [SkillTag] {
        skillIDs.map { skillID in
            SkillTag(
                id: skillID,
                name: dictionary?.skill(id: skillID)?.name ?? skillID,
                kind: kind
            )
        }
    }

    private static func limitedTags(
        _ skillIDs: [SkillID],
        kind: SkillTagKind,
        limit: Int,
        dictionary: SkillDictionary?
    ) -> [SkillTag] {
        tags(for: Array(skillIDs.prefix(limit)), kind: kind, dictionary: dictionary)
    }
}
