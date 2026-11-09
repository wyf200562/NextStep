import Foundation

/// Builds the stable, source-qualified identity string for a `JobPosting`.
///
/// `identityKey` is separate from the local `id`: refreshes upsert by this key so the same
/// posting is updated instead of duplicated.
nonisolated enum JobIdentityKey {
    static func remotive(externalID: String) -> String {
        "remotive:\(externalID)"
    }

    static func manual(id: UUID = UUID()) -> String {
        "manual:\(id.uuidString.lowercased())"
    }
}
