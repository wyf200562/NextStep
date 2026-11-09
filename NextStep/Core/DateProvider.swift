import Foundation

/// Supplies the current date and calendar so time-dependent logic is deterministic in tests.
nonisolated protocol DateProvider: Sendable {
    var now: Date { get }
    var calendar: Calendar { get }
}

/// Production provider backed by the system clock.
nonisolated struct SystemDateProvider: DateProvider {
    let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    var now: Date { Date() }
}

/// Deterministic provider for tests and Previews.
nonisolated struct FixedDateProvider: DateProvider {
    private let fixedNow: Date
    let calendar: Calendar

    init(now: Date, calendar: Calendar = .autoupdatingCurrent) {
        self.fixedNow = now
        self.calendar = calendar
    }

    var now: Date { fixedNow }
}
