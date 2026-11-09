import Foundation

/// Bundle metadata and external links shown on the 关于 page.
///
/// The GitHub URL is a provisional placeholder: the repository is not public yet. Ticket 24
/// (release readiness) owns replacing it with the final repository URL.
nonisolated enum AppInfo {
    /// Provisional until ticket 24 finalizes the public repository URL.
    static let provisionalGitHubURL = URL(string: "https://github.com/")!

    static let remotiveURL = URL(string: "https://remotive.com/")!

    static var version: String {
        bundleString(forKey: "CFBundleShortVersionString") ?? "—"
    }

    static var build: String {
        bundleString(forKey: "CFBundleVersion") ?? "—"
    }

    /// e.g. `1.0（1）`.
    static var versionDisplayText: String {
        "\(version)（\(build)）"
    }

    private static func bundleString(forKey key: String) -> String? {
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
