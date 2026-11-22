import Foundation
import Testing
@testable import NextStep

@Suite("Application list")
struct ApplicationListBuilderTests {
    private struct RoundSpec {
        let date: Date
        let result: InterviewResult
        let label: String?

        init(_ date: Date, _ result: InterviewResult = .pending, label: String? = nil) {
            self.date = date
            self.result = result
            self.label = label
        }
    }

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

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
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
            InterviewRound(scheduledAt: $0.date, format: .video, result: $0.result, label: $0.label)
        }
        return application
    }

    private func snapshot(
        _ filter: ApplicationListFilter,
        _ applications: [Application],
        now: Date? = nil
    ) -> ApplicationListSnapshot {
        ApplicationListBuilder.snapshot(
            for: filter,
            applications: applications,
            now: now ?? day(0, hour: 10),
            calendar: calendar
        )
    }

    @Test("the five filters select the agreed status groups")
    func filtersSelectAgreedStatusGroups() {
        let now = day(0, hour: 10)
        let applications = ApplicationStatus.allCases.enumerated().map { index, status in
            application(id: fixedID(index + 1), status: status, lastModifiedAt: now)
        }

        let all = snapshot(.all, applications)
        #expect(all.rows.count == 7)

        let activeIDs = Set(snapshot(.active, applications).rows.map(\.id))
        #expect(activeIDs == Set([
            fixedID(1), // wishlist
            fixedID(2), // applied
            fixedID(3), // oa
            fixedID(4), // interview
        ]))

        let offerIDs = Set(snapshot(.offer, applications).rows.map(\.id))
        #expect(offerIDs == [fixedID(5)])

        let endedIDs = Set(snapshot(.ended, applications).rows.map(\.id))
        #expect(endedIDs == Set([fixedID(6), fixedID(7)])) // rejected, withdrawn

        #expect(snapshot(.upcoming, applications).rows.isEmpty)
    }

    @Test("upcoming keeps only nodes from now to midnight on day eight and excludes terminal statuses")
    func upcomingKeepsOnlyNodesInsideTheWeek() {
        let now = day(0, hour: 10)

        let applications = [
            application(id: fixedID(1), deadline: now), // exactly now: inclusive
            application(id: fixedID(2), deadline: day(0, hour: 9, minute: 59)), // already overdue
            application(id: fixedID(3), deadline: day(7, hour: 23, minute: 59)), // last minute of the week
            application(id: fixedID(4), deadline: day(8, hour: 0)), // day-eight midnight: excluded
            application(id: fixedID(5), rounds: [RoundSpec(day(3, hour: 14))]), // rounds no longer count
            application(id: fixedID(6), status: .offer, deadline: day(1, hour: 9)),
            application(id: fixedID(7), status: .rejected, deadline: day(1, hour: 9)),
            application(id: fixedID(8), status: .withdrawn, deadline: day(1, hour: 9)),
        ]

        let ids = Set(snapshot(.upcoming, applications, now: now).rows.map(\.id))

        #expect(ids == Set([fixedID(1), fixedID(3), fixedID(6)]))
    }

    @Test("rows order upcoming nodes first, then overdue nodes most recent first, then the rest by last update")
    func rowsOrderUpcomingThenOverdueThenTheRest() {
        let now = day(0, hour: 10)

        let rows = snapshot(
            .all,
            [
                application(id: fixedID(1), lastModifiedAt: day(0, hour: 8), deadline: day(2, hour: 9)),
                application(id: fixedID(2), lastModifiedAt: day(0, hour: 8), deadline: day(3, hour: 9)),
                application(id: fixedID(3), lastModifiedAt: day(0, hour: 8), deadline: day(0, hour: 9)),
                application(
                    id: fixedID(4), lastModifiedAt: day(0, hour: 8),
                    deadline: day(0, hour: 9, minute: 30)
                ),
                application(id: fixedID(5), lastModifiedAt: day(0, hour: 9, minute: 30)),
                application(id: fixedID(6), lastModifiedAt: day(-1, hour: 9)),
            ],
            now: now
        ).rows

        #expect(rows.map(\.id) == [fixedID(1), fixedID(2), fixedID(4), fixedID(3), fixedID(5), fixedID(6)])
        #expect(rows[0].node?.isOverdue == false)
        #expect(rows[0].node?.title == "截止")
        #expect(rows[2].node?.isOverdue == true)
        #expect(rows[4].node == nil)
        #expect(rows[5].node == nil)
    }

    @Test("rows with the same node instant fall back to application id")
    func equalNodeInstantsFallBackToApplicationID() {
        let now = day(0, hour: 10)
        let upcomingInstant = day(3, hour: 9)
        let overdueInstant = day(0, hour: 9)

        let rows = snapshot(
            .all,
            [
                application(id: fixedID(4), lastModifiedAt: now, deadline: overdueInstant),
                application(id: fixedID(2), lastModifiedAt: now, deadline: upcomingInstant),
                application(id: fixedID(3), lastModifiedAt: now, deadline: overdueInstant),
                application(id: fixedID(1), lastModifiedAt: now, deadline: upcomingInstant),
            ],
            now: now
        ).rows

        #expect(rows.map(\.id) == [fixedID(1), fixedID(2), fixedID(3), fixedID(4)])
    }

    @Test("terminal applications have no node and sort with the node-less group")
    func terminalApplicationsHaveNoNode() {
        let now = day(0, hour: 10)
        let applications = [
            application(
                id: fixedID(1), status: .rejected,
                lastModifiedAt: day(0, hour: 9, minute: 30), deadline: day(1, hour: 9)
            ),
            application(id: fixedID(2), lastModifiedAt: day(0, hour: 8)),
            application(
                id: fixedID(3), status: .withdrawn,
                lastModifiedAt: day(0, hour: 9, minute: 45), deadline: day(1, hour: 9)
            ),
            application(id: fixedID(4), lastModifiedAt: day(0, hour: 8), deadline: day(2, hour: 9)),
        ]

        let rows = snapshot(.all, applications, now: now).rows

        #expect(rows.map(\.id) == [fixedID(4), fixedID(3), fixedID(1), fixedID(2)])
        #expect(rows[1].node == nil)
        #expect(rows[2].node == nil)
        #expect(snapshot(.upcoming, applications, now: now).rows.map(\.id) == [fixedID(4)])
    }

    @Test("a round on the deadline instant supplies the row's node title")
    func roundOnTheDeadlineInstantSuppliesTheRowTitle() {
        let now = day(0, hour: 10)
        let deadline = day(2, hour: 14)
        let application = application(
            id: fixedID(1),
            deadline: deadline,
            rounds: [RoundSpec(deadline, label: "终面")]
        )

        let row = snapshot(.all, [application], now: now).rows[0]

        #expect(row.node == ApplicationNode(date: deadline, title: "终面", isOverdue: false))
    }

    @Test("offer and ended order by last modification time and then id")
    func offerAndEndedOrderByLastModification() {
        let now = day(0, hour: 10)
        let applications = [
            application(
                id: fixedID(4), status: .offer,
                lastModifiedAt: day(0, hour: 8), deadline: day(1)
            ),
            application(
                id: fixedID(3), status: .offer,
                lastModifiedAt: day(0, hour: 9), deadline: day(2)
            ),
            application(
                id: fixedID(2), status: .rejected,
                lastModifiedAt: day(0, hour: 9)
            ),
            application(
                id: fixedID(1), status: .withdrawn,
                lastModifiedAt: day(0, hour: 9)
            ),
        ]

        #expect(snapshot(.offer, applications, now: now).rows.map(\.id) == [fixedID(3), fixedID(4)])
        #expect(snapshot(.ended, applications, now: now).rows.map(\.id) == [fixedID(1), fixedID(2)])
    }

    @Test("the summary counts every application and every active application")
    func summaryCountsAllAndActiveApplications() {
        let now = day(0, hour: 10)
        let applications = [
            application(id: fixedID(1), status: .wishlist, lastModifiedAt: now),
            application(id: fixedID(2), status: .interview, lastModifiedAt: now),
            application(id: fixedID(3), status: .offer, lastModifiedAt: now),
            application(id: fixedID(4), status: .rejected, lastModifiedAt: now),
        ]

        let offerSnapshot = snapshot(.offer, applications, now: now)

        #expect(offerSnapshot.totalCount == 4)
        #expect(offerSnapshot.activeCount == 2)
        #expect(offerSnapshot.rows.map(\.id) == [fixedID(3)])
    }
}
