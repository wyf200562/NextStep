import Foundation
import os

/// A job-direction family such as iOS/mobile, backend, or design.
nonisolated struct DirectionFamily: Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    /// Normalized, lowercase aliases in English and Chinese.
    let aliases: [String]
}

/// A normalized direction alias and its family.
nonisolated struct DirectionAlias: Sendable, Equatable {
    let alias: String
    let directionID: String
}

/// Data-driven role-direction lexicon used to recognize target directions and "other" directions.
nonisolated struct RoleDirectionLexicon: Sendable, Equatable {
    let directions: [DirectionFamily]
    /// Normalized aliases sorted longest-first with dictionary-order tie-breaking.
    let aliasesInScanOrder: [DirectionAlias]

    private let directionsByID: [String: DirectionFamily]

    init(directions: [DirectionFamily]) {
        self.directions = directions

        var byID: [String: DirectionFamily] = [:]
        var owners: [String: String] = [:]
        var ordered: [DirectionAlias] = []

        for direction in directions {
            byID[direction.id] = direction
            var seenForDirection: Set<String> = []
            for candidate in direction.aliases {
                let alias = MatchingTextNormalizer.normalize(candidate)
                guard !alias.isEmpty, seenForDirection.insert(alias).inserted else { continue }

                if let existingOwner = owners[alias] {
                    if existingOwner != direction.id {
                        AppLogger.matching.debug(
                            "Duplicate direction alias '\(alias, privacy: .public)' ignored; '\(existingOwner, privacy: .public)' wins"
                        )
                    }
                } else {
                    owners[alias] = direction.id
                    ordered.append(DirectionAlias(alias: alias, directionID: direction.id))
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
        self.directionsByID = byID
    }

    func direction(id: String) -> DirectionFamily? {
        directionsByID[id]
    }

    /// Every family with at least one alias appearing in the text.
    func directionIDs(in text: String) -> Set<String> {
        let normalized = MatchingTextNormalizer.normalize(text)
        guard !normalized.isEmpty else { return [] }

        var result: Set<String> = []
        for entry in aliasesInScanOrder where MatchingTextNormalizer.containsAlias(entry.alias, in: normalized) {
            result.insert(entry.directionID)
        }
        return result
    }

    /// The first family in dictionary order whose alias appears in a target role.
    func directionID(forTargetRole text: String) -> String? {
        let matched = directionIDs(in: text)
        return directions.first { matched.contains($0.id) }?.id
    }
}
