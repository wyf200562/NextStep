import Foundation
import Testing
@testable import NextStep

@Suite("Overview dashboard")
struct DashboardBuilderTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()

    /// 2026-11-09 is the fixed "today" used by every case.
    private func day(_ offset: Int, hour: Int = 9, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 11,
            day: 9 + offset,
            hour: hour,
            minute: minute
        ))!
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    private struct RoundSpec {
        var id = UUID()
        var date: Date
        var result: InterviewResult = .pending
        var label: String?
    }

    private func application(
        id: UUID = UUID(),
        status: ApplicationStatus = .applied,
        lastModifiedAt: Date? = nil,
        deadline: Date? = nil,
        rounds: [RoundSpec] = []
    ) -> Application {
        let createdAt = day(0, hour: 8)
        let application = Application(
            id: id,
            companyName: "公司",
            roleTitle: "职位",
            status: status,
            createdAt: createdAt,
            lastModifiedAt: lastModifiedAt ?? createdAt,
            deadline: deadline
        )
        application.interviewRounds = rounds.map {
            InterviewRound(
                id: $0.id,
                scheduledAt: $0.date,
                format: .video,
                result: $0.result,
                label: $0.label
            )
        }
        return application
    }

    private func snapshot(
        _ applications: [Application],
        now: Date? = nil
    ) -> DashboardSnapshot {
        DashboardBuilder.snapshot(
            applications: applications,
            now: now ?? day(0, hour: 10),
            calendar: calendar
        )
    }

    @Test("today starts at this instant: an earlier node leaves the agenda and is counted as overdue")
    func todayAgendaStartsAtNowAndCountsPastNodesAsOverdue() {
        let now = day(0, hour: 13)
        let applications = [
            application(id: fixedID(1), deadline: day(0, hour: 9)),
            application(id: fixedID(2), deadline: now),
            application(id: fixedID(3), deadline: day(0, hour: 14)),
        ]

        let result = snapshot(applications, now: now)

        #expect(result.todayEvents.map(\.applicationID) == [fixedID(2), fixedID(3)])
        #expect(result.overdueCount == 1)
    }

    @Test("the upcoming window is tomorrow through midnight on day eight, and one application yields one event")
    func upcomingWindowIsTomorrowThroughDayEightMidnight() {
        let applications = [
            application(id: fixedID(1), deadline: day(0, hour: 23, minute: 59)),
            application(id: fixedID(2), deadline: day(1, hour: 0)),
            application(id: fixedID(3), deadline: day(7, hour: 23, minute: 59)),
            application(id: fixedID(4), deadline: day(8, hour: 0)),
            application(id: fixedID(5), deadline: day(-1, hour: 23, minute: 59)),
            application(id: fixedID(6), status: .offer, deadline: day(2, hour: 9)),
        ]

        let result = snapshot(applications)

        #expect(result.todayEvents.map(\.applicationID) == [fixedID(1)])
        #expect(result.upcomingEvents.map(\.applicationID) == [fixedID(2), fixedID(6), fixedID(3)])
        #expect(result.overdueCount == 1)
    }

    @Test("one application produces at most one event even when rounds sit inside the week")
    func oneApplicationProducesAtMostOneEvent() {
        let subject = application(
            id: fixedID(1),
            deadline: day(2, hour: 9),
            rounds: [
                RoundSpec(date: day(2, hour: 9), label: "终面"),
                RoundSpec(date: day(3, hour: 9), label: "HR 面"),
            ]
        )

        let result = snapshot([subject])

        #expect(result.todayEvents.isEmpty)
        #expect(result.upcomingEvents.count == 1)
        #expect(result.upcomingEvents.first?.applicationID == fixedID(1))
        #expect(result.upcomingEvents.first?.title == "终面")
    }

    @Test("rounds without a deadline produce no event and no count")
    func futureRoundsAloneAreInvisible() {
        let subject = application(
            id: fixedID(1),
            rounds: [RoundSpec(date: day(1, hour: 9), label: "一面")]
        )

        let result = snapshot([subject])

        #expect(result.todayEvents.isEmpty)
        #expect(result.upcomingEvents.isEmpty)
        #expect(result.upcomingCount == 0)
        #expect(result.overdueCount == 0)
    }

    @Test("ended applications never enter the agenda or the counts")
    func terminalApplicationsAreInvisible() {
        let applications = [
            application(id: fixedID(1), status: .rejected, deadline: day(1, hour: 9)),
            application(id: fixedID(2), status: .withdrawn, deadline: day(-3, hour: 9)),
        ]

        let result = snapshot(applications)

        #expect(result.todayEvents.isEmpty)
        #expect(result.upcomingEvents.isEmpty)
        #expect(result.upcomingCount == 0)
        #expect(result.overdueCount == 0)
    }

    @Test("event titles come from the shared node copy")
    func eventTitlesComeFromTheSharedCopy() {
        let applications = [
            application(
                id: fixedID(1),
                deadline: day(2, hour: 14),
                rounds: [RoundSpec(date: day(2, hour: 14), label: "终面")]
            ),
            application(
                id: fixedID(2),
                deadline: day(2, hour: 15),
                rounds: [RoundSpec(date: day(2, hour: 15))]
            ),
            application(id: fixedID(3), deadline: day(2, hour: 16)),
        ]

        let titles = Dictionary(
            uniqueKeysWithValues: snapshot(applications).upcomingEvents.map {
                ($0.applicationID, $0.title)
            }
        )

        #expect(titles[fixedID(1)] == "终面")
        #expect(titles[fixedID(2)] == "面试")
        #expect(titles[fixedID(3)] == "截止")
    }

    @Test("events order by time, then application id")
    func eventsOrderByTimeThenApplicationID() {
        let sharedInstant = day(1, hour: 9)
        let applications = [
            application(id: fixedID(3), deadline: sharedInstant),
            application(id: fixedID(1), deadline: sharedInstant),
            application(id: fixedID(2), deadline: day(1, hour: 8)),
        ]

        let events = snapshot(applications).upcomingEvents

        #expect(events.map(\.applicationID) == [fixedID(2), fixedID(1), fixedID(3)])
    }

    @Test("progress counts use one row per application and the same window as the list")
    func progressCountsDedupeApplications() {
        let applications = [
            application(id: fixedID(1), status: .applied, deadline: day(0, hour: 0)),
            application(
                id: fixedID(2),
                status: .interview,
                deadline: day(3, hour: 9),
                rounds: [RoundSpec(date: day(3, hour: 9))]
            ),
            application(id: fixedID(3), status: .offer, deadline: day(2, hour: 9)),
            application(id: fixedID(4), status: .wishlist),
            application(id: fixedID(5), status: .rejected, deadline: day(1, hour: 9)),
            application(id: fixedID(6), status: .withdrawn, rounds: [RoundSpec(date: day(1, hour: 9))]),
            application(id: fixedID(7), status: .applied, deadline: day(8, hour: 0)),
            application(
                id: fixedID(8),
                status: .applied,
                rounds: [RoundSpec(date: day(2, hour: 9), result: .passed)]
            ),
        ]

        let result = snapshot(applications)

        #expect(result.activeCount == 5) // 1, 2, 4, 7, 8
        #expect(result.upcomingCount == 2) // 2, 3 — the 00:00 node on day zero is already overdue
        #expect(result.overdueCount == 1) // 1
        #expect(result.offerCount == 1)
    }

    @Test("upcomingCount equals the row count of the list's upcoming filter")
    func upcomingCountMatchesTheListFilter() {
        let now = day(0, hour: 13)
        let applications = [
            application(id: fixedID(1), deadline: day(0, hour: 12)),
            application(id: fixedID(2), deadline: now),
            application(id: fixedID(3), deadline: day(7, hour: 23, minute: 59)),
            application(id: fixedID(4), deadline: day(8, hour: 0)),
            application(id: fixedID(5), rounds: [RoundSpec(date: day(1, hour: 9))]),
            application(id: fixedID(6), status: .withdrawn, deadline: day(1, hour: 9)),
        ]

        let result = snapshot(applications, now: now)
        let listRows = ApplicationListBuilder.snapshot(
            for: .upcoming,
            applications: applications,
            now: now,
            calendar: calendar
        ).rows

        #expect(result.upcomingCount == 2) // 2, 3
        #expect(result.upcomingCount == listRows.count)
    }

    @Test("recent updates are the five latest by last modification, then application id, across all statuses")
    func recentUpdatesTakeTheFiveLatest() {
        let applications = [
            application(id: fixedID(8), status: .rejected, lastModifiedAt: day(0, hour: 0)),
            application(id: fixedID(1), status: .applied, lastModifiedAt: day(0, hour: 1)),
            application(id: fixedID(2), status: .applied, lastModifiedAt: day(0, hour: 2)),
            application(id: fixedID(3), status: .applied, lastModifiedAt: day(0, hour: 3)),
            application(id: fixedID(4), status: .applied, lastModifiedAt: day(0, hour: 4)),
            application(id: fixedID(5), status: .applied, lastModifiedAt: day(0, hour: 5)),
            application(id: fixedID(7), status: .offer, lastModifiedAt: day(0, hour: 6)),
            application(id: fixedID(6), status: .rejected, lastModifiedAt: day(0, hour: 6)),
        ]

        let result = snapshot(applications)

        #expect(result.recentApplications.map(\.id) == [
            fixedID(6), fixedID(7), fixedID(5), fixedID(4), fixedID(3),
        ])
    }

    @Test("empty data yields no events, zero counts, and no recent applications")
    func emptyDataIsAnEmptyDashboard() {
        let result = snapshot([])

        #expect(result.todayEvents.isEmpty)
        #expect(result.upcomingEvents.isEmpty)
        #expect(result.activeCount == 0)
        #expect(result.upcomingCount == 0)
        #expect(result.overdueCount == 0)
        #expect(result.offerCount == 0)
        #expect(result.recentApplications.isEmpty)
        #expect(!result.hasEvents)
    }

    // MARK: - Table-driven agenda and window rules

    enum AgendaScenario: CaseIterable, Sendable, CustomTestStringConvertible {
        case todayDeadline
        case todayNodeAlreadyPast
        case tomorrowDeadline
        case daySevenDeadline
        case dayEightMidnightDeadline
        case yesterdayDeadline
        case rejectedDeadline
        case withdrawnDeadline
        case offerDeadline
        case futureRoundWithoutDeadline

        var testDescription: String {
            switch self {
            case .todayDeadline: "today deadline"
            case .todayNodeAlreadyPast: "today node already past"
            case .tomorrowDeadline: "tomorrow deadline"
            case .daySevenDeadline: "day seven deadline"
            case .dayEightMidnightDeadline: "day eight midnight deadline"
            case .yesterdayDeadline: "yesterday deadline"
            case .rejectedDeadline: "rejected deadline"
            case .withdrawnDeadline: "withdrawn deadline"
            case .offerDeadline: "offer deadline"
            case .futureRoundWithoutDeadline: "future round without deadline"
            }
        }
    }

    @Test("agenda and counts follow the deadline-only table", arguments: AgendaScenario.allCases)
    func agendaFollowsTheDeadlineOnlyTable(_ scenario: AgendaScenario) {
        let subject: Application
        switch scenario {
        case .todayDeadline:
            subject = application(id: fixedID(1), deadline: day(0, hour: 23))
        case .todayNodeAlreadyPast:
            subject = application(id: fixedID(1), deadline: day(0, hour: 9))
        case .tomorrowDeadline:
            subject = application(id: fixedID(1), deadline: day(1, hour: 0))
        case .daySevenDeadline:
            subject = application(id: fixedID(1), deadline: day(7, hour: 23, minute: 59))
        case .dayEightMidnightDeadline:
            subject = application(id: fixedID(1), deadline: day(8, hour: 0))
        case .yesterdayDeadline:
            subject = application(id: fixedID(1), deadline: day(-1, hour: 23, minute: 59))
        case .rejectedDeadline:
            subject = application(id: fixedID(1), status: .rejected, deadline: day(1, hour: 9))
        case .withdrawnDeadline:
            subject = application(id: fixedID(1), status: .withdrawn, deadline: day(-1, hour: 9))
        case .offerDeadline:
            subject = application(id: fixedID(1), status: .offer, deadline: day(2, hour: 9))
        case .futureRoundWithoutDeadline:
            subject = application(id: fixedID(1), rounds: [RoundSpec(date: day(1, hour: 9))])
        }

        let result = snapshot([subject])

        switch scenario {
        case .todayDeadline:
            #expect(result.todayEvents.count == 1)
            #expect(result.upcomingEvents.isEmpty)
            #expect(result.upcomingCount == 1)
            #expect(result.overdueCount == 0)
        case .tomorrowDeadline, .daySevenDeadline, .offerDeadline:
            #expect(result.todayEvents.isEmpty)
            #expect(result.upcomingEvents.count == 1)
            #expect(result.upcomingCount == 1)
            #expect(result.overdueCount == 0)
        case .todayNodeAlreadyPast, .yesterdayDeadline:
            #expect(result.todayEvents.isEmpty)
            #expect(result.upcomingEvents.isEmpty)
            #expect(result.upcomingCount == 0)
            #expect(result.overdueCount == 1)
        case .dayEightMidnightDeadline, .rejectedDeadline, .withdrawnDeadline,
             .futureRoundWithoutDeadline:
            #expect(result.todayEvents.isEmpty)
            #expect(result.upcomingEvents.isEmpty)
            #expect(result.upcomingCount == 0)
            #expect(result.overdueCount == 0)
        }
    }
}
