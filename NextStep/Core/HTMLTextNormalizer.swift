import Foundation

/// Converts an HTML fragment into readable plain text.
///
/// Shared by the Remotive job source and the matching pipeline. It deliberately avoids a
/// third-party parser: scripts and styles are dropped, block boundaries become newlines, tags are
/// removed, common entities are decoded, and whitespace is collapsed.
nonisolated enum HTMLTextNormalizer {
    static func plainText(from html: String) -> String {
        guard html.contains("<") || html.contains("&") else { return html }

        var text = html
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        text = removeElement(text, tag: "script")
        text = removeElement(text, tag: "style")
        text = insertBlockBoundaries(in: text)
        text = removeTags(in: text)
        text = decodeEntities(in: text)
        return collapseWhitespace(in: text)
    }

    // MARK: - Elements

    private static func removeElement(_ text: String, tag: String) -> String {
        var result = text
        while let opening = result.range(of: "<\(tag)", options: [.caseInsensitive]) {
            guard let openingEnd = result[opening.lowerBound...].firstIndex(of: ">") else {
                result.removeSubrange(opening.lowerBound...)
                break
            }
            let contentStart = result.index(after: openingEnd)
            guard
                let closing = result.range(
                    of: "</\(tag)",
                    options: [.caseInsensitive],
                    range: contentStart..<result.endIndex
                ),
                let closingEnd = result[closing.lowerBound...].firstIndex(of: ">")
            else {
                result.removeSubrange(opening.lowerBound...)
                break
            }
            result.removeSubrange(opening.lowerBound...closingEnd)
        }
        return result
    }

    private static let blockMarkers = [
        "br", "/p", "/div", "/li", "/ul", "/ol", "/dl", "/dt", "/dd",
        "/h1", "/h2", "/h3", "/h4", "/h5", "/h6",
        "/tr", "/table", "/section", "/article", "/header", "/footer", "/blockquote",
    ]

    private static func insertBlockBoundaries(in text: String) -> String {
        var result = text
        for marker in blockMarkers {
            result = result.replacingOccurrences(
                of: "<\(marker)",
                with: "\n<\(marker)",
                options: [.caseInsensitive]
            )
        }
        return result
    }

    // MARK: - Tags

    private static func removeTags(in text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if character == "<" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, isTagStart(text[nextIndex]),
                   let tagEnd = text[index...].firstIndex(of: ">") {
                    index = text.index(after: tagEnd)
                    continue
                }
            }
            result.append(character)
            index = text.index(after: index)
        }
        return result
    }

    private static func isTagStart(_ character: Character) -> Bool {
        character == "/" || character == "!" || character == "?"
            || (character.isASCII && character.isLetter)
    }

    // MARK: - Entities

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "nbsp": " ", "hellip": "...", "mdash": "-", "ndash": "-",
        "rsquo": "'", "lsquo": "'", "ldquo": "\"", "rdquo": "\"",
        "middot": "·", "bull": "•", "copy": "©", "reg": "®",
    ]

    private static func decodeEntities(in text: String) -> String {
        guard text.contains("&") else { return text }

        var result = ""
        result.reserveCapacity(text.count)
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if character == "&",
               let semicolon = entitySemicolon(in: text, from: index) {
                let bodyStart = text.index(after: index)
                let body = String(text[bodyStart..<semicolon])
                if let decoded = decodedEntity(body) {
                    result.append(decoded)
                    index = text.index(after: semicolon)
                    continue
                }
            }
            result.append(character)
            index = text.index(after: index)
        }
        return result
    }

    private static func entitySemicolon(in text: String, from index: String.Index) -> String.Index? {
        let limit = text.index(index, offsetBy: 12, limitedBy: text.endIndex) ?? text.endIndex
        guard let semicolon = text[index..<limit].firstIndex(of: ";") else { return nil }
        return semicolon
    }

    private static func decodedEntity(_ body: String) -> String? {
        if body.hasPrefix("#x") || body.hasPrefix("#X") {
            guard let value = UInt32(body.dropFirst(2), radix: 16),
                  let scalar = UnicodeScalar(value) else { return nil }
            return String(Character(scalar))
        }
        if body.hasPrefix("#") {
            guard let value = UInt32(body.dropFirst()),
                  let scalar = UnicodeScalar(value) else { return nil }
            return String(Character(scalar))
        }
        return namedEntities[body.lowercased()]
    }

    // MARK: - Whitespace

    private static func collapseWhitespace(in text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            line.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }

        var output: [String] = []
        var previousWasBlank = true
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !previousWasBlank, !output.isEmpty {
                    output.append("")
                }
                previousWasBlank = true
            } else {
                output.append(trimmed)
                previousWasBlank = false
            }
        }
        return output.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
