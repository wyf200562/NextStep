import Foundation

/// Shared validation for links from Remotive payloads and user-entered form fields.
///
/// Only absolute http(s) URLs with a non-empty host are usable; relative paths and custom
/// schemes are rejected everywhere so the same string is treated the same way across features.
nonisolated enum WebURL {
    /// Trims and parses `raw`, returning `nil` for blank or non-web input.
    static func parse(_ raw: String?) -> URL? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        return isValid(url) ? url : nil
    }

    /// Whether `url` is absolute http(s) and has a non-empty host.
    static func isValid(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        return url.host?.isEmpty == false
    }
}
