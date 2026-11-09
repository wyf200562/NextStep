import Foundation

/// One category section in the skill picker.
nonisolated struct SkillCategoryGroup: Identifiable, Equatable, Sendable {
    let category: String
    let skills: [Skill]

    var id: String { category }
}

/// Pure grouping and search for the skill picker.
///
/// Categories keep the dictionary's first-appearance order; search matches canonical names and
/// aliases after the shared normalization pipeline.
nonisolated enum SkillCatalog {
    static func groups(from skills: [Skill], matching query: String) -> [SkillCategoryGroup] {
        let normalizedQuery = MatchingTextNormalizer.normalize(query)
        let filtered = normalizedQuery.isEmpty
            ? skills
            : skills.filter { matches($0, normalizedQuery: normalizedQuery) }

        var categoryOrder: [String] = []
        var skillsByCategory: [String: [Skill]] = [:]
        for skill in filtered {
            if skillsByCategory[skill.category] == nil {
                categoryOrder.append(skill.category)
            }
            skillsByCategory[skill.category, default: []].append(skill)
        }

        return categoryOrder.map { category in
            SkillCategoryGroup(category: category, skills: skillsByCategory[category] ?? [])
        }
    }

    static func matches(_ skill: Skill, normalizedQuery: String) -> Bool {
        guard !normalizedQuery.isEmpty else { return true }
        if MatchingTextNormalizer.normalize(skill.name).contains(normalizedQuery) {
            return true
        }
        return skill.aliases.contains { $0.contains(normalizedQuery) }
    }
}
