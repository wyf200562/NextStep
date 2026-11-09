import Foundation
@testable import NextStep

/// Test clock whose `now` can be advanced manually.
///
/// The repository stamps `lastModifiedAt` with the current time, so deterministic tests need an
/// injectable clock that moves from "creation" to "edit" without reading the real clock.
nonisolated final class MutableDateProvider: DateProvider, @unchecked Sendable {
    var now: Date
    let calendar: Calendar

    init(now: Date, calendar: Calendar = .autoupdatingCurrent) {
        self.now = now
        self.calendar = calendar
    }
}
