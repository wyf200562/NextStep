import Foundation

/// The result of asking `JobRepository` to refresh Discover.
nonisolated enum RefreshOutcome {
    /// `updated` counts every existing `identityKey` touched by this refresh, not only changed rows.
    case refreshed(added: Int, updated: Int)
    case skipped(reason: SkipReason)
    case failed(error: any Error, cachedCount: Int)

    nonisolated enum SkipReason: String, Sendable {
        case fresh
        case quotaExhausted
        case tooSoon
    }
}
