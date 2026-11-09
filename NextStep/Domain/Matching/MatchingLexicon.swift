import Foundation

/// The immutable set of data-driven dictionaries used by matching.
nonisolated struct MatchingLexicon: Sendable, Equatable {
    let skillDictionary: SkillDictionary
    let roleDirectionLexicon: RoleDirectionLexicon
    let locationLexicon: LocationLexicon
}
