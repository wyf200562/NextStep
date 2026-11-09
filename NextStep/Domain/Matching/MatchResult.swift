import Foundation

/// A skill dictionary id.
typealias SkillID = String

/// Score band derived from the 0–100 total.
nonisolated enum MatchBand: String, CaseIterable, Sendable {
    case strong = "strong"
    case medium = "medium"
    case low = "low"

    var displayName: String {
        switch self {
        case .strong: "强匹配"
        case .medium: "可尝试"
        case .low: "低匹配"
        }
    }
}

/// Explainability confidence. Empty descriptions or zero identified skills produce `.low`.
nonisolated enum Confidence: String, CaseIterable, Sendable {
    case high = "high"
    case low = "low"

    var displayName: String {
        switch self {
        case .high: "高"
        case .low: "低"
        }
    }
}

/// The four scoring components. `total` is derived and never persisted.
nonisolated struct MatchComponents: Sendable, Equatable {
    let skills: Int
    let direction: Int
    let location: Int
    let jobType: Int

    var total: Int { skills + direction + location + jobType }
}

/// Why a posting cannot be scored. Ineligible postings have no total score.
nonisolated enum IneligibilityReason: Sendable, Equatable {
    case notInternship
    case locationMismatch

    var displayName: String {
        switch self {
        case .notInternship: "非实习"
        case .locationMismatch: "地点不符"
        }
    }
}

nonisolated enum Eligibility: Sendable, Equatable {
    case eligible
    case ineligible(reason: IneligibilityReason)
}

/// Which job field produced a skill match.
nonisolated enum SkillMatchField: String, CaseIterable, Sendable, Hashable {
    case title
    case tags
    case description
}

/// One piece of skill-match evidence.
nonisolated struct SkillEvidence: Sendable, Equatable, Hashable {
    let skillID: SkillID
    let field: SkillMatchField
    let matchedAlias: String
}

/// A derived, never-persisted explanation of how a posting matches the user profile.
nonisolated struct MatchResult: Sendable, Equatable {
    /// `nil` for ineligible postings.
    let score: Int?
    /// `nil` when the profile gate is unmet or the posting is ineligible.
    let band: MatchBand?
    let matchedSkills: [SkillID]
    let missingSkills: [SkillID]
    let components: MatchComponents
    let eligibility: Eligibility
    let confidence: Confidence
    let reason: String
    let evidence: [SkillEvidence]
}
