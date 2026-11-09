import Foundation
import Testing
@testable import NextStep

@Suite("Application list")
struct ApplicationListBuilderTests {
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
        rounds: [(date: Date, result: InterviewResult)] = []
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
            InterviewRound(scheduledAt: $0.date, format: .video, result: $0.result)
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

        #expect(snapshot(.dueSoon, applications).rows.isEmpty)
    }

    @Test("dueSoon covers today through today plus seven calendar days and excludes terminal statuses")
    func dueSoonCoversTheSevenDayWindow() {
        let now = day(0, hour: 10)
        let todayStart = day(0, hour: 0)
        let lastDayOfWindow = day(7, hour: 23, minute: 59)
        let dayAfterWindow = day(8, hour: 0)

        let applications = [
            application(id: fixedID(1), deadline: todayStart),
            application(id: fixedID(2), deadline: lastDayOfWindow),
            application(id: fixedID(3), deadline: dayAfterWindow),
            application(id: fixedID(4), deadline: day(-1, hour: 23, minute: 59)),
            application(id: fixedID(5), rounds: [(day(3, hour: 14), .pending)]),
            application(id: fixedID(6), rounds: [(day(3, hour: 14), .passed)]),
            application(id: fixedID(7), status: .offer, deadline: day(1, hour: 9)),
            application(id: fixedID(8), status: .rejected, deadline: day(1, hour: 9)),
            application(id: fixedID(9), status: .withdrawn, rounds: [(day(1, hour: 9), .pending)]),
        ]

        let ids = Set(snapshot(.dueSoon, applications, now: now).rows.map(\.id))

        #expect(ids == Set([
            fixedID(1), // today 00:00
            fixedID(2), // today + 7, last minute
            fixedID(5), // pending interview inside the window
            fixedID(7), // offer deadline still counts
        ]))
    }

    @Test("all, active, and dueSoon order by the nearest upcoming node, then last modification and id")
    func upcomingOrderingUsesNearestNodeThenLastModifiedAndID() {
        let now = day(0, hour: 10)

        let applicationWithDeadlineLater = application(
            id: fixedID(1),
            lastModifiedAt: day(0, hour: 9),
            deadline: day(2, hour: 9)
        )
        let applicationWithInterviewSooner = application(
            id: fixedID(2),
            lastModifiedAt: day(0, hour: 8),
            rounds: [(day(1, hour: 9), .pending)]
        )
        let applicationWithoutUpcomingNode = application(
            id: fixedID(3),
            lastModifiedAt: day(0, hour: 9, minute: 30)
        )
        let applicationWithPassedDeadline = application(
            id: fixedID(4),
            lastModifiedAt: day(0, hour: 7),
            deadline: day(0, hour: 9)
        )

        let rows = snapshot(
            .all,
            [
                applicationWithDeadlineLater,
                applicationWithInterviewSooner,
                applicationWithoutUpcomingNode,
                applicationWithPassedDeadline,
            ],
            now: now
        ).rows

        #expect(rows.map(\.id) == [fixedID(2), fixedID(1), fixedID(3), fixedID(4)])
        #expect(rows[0].nearestNode?.kind == .interview)
        #expect(rows[1].nearestNode?.kind == .deadline)
        #expect(rows[2].nearestNode == nil)
        #expect(rows[3].nearestNode == nil)
    }

    @Test("rows with the same nearest node fall back to application id")
    func equalNearestNodesFallBackToApplicationID() {
        let now = day(0, hour: 10)
        let deadline = day(3, hour: 9)

        let rows = snapshot(
            .all,
            [
                application(id: fixedID(2), lastModifiedAt: now, deadline: deadline),
                application(id: fixedID(1), lastModifiedAt: now, deadline: deadline),
            ],
            now: now
        ).rows

        #expect(rows.map(\.id) == [fixedID(1), fixedID(2)])
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

    @Test("the nearest node ignores finished rounds and prefers a deadline on an identical instant")
    func nearestNodeSelectionRules() {
        let now = day(0, hour: 10)
        let sharedInstant = day(1, hour: 9)

        let deadlineAndLaterInterview = application(
            id: fixedID(1),
            deadline: sharedInstant,
            rounds: [(day(2, hour: 9), .pending)]
        )
        let deadlineAndEarlierInterview = application(
            id: fixedID(2),
            deadline: day(2, hour: 9),
            rounds: [(day(1, hour: 9), .pending)]
        )
        let deadHeat = application(
            id: fixedID(3),
            deadline: sharedInstant,
            rounds: [(sharedInstant, .pending)]
        )
        let onlyFinishedRound = application(
            id: fixedID(4),
            rounds: [(day(1, hour: 9), .passed)]
        )

        let rows = snapshot(
            .all,
            [deadlineAndLaterInterview, deadlineAndEarlierInterview, deadHeat, onlyFinishedRound],
            now: now
        ).rows

        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        #expect(byID[fixedID(1)]?.nearestNode?.kind == .deadline)
        #expect(byID[fixedID(2)]?.nearestNode?.kind == .interview)
        #expect(byID[fixedID(3)]?.nearestNode?.kind == .deadline)
        #expect(byID[fixedID(4)]?.nearestNode == nil)
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
