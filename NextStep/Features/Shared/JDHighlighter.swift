import Foundation

/// Whether a highlighted JD range matched a profile skill or is a required skill the profile lacks.
nonisolated enum JDHighlightKind: Sendable, Equatable {
    case matched
    case missing
}

/// One contiguous run of JD text. `kind == nil` means plain, unhighlighted text.
nonisolated struct JDHighlightSegment: Sendable, Equatable {
    let text: String
    let kind: JDHighlightKind?
}

/// Builds non-overlapping, longest-first JD highlight segments for the detail screen.
///
/// The highlighter is pure and display-only: it never mutates or persists the JD. Matching aliases
/// are searched case-insensitively using the same ASCII word-boundary rule as the matching engine,
/// so `Swift` never highlights inside `SwiftUI` while a longer alias can still win.
nonisolated enum JDHighlighter {
    private struct Candidate {
        let range: Range<String.Index>
        let kind: JDHighlightKind
        let alias: String
        let length: Int
        let offsetStart: Int
    }

    /// Canonical names plus aliases for the given skill ids; unknown ids fall back to the raw id.
    static func aliases(for skillIDs: [SkillID], dictionary: SkillDictionary?) -> [String] {
        var result: [String] = []
        var seen: Set<String> = []
        for skillID in skillIDs {
            let candidates: [String]
            if let skill = dictionary?.skill(id: skillID) {
                candidates = [skill.name] + skill.aliases
            } else {
                candidates = [skillID]
            }
            for candidate in candidates {
                let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else { continue }
                result.append(trimmed)
            }
        }
        return result
    }

    /// Splits `text` into plain and highlighted runs. Returns no segments for empty text.
    static func segments(
        text: String,
        matchedAliases: [String],
        missingAliases: [String]
    ) -> [JDHighlightSegment] {
        guard !text.isEmpty else { return [] }

        var candidates: [Candidate] = []
        for alias in matchedAliases {
            candidates += occurrences(of: alias, kind: .matched, in: text)
        }
        for alias in missingAliases {
            candidates += occurrences(of: alias, kind: .missing, in: text)
        }
        guard !candidates.isEmpty else {
            return [JDHighlightSegment(text: text, kind: nil)]
        }

        // Longest first; ties resolve by start, then matched over missing, then alias, so the
        // selection is deterministic even if two skills share an alias.
        candidates.sort { lhs, rhs in
            if lhs.length != rhs.length { return lhs.length > rhs.length }
            if lhs.offsetStart != rhs.offsetStart { return lhs.offsetStart < rhs.offsetStart }
            if lhs.kind != rhs.kind { return lhs.kind == .matched }
            return lhs.alias < rhs.alias
        }

        var claimed: [Range<String.Index>] = []
        var selected: [Candidate] = []
        for candidate in candidates
        where !claimed.contains(where: { $0.overlaps(candidate.range) }) {
            claimed.append(candidate.range)
            selected.append(candidate)
        }
        selected.sort { $0.offsetStart < $1.offsetStart }

        var result: [JDHighlightSegment] = []
        var cursor = text.startIndex
        for candidate in selected {
            if cursor < candidate.range.lowerBound {
                append(
                    JDHighlightSegment(text: String(text[cursor..<candidate.range.lowerBound]), kind: nil),
                    to: &result
                )
            }
            append(
                JDHighlightSegment(text: String(text[candidate.range]), kind: candidate.kind),
                to: &result
            )
            cursor = candidate.range.upperBound
        }
        if cursor < text.endIndex {
            append(JDHighlightSegment(text: String(text[cursor...]), kind: nil), to: &result)
        }
        return result
    }

    // MARK: - Scanning

    private static func occurrences(
        of alias: String,
        kind: JDHighlightKind,
        in text: String
    ) -> [Candidate] {
        guard !alias.isEmpty else { return [] }

        var results: [Candidate] = []
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let range = text.range(
                  of: alias,
                  options: [.caseInsensitive],
                  range: searchStart..<text.endIndex,
                  locale: nil
              ) {
            if hasWordBoundaries(range: range, in: text) {
                results.append(Candidate(
                    range: range,
                    kind: kind,
                    alias: alias,
                    length: text.distance(from: range.lowerBound, to: range.upperBound),
                    offsetStart: text.distance(from: text.startIndex, to: range.lowerBound)
                ))
            }
            searchStart = range.upperBound
        }
        return results
    }

    /// The same boundary rule as `MatchingTextNormalizer`: an ASCII alphanumeric edge must not sit
    /// next to another ASCII alphanumeric character.
    private static func hasWordBoundaries(range: Range<String.Index>, in text: String) -> Bool {
        guard range.lowerBound < range.upperBound else { return false }

        let first = text[range.lowerBound]
        let last = text[text.index(before: range.upperBound)]

        if isASCIIAlphanumeric(first), range.lowerBound > text.startIndex {
            let previous = text[text.index(before: range.lowerBound)]
            if isASCIIAlphanumeric(previous) { return false }
        }
        if isASCIIAlphanumeric(last), range.upperBound < text.endIndex {
            let next = text[range.upperBound]
            if isASCIIAlphanumeric(next) { return false }
        }
        return true
    }

    private static func isASCIIAlphanumeric(_ character: Character) -> Bool {
        character.isASCII && (character.isLetter || character.isNumber)
    }

    private static func append(_ segment: JDHighlightSegment, to segments: inout [JDHighlightSegment]) {
        if let last = segments.last, last.kind == segment.kind {
            segments[segments.count - 1] = JDHighlightSegment(
                text: last.text + segment.text,
                kind: last.kind
            )
        } else {
            segments.append(segment)
        }
    }
}
