import Foundation

/// The single home for the upcoming boundary (ADR-0005 decisions 6 and 7).
enum ApplicationDeadlineWindow {
    /// `[now, today+8 00:00)`. Lower bound is an instant, upper bound a day boundary — intentional.
    /// Returns an empty range if the calendar cannot compute the upper bound.
    static func window(now: Date, calendar: Calendar) -> Range<Date> {
        let today = calendar.startOfDay(for: now)
        guard let upperBound = calendar.date(byAdding: .day, value: 8, to: today),
              upperBound > now
        else {
            return now..<now
        }
        return now..<upperBound
    }

    /// `deadline >= now`, inclusive to the minute. False when there is no deadline or the status
    /// is ended (`ApplicationStatus.isEnded`).
    static func isUpcoming(_ application: Application, now: Date) -> Bool {
        guard !application.status.isEnded, let deadline = application.deadline else { return false }
        return deadline >= now
    }

    /// `deadline < now`. Mirror of `isUpcoming`; same exclusions.
    static func isOverdue(_ application: Application, now: Date) -> Bool {
        guard !application.status.isEnded, let deadline = application.deadline else { return false }
        return deadline < now
    }

    /// Upcoming and inside `window(now:calendar:)`.
    static func isWithinUpcomingWeek(
        _ application: Application,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        guard isUpcoming(application, now: now), let deadline = application.deadline else {
            return false
        }
        return window(now: now, calendar: calendar).contains(deadline)
    }
}
