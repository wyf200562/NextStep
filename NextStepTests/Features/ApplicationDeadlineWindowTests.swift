import Foundation
import Testing
@testable import NextStep

@Suite("Deadline window")
struct ApplicationDeadlineWindowTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()

    private func day(_ day: Int, hour: Int = 9, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 11,
            day: 9 + day,
            hour: hour,
            minute: minute
        ))!
    }

    private func application(
        status: ApplicationStatus = .applied,
        deadline: Date? = nil
    ) -> Application {
        Application(
            companyName: "公司",
            roleTitle: "职位",
            status: status,
            createdAt: day(0, hour: 8),
            deadline: deadline
        )
    }

    @Test("a deadline before now is overdue and outside the upcoming week")
    func deadlineBeforeNowIsOverdue() {
        let now = day(0, hour: 10)
        let application = application(deadline: day(0, hour: 9, minute: 59))

        #expect(ApplicationDeadlineWindow.isOverdue(application, now: now))
        #expect(!ApplicationDeadlineWindow.isUpcoming(application, now: now))
        #expect(!ApplicationDeadlineWindow.isWithinUpcomingWeek(application, now: now, calendar: calendar))
    }

    @Test("a deadline exactly at now is upcoming and inside the upcoming week")
    func deadlineAtNowIsUpcoming() {
        let now = day(0, hour: 10)
        let application = application(deadline: now)

        #expect(ApplicationDeadlineWindow.isUpcoming(application, now: now))
        #expect(!ApplicationDeadlineWindow.isOverdue(application, now: now))
        #expect(ApplicationDeadlineWindow.isWithinUpcomingWeek(application, now: now, calendar: calendar))
    }

    @Test("the window runs from now to midnight on day eight")
    func windowRunsFromNowToMidnightOnDayEight() {
        let now = day(0, hour: 10)
        let window = ApplicationDeadlineWindow.window(now: now, calendar: calendar)

        #expect(window.lowerBound == now)
        #expect(window.upperBound == day(8, hour: 0))
        #expect(window.contains(day(7, hour: 23, minute: 59)))
        #expect(!window.contains(day(8, hour: 0)))
        #expect(!window.contains(day(0, hour: 9, minute: 59)))
    }

    @Test("a missing deadline or an ended status is neither upcoming nor overdue")
    func missingDeadlineAndEndedStatusesAreExcluded() {
        let now = day(0, hour: 10)
        let applications = [
            application(deadline: nil),
            application(status: .rejected, deadline: day(1, hour: 9)),
            application(status: .withdrawn, deadline: day(1, hour: 9)),
        ]

        for application in applications {
            #expect(!ApplicationDeadlineWindow.isUpcoming(application, now: now))
            #expect(!ApplicationDeadlineWindow.isOverdue(application, now: now))
            #expect(!ApplicationDeadlineWindow.isWithinUpcomingWeek(application, now: now, calendar: calendar))
        }
    }
}
