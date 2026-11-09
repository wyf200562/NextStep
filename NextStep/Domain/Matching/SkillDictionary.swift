import Foundation
import os

/// One canonical skill in the bundled dictionary. `id` is stable; display changes go to `name`.
nonisolated struct Skill: Sendable, Equatable, Identifiable {
    let id: SkillID
    let name: String
    /// Normalized, lowercase aliases. The canonical name is also scanned but is not repeated here.
    let aliases: [String]
    let category: String
}

/// A normalized alias and the skill that owns it.
nonisolated struct SkillAlias: Sendable, Equatable {
    let alias: String
    let skillID: SkillID
}

/// Immutable, data-driven skill dictionary.
///
/// Aliases are normalized and deduplicated by dictionary order: the first skill that claims an
/// alias keeps it. `aliasesInScanOrder` is sorted longest-first so Chinese longest-substring
/// matching and multi-word English aliases win over their prefixes.
nonisolated struct SkillDictionary: Sendable, Equatable {
    let skills: [Skill]
    let aliasesInScanOrder: [SkillAlias]

    private let skillsByID: [SkillID: Skill]
    private let skillsByNormalizedName: [String: Skill]
    private let ownerByAlias: [String: SkillID]

    init(skills: [Skill]) {
        self.skills = skills

        var byID: [SkillID: Skill] = [:]
        var byName: [String: Skill] = [:]
        var owners: [String: SkillID] = [:]
        var ordered: [SkillAlias] = []

        for skill in skills {
            byID[skill.id] = skill
            let normalizedName = MatchingTextNormalizer.normalize(skill.name)
            if !normalizedName.isEmpty, byName[normalizedName] == nil {
                byName[normalizedName] = skill
            }

            var seenForSkill: Set<String> = []
            for candidate in [normalizedName] + skill.aliases {
                let alias = MatchingTextNormalizer.normalize(candidate)
                guard !alias.isEmpty, seenForSkill.insert(alias).inserted else { continue }

                if let existingOwner = owners[alias] {
                    if existingOwner != skill.id {
                        AppLogger.matching.debug(
                            "Duplicate skill alias '\(alias, privacy: .public)' ignored; '\(existingOwner, privacy: .public)' wins"
                        )
                    }
                } else {
                    owners[alias] = skill.id
                    ordered.append(SkillAlias(alias: alias, skillID: skill.id))
                }
            }
        }

        var insertionOrder: [String: Int] = [:]
        for (index, entry) in ordered.enumerated() {
            insertionOrder[entry.alias] = index
        }
        self.aliasesInScanOrder = ordered.sorted { lhs, rhs in
            if lhs.alias.count != rhs.alias.count { return lhs.alias.count > rhs.alias.count }
            return (insertionOrder[lhs.alias] ?? 0) < (insertionOrder[rhs.alias] ?? 0)
        }

        self.skillsByID = byID
        self.skillsByNormalizedName = byName
        self.ownerByAlias = owners
    }

    func skill(id: SkillID) -> Skill? {
        skillsByID[id]
    }

    /// Resolves a canonical display name case-insensitively. Aliases are scan-only.
    func skill(named name: String) -> Skill? {
        skillsByNormalizedName[MatchingTextNormalizer.normalize(name)]
    }

    func skillID(forAlias alias: String) -> SkillID? {
        ownerByAlias[MatchingTextNormalizer.normalize(alias)]
    }
}
