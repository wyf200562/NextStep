import Foundation
import Testing
@testable import NextStep

@Suite("RefreshLedger")
@MainActor
struct RefreshLedgerTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "NextStepTests.RefreshLedger.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func makeLedger(
        defaults: UserDefaults,
        now: Date
    ) -> (ledger: RefreshLedger, clock: MutableDateProvider) {
        let clock = MutableDateProvider(now: now)
        return (RefreshLedger(userDefaults: defaults, dateProvider: clock), clock)
    }

    @Test func firstFourAttemptsInTheRollingWindowAreAllowedThenQuotaIsExhausted() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let (ledger, clock) = makeLedger(defaults: defaults, now: start)

        for index in 0..<4 {
            #expect(ledger.nextAttemptBlock(for: .remotive) == nil, "Attempt \(index) should be allowed")
            ledger.recordAttempt(for: .remotive)
            clock.now = clock.now.addingTimeInterval(61)
        }

        #expect(ledger.nextAttemptBlock(for: .remotive) == .quotaExhausted)
        #expect(ledger.nextAttemptBlock(for: .url) == nil)
        #expect(ledger.lastSuccess(for: .remotive) == nil)
    }

    @Test func theQuotaWindowRollsForwardWithTheCurrentTime() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let (ledger, clock) = makeLedger(defaults: defaults, now: start)

        for _ in 0..<4 {
            ledger.recordAttempt(for: .remotive)
            clock.now = clock.now.addingTimeInterval(61)
        }
        #expect(ledger.nextAttemptBlock(for: .remotive) == .quotaExhausted)

        // The first attempt falls out of the rolling 24-hour window.
        clock.now = start.addingTimeInterval(24 * 60 * 60 + 1)
        #expect(ledger.nextAttemptBlock(for: .remotive) == nil)

        // Once every old attempt has aged out, another full quota is available.
        clock.now = start.addingTimeInterval(4 * 61 + 24 * 60 * 60 + 1)
        for index in 0..<4 {
            #expect(ledger.nextAttemptBlock(for: .remotive) == nil, "Attempt \(index) should be allowed")
            ledger.recordAttempt(for: .remotive)
            clock.now = clock.now.addingTimeInterval(61)
        }
        #expect(ledger.nextAttemptBlock(for: .remotive) == .quotaExhausted)
    }

    @Test func twoAttemptsMustBeAtLeastSixtySecondsApart() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let (ledger, clock) = makeLedger(defaults: defaults, now: start)

        ledger.recordAttempt(for: .remotive)

        clock.now = start.addingTimeInterval(59)
        #expect(ledger.nextAttemptBlock(for: .remotive) == .tooSoon)

        clock.now = start.addingTimeInterval(60)
        #expect(ledger.nextAttemptBlock(for: .remotive) == nil)
    }

    @Test func onlyASuccessfulRefreshUpdatesLastSuccess() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let (ledger, clock) = makeLedger(defaults: defaults, now: start)

        ledger.recordAttempt(for: .remotive)
        #expect(ledger.lastSuccess(for: .remotive) == nil)

        clock.now = start.addingTimeInterval(10)
        ledger.recordSuccess(for: .remotive)
        #expect(ledger.lastSuccess(for: .remotive) == start.addingTimeInterval(10))

        clock.now = start.addingTimeInterval(90)
        ledger.recordAttempt(for: .remotive)
        #expect(ledger.lastSuccess(for: .remotive) == start.addingTimeInterval(10))
    }

    @Test func ledgerStatePersistsAcrossInstances() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let (first, clock) = makeLedger(defaults: defaults, now: start)
        first.recordSuccess(for: .remotive)
        for _ in 0..<4 {
            #expect(first.nextAttemptBlock(for: .remotive) == nil)
            first.recordAttempt(for: .remotive)
            clock.now = clock.now.addingTimeInterval(61)
        }

        let (second, _) = makeLedger(defaults: defaults, now: clock.now)

        #expect(second.nextAttemptBlock(for: .remotive) == .quotaExhausted)
        #expect(second.lastSuccess(for: .remotive) == start)
    }

    @Test func resetClearsAttemptsAndSuccessForEverySource() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let (ledger, _) = makeLedger(defaults: defaults, now: start)
        ledger.recordAttempt(for: .remotive)
        ledger.recordAttempt(for: .url)
        ledger.recordSuccess(for: .remotive)

        ledger.reset()

        #expect(ledger.nextAttemptBlock(for: .remotive) == nil)
        #expect(ledger.nextAttemptBlock(for: .url) == nil)
        #expect(ledger.lastSuccess(for: .remotive) == nil)
    }

    @Test func anAttemptIsRecordedWhenItStartsNotWhenItSucceeds() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let (ledger, clock) = makeLedger(defaults: defaults, now: start)

        // Recording an attempt before a request that later fails still consumes quota and interval.
        ledger.recordAttempt(for: .remotive)
        ledger.recordAttempt(for: .remotive)
        clock.now = start.addingTimeInterval(60)

        #expect(ledger.nextAttemptBlock(for: .remotive) == nil)
        ledger.recordAttempt(for: .remotive)
        ledger.recordAttempt(for: .remotive)
        clock.now = start.addingTimeInterval(120)

        #expect(ledger.nextAttemptBlock(for: .remotive) == .quotaExhausted)
        #expect(ledger.lastSuccess(for: .remotive) == nil)
    }
}
