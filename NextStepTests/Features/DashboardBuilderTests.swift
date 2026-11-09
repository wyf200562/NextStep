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

    @Test("today lists today's deadlines and pending interviews, keeps past events flagged, and excludes other days")
    func todayWindowKeepsPastEventsAndExcludesOtherDays() {
        let now = day(0, hour: 10)
        let applications = [
            application(id: fixedID(1), deadline: day(0, hour: 9)),
            application(id: fixedID(2), rounds: [RoundSpec(date: day(0, hour: 15), label: "一面")]),
            application(id: fixedID(3), deadline: day(1, hour: 9)),
            application(id: fixedID(4), deadline: day(-1, hour: 9)),
            application(id: fixedID(5), rounds: [RoundSpec(date: day(0, hour: 11), result: .passed)]),
            application(id: fixedID(6), status: .rejected, deadline: day(0, hour: 12)),
        ]

        let result = snapshot(applications, now: now)

        #expect(result.todayEvents.map(\.applicationID) == [fixedID(1), fixedID(2)])
        #expect(result.todayEvents.map(\.kind) == [.deadline, .interview])
        #expect(result.todayEvents[0].isPast)
        #expect(!result.todayEvents[1].isPast)
        #expect(result.todayEvents[1].roundLabel == "一面")
        #expect(result.todayEvents[1].title == "面试 · 一面")
        #expect(result.upcomingEvents.map(\.applicationID) == [fixedID(3)])
    }

    @Test("the upcoming window covers tomorrow through today plus seven, and includes offer deadlines")
    func upcomingWindowCoversTomorrowThroughDaySeven() {
        let applications = [
            application(id: fixedID(1), deadline: day(0, hour: 23, minute: 59)),
            application(id: fixedID(2), deadline: day(1, hour: 0)),
            application(id: fixedID(3), deadline: day(7, hour: 23, minute: 59)),
            application(id: fixedID(4), deadline: day(8, hour: 0)),
            application(id: fixedID(5), rounds: [RoundSpec(date: day(1, hour: 0))]),
            application(id: fixedID(6), rounds: [RoundSpec(date: day(7, hour: 23, minute: 59))]),
            application(id: fixedID(7), status: .offer, deadline: day(2, hour: 9)),
        ]

        let result = snapshot(applications)

        #expect(result.todayEvents.map(\.applicationID) == [fixedID(1)])
        #expect(Set(result.upcomingEvents.map(\.applicationID)) == Set([
            fixedID(2), fixedID(3), fixedID(5), fixedID(6), fixedID(7),
        ]))
    }

    @Test("events merge by time, then application id, deadline before interview, then round id")
    func eventsMergeWithTheAgreedTieBreakers() {
        let sharedInstant = day(1, hour: 9)
        let laterRound = RoundSpec(id: fixedID(22), date: sharedInstant, label: "R2")
        let earlierRound = RoundSpec(id: fixedID(21), date: sharedInstant, label: "R1")

        let applications = [
            application(
                id: fixedID(12),
                deadline: day(1, hour: 10)
            ),
            application(
                id: fixedID(2),
                deadline: sharedInstant
            ),
            application(
                id: fixedID(1),
                deadline: sharedInstant,
                rounds: [laterRound, earlierRound]
            ),
            application(
                id: fixedID(3),
                deadline: day(1, hour: 8)
            ),
        ]

        let events = snapshot(applications).upcomingEvents

        #expect(events.count == 6)
        #expect(events[0].applicationID == fixedID(3))
        #expect(events[1].applicationID == fixedID(1))
        #expect(events[1].kind == .deadline)
        #expect(events[2].applicationID == fixedID(1))
        #expect(events[2].kind == .interview)
        #expect(events[2].roundID == fixedID(21))
        #expect(events[3].applicationID == fixedID(1))
        #expect(events[3].kind == .interview)
        #expect(events[3].roundID == fixedID(22))
        #expect(events[4].applicationID == fixedID(2))
        #expect(events[5].applicationID == fixedID(12))
    }

    @Test("progress counts dedupe applications and offer deadlines count as due soon")
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
        #expect(result.dueSoonCount == 3) // 1, 2 (deadline + round counted once), 3 (offer deadline)
        #expect(result.offerCount == 1)
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
        #expect(result.dueSoonCount == 0)
        #expect(result.offerCount == 0)
        #expect(result.recentApplications.isEmpty)
        #expect(!result.hasEvents)
    }

    // MARK: - Table-driven source and window rules

    enum SourceScenario: CaseIterable, Sendable, CustomTestStringConvertible {
        case todayDeadline
        case todayPendingRound
        case tomorrowDeadline
        case daySevenDeadline
        case dayEightDeadline
        case yesterdayDeadline
        case finishedRound
        case rejectedDeadline
        case withdrawnPendingRound
        case offerDeadline

        var testDescription: String {
            switch self {
            case .todayDeadline: "today deadline"
            case .todayPendingRound: "today pending round"
            case .tomorrowDeadline: "tomorrow deadline"
            case .daySevenDeadline: "day seven deadline"
            case .dayEightDeadline: "day eight deadline"
            case .yesterdayDeadline: "yesterday deadline"
            case .finishedRound: "finished round"
            case .rejectedDeadline: "rejected deadline"
            case .withdrawnPendingRound: "withdrawn pending round"
            case .offerDeadline: "offer deadline"
            }
        }
    }

    @Test("event sources and windows follow the spec table", arguments: SourceScenario.allCases)
    func eventSourceAndWindowRules(_ scenario: SourceScenario) {
        let subject: Application
        switch scenario {
        case .todayDeadline:
            subject = application(id: fixedID(1), deadline: day(0, hour: 23))
        case .todayPendingRound:
            subject = application(id: fixedID(1), rounds: [RoundSpec(date: day(0, hour: 23))])
        case .tomorrowDeadline:
            subject = application(id: fixedID(1), deadline: day(1, hour: 0))
        case .daySevenDeadline:
            subject = application(id: fixedID(1), deadline: day(7, hour: 23, minute: 59))
        case .dayEightDeadline:
            subject = application(id: fixedID(1), deadline: day(8, hour: 0))
        case .yesterdayDeadline:
            subject = application(id: fixedID(1), deadline: day(-1, hour: 23, minute: 59))
        case .finishedRound:
            subject = application(
                id: fixedID(1),
                rounds: [RoundSpec(date: day(1, hour: 9), result: .passed)]
            )
        case .rejectedDeadline:
            subject = application(id: fixedID(1), status: .rejected, deadline: day(1, hour: 9))
        case .withdrawnPendingRound:
            subject = application(
                id: fixedID(1),
                status: .withdrawn,
                rounds: [RoundSpec(date: day(1, hour: 9))]
            )
        case .offerDeadline:
            subject = application(id: fixedID(1), status: .offer, deadline: day(2, hour: 9))
        }

        let result = snapshot([subject])

        switch scenario {
        case .todayDeadline, .todayPendingRound:
            #expect(result.todayEvents.count == 1)
            #expect(result.upcomingEvents.isEmpty)
        case .tomorrowDeadline, .daySevenDeadline, .offerDeadline:
            #expect(result.todayEvents.isEmpty)
            #expect(result.upcomingEvents.count == 1)
        case .dayEightDeadline, .yesterdayDeadline, .finishedRound, .rejectedDeadline, .withdrawnPendingRound:
            #expect(result.todayEvents.isEmpty)
            #expect(result.upcomingEvents.isEmpty)
        }
        #expect(result.hasEvents == !result.todayEvents.isEmpty || !result.upcomingEvents.isEmpty)
    }
}
