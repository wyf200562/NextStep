import Foundation

/// Per-source refresh quota and interval bookkeeping, persisted across launches in `UserDefaults`.
///
/// An "attempt" is recorded when a network request starts, before its outcome is known: successes,
/// failures, timeouts, offline errors, decoding errors, and cancelled requests all count. The
/// rolling window is stricter than a calendar day. `lastSuccess` only moves on a completed,
/// persisted refresh and drives the 6-hour Discover TTL and the "更新于" label.
@MainActor
final class RefreshLedger {
    static let maxAttemptsPerRollingWindow = 4
    static let rollingWindow: TimeInterval = 24 * 60 * 60
    static let minimumAttemptInterval: TimeInterval = 60

    private static let keyPrefix = "nextstep.refreshLedger"

    private let userDefaults: UserDefaults
    private let dateProvider: any DateProvider

    init(userDefaults: UserDefaults = .standard, dateProvider: any DateProvider) {
        self.userDefaults = userDefaults
        self.dateProvider = dateProvider
    }

    /// Why a new network attempt is not allowed right now, or `nil` when it is allowed.
    func nextAttemptBlock(for source: JobIntakeMethod) -> RefreshOutcome.SkipReason? {
        let attempts = activeAttempts(for: source)
        if attempts.count >= Self.maxAttemptsPerRollingWindow {
            return .quotaExhausted
        }
        if let latestAttempt = attempts.max(),
           dateProvider.now.timeIntervalSince(latestAttempt) < Self.minimumAttemptInterval {
            return .tooSoon
        }
        return nil
    }

    /// Call immediately before starting the request so cancelled attempts still consume quota.
    func recordAttempt(for source: JobIntakeMethod) {
        let now = dateProvider.now
        var attempts = activeAttempts(for: source, at: now)
        attempts.append(now)
        userDefaults.set(
            attempts.map(\.timeIntervalSince1970),
            forKey: attemptsKey(for: source)
        )
    }

    /// Call only after every draft was persisted; failures never move the successful-refresh time.
    func recordSuccess(for source: JobIntakeMethod) {
        userDefaults.set(dateProvider.now.timeIntervalSince1970, forKey: lastSuccessKey(for: source))
    }

    func lastSuccess(for source: JobIntakeMethod) -> Date? {
        guard userDefaults.object(forKey: lastSuccessKey(for: source)) != nil else { return nil }
        let interval = userDefaults.double(forKey: lastSuccessKey(for: source))
        return Date(timeIntervalSince1970: interval)
    }

    /// Clears every source's attempts and success time (used by the debug clear-data action).
    func reset() {
        for source in JobIntakeMethod.allCases {
            userDefaults.removeObject(forKey: attemptsKey(for: source))
            userDefaults.removeObject(forKey: lastSuccessKey(for: source))
        }
    }

    // MARK: - Storage

    private func activeAttempts(
        for source: JobIntakeMethod,
        at now: Date? = nil
    ) -> [Date] {
        let referenceDate = now ?? dateProvider.now
        let cutoff = referenceDate.addingTimeInterval(-Self.rollingWindow)
        return storedAttempts(for: source).filter { $0 > cutoff }
    }

    private func storedAttempts(for source: JobIntakeMethod) -> [Date] {
        let intervals = userDefaults.array(forKey: attemptsKey(for: source)) as? [Double] ?? []
        return intervals.map(Date.init(timeIntervalSince1970:))
    }

    private func attemptsKey(for source: JobIntakeMethod) -> String {
        "\(Self.keyPrefix).\(source.rawValue).attempts"
    }

    private func lastSuccessKey(for source: JobIntakeMethod) -> String {
        "\(Self.keyPrefix).\(source.rawValue).lastSuccess"
    }
}
