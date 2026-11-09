import Foundation

/// Pure helpers for the free-text tag lists on the 我的 tab: target roles and preferred locations.
///
/// Tags are trimmed, blanks are rejected, and duplicates are compared case- and
/// diacritic-insensitively so "Remote" and "remote" stay one tag.
nonisolated enum TagList {
    static func normalized(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func appending(_ raw: String, to tags: [String]) -> [String] {
        guard let tag = normalized(raw) else { return tags }
        let isDuplicate = tags.contains {
            $0.compare(
                tag,
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: nil
            ) == .orderedSame
        }
        return isDuplicate ? tags : tags + [tag]
    }

    static func removing(_ tag: String, from tags: [String]) -> [String] {
        tags.filter { $0 != tag }
    }
}
