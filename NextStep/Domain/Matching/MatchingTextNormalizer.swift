import Foundation

/// Text normalization shared by dictionary loading, skill scanning, and matching.
///
/// The pipeline is NFKC compatibility folding, case folding, HTML removal, punctuation
/// canonicalization, and whitespace collapsing. The original text is never mutated; callers keep
/// it for display.
nonisolated enum MatchingTextNormalizer {
    static func normalize(_ text: String) -> String {
        var value = HTMLTextNormalizer.plainText(from: text)
        value = value.precomposedStringWithCompatibilityMapping
        value = value.lowercased()
        value = normalizePunctuation(value)
        return collapseWhitespace(value)
    }

    /// Whether `alias` occurs in `text` at a valid alias boundary.
    static func containsAlias(_ alias: String, in text: String) -> Bool {
        !occurrences(of: alias, in: text).isEmpty
    }

    /// Non-overlapping occurrences of `alias` in `text`.
    ///
    /// Aliases that start or end with an ASCII alphanumeric need a word boundary on that side, so
    /// `swift` never matches inside `swiftui`. Chinese characters count as boundaries.
    static func occurrences(of alias: String, in text: String) -> [Range<String.Index>] {
        guard !alias.isEmpty, !text.isEmpty else { return [] }

        var results: [Range<String.Index>] = []
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let range = text.range(of: alias, range: searchStart..<text.endIndex) {
            if hasWordBoundaries(alias: alias, range: range, in: text) {
                results.append(range)
            }
            searchStart = range.upperBound
        }
        return results
    }

    // MARK: - Punctuation

    private static let punctuationReplacements: [(String, String)] = [
        ("\u{2010}", "-"), ("\u{2011}", "-"), ("\u{2012}", "-"), ("\u{2013}", "-"),
        ("\u{2014}", "-"), ("\u{2015}", "-"), ("\u{2212}", "-"),
        ("\u{2018}", "'"), ("\u{2019}", "'"), ("\u{201A}", "'"), ("\u{201B}", "'"),
        ("\u{201C}", "\""), ("\u{201D}", "\""), ("\u{201E}", "\""), ("\u{201F}", "\""),
        ("\u{2026}", "..."), ("\u{2044}", "/"), ("\u{2215}", "/"),
    ]

    private static func normalizePunctuation(_ text: String) -> String {
        var value = text
        for (source, replacement) in punctuationReplacements {
            value = value.replacingOccurrences(of: source, with: replacement)
        }
        return value
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    // MARK: - Boundaries

    private static func hasWordBoundaries(
        alias: String,
        range: Range<String.Index>,
        in text: String
    ) -> Bool {
        guard let first = alias.first, let last = alias.last else { return false }

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
}
