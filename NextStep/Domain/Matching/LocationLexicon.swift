import Foundation
import os

/// A country, region, or remote-work area recognized in location text.
nonisolated struct LocationRegion: Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    /// Normalized, lowercase aliases in English and Chinese.
    let aliases: [String]
    /// Broader region that contains this one, if any (for example China within Asia).
    let parentID: String?
}

/// A normalized location alias and its region.
nonisolated struct LocationAlias: Sendable, Equatable {
    let alias: String
    let regionID: String
}

/// Data-driven location lexicon.
nonisolated struct LocationLexicon: Sendable, Equatable {
    /// The region id reserved for remote/worldwide work.
    static let remoteRegionID = "remote"

    let regions: [LocationRegion]
    /// Normalized aliases sorted longest-first with dictionary-order tie-breaking.
    let aliasesInScanOrder: [LocationAlias]

    private let regionsByID: [String: LocationRegion]
    private let ownerByAlias: [String: String]

    init(regions: [LocationRegion]) {
        let knownIDs = Set(regions.map(\.id))
        var resolvedRegions: [LocationRegion] = []
        var byID: [String: LocationRegion] = [:]
        var owners: [String: String] = [:]
        var ordered: [LocationAlias] = []

        for region in regions {
            let parentID: String?
            if let rawParent = region.parentID {
                if rawParent != region.id, knownIDs.contains(rawParent) {
                    parentID = rawParent
                } else {
                    parentID = nil
                    AppLogger.matching.debug(
                        "Unknown location parent '\(rawParent, privacy: .public)' for '\(region.id, privacy: .public)' ignored"
                    )
                }
            } else {
                parentID = nil
            }

            let resolved = LocationRegion(
                id: region.id,
                name: region.name,
                aliases: region.aliases,
                parentID: parentID
            )
            resolvedRegions.append(resolved)
            byID[resolved.id] = resolved

            var seenForRegion: Set<String> = []
            for candidate in resolved.aliases {
                let alias = MatchingTextNormalizer.normalize(candidate)
                guard !alias.isEmpty, seenForRegion.insert(alias).inserted else { continue }

                if let existingOwner = owners[alias] {
                    if existingOwner != resolved.id {
                        AppLogger.matching.debug(
                            "Duplicate location alias '\(alias, privacy: .public)' ignored; '\(existingOwner, privacy: .public)' wins"
                        )
                    }
                } else {
                    owners[alias] = resolved.id
                    ordered.append(LocationAlias(alias: alias, regionID: resolved.id))
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
        self.regions = resolvedRegions
        self.regionsByID = byID
        self.ownerByAlias = owners
    }

    func region(id: String) -> LocationRegion? {
        regionsByID[id]
    }

    /// Every region with at least one alias appearing in the text.
    func regionIDs(in text: String) -> Set<String> {
        let normalized = MatchingTextNormalizer.normalize(text)
        guard !normalized.isEmpty else { return [] }

        var result: Set<String> = []
        for entry in aliasesInScanOrder where MatchingTextNormalizer.containsAlias(entry.alias, in: normalized) {
            result.insert(entry.regionID)
        }
        return result
    }

    func isAncestor(_ ancestorID: String, of regionID: String) -> Bool {
        var current = regionsByID[regionID]?.parentID
        var visited: Set<String> = []
        while let id = current, visited.insert(id).inserted {
            if id == ancestorID { return true }
            current = regionsByID[id]?.parentID
        }
        return false
    }

    /// Whether two regions overlap by identity or ancestor/descendant containment.
    ///
    /// Siblings such as US and Canada do not match each other through their common parent.
    func related(_ lhs: String, _ rhs: String) -> Bool {
        lhs == rhs || isAncestor(lhs, of: rhs) || isAncestor(rhs, of: lhs)
    }
}
