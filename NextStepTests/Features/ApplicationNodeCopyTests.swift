import Foundation
import Testing
@testable import NextStep

@Suite("Application node copy")
struct ApplicationNodeCopyTests {
    private struct Round {
        let date: Date
        let result: InterviewResult
        let label: String?

        init(_ date: Date, result: InterviewResult = .pending, label: String? = nil) {
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

    private func application(
        status: ApplicationStatus = .applied,
        deadline: Date? = nil,
        rounds: [Round] = []
    ) -> Application {
        let application = Application(
            companyName: "公司",
            roleTitle: "职位",
            status: status,
            createdAt: day(0, hour: 8),
            deadline: deadline
        )
        application.interviewRounds = rounds.map {
            InterviewRound(scheduledAt: $0.date, format: .video, result: $0.result, label: $0.label)
        }
        return application
    }

    @Test("a round on the same instant supplies the node title")
    func roundOnTheSameInstantSuppliesTheTitle() {
        let instant = day(3, hour: 14)
        let application = application(deadline: instant, rounds: [Round(instant, label: "终面")])

        #expect(ApplicationNodeCopy.title(forNodeAt: instant, of: application) == "终面")
    }

    @Test("a blank round label falls back to 面试")
    func blankLabelFallsBackToInterview() {
        let instant = day(3, hour: 14)

        for label in [nil, ""] as [String?] {
            let application = application(deadline: instant, rounds: [Round(instant, label: label)])
            #expect(ApplicationNodeCopy.title(forNodeAt: instant, of: application) == "面试")
        }
    }

    @Test("a round that already has a result still supplies its label")
    func recordedResultStillSuppliesTheLabel() {
        let instant = day(3, hour: 14)
        let application = application(
            deadline: instant,
            rounds: [Round(instant, result: .passed, label: "一面")]
        )

        #expect(ApplicationNodeCopy.title(forNodeAt: instant, of: application) == "一面")
    }

    @Test("no round on the instant means 截止, whatever the status")
    func noRoundMeansDeadlineWhateverTheStatus() {
        let instant = day(3, hour: 14)
        let statuses: [ApplicationStatus] = [.applied, .oa, .interview, .offer]

        for status in statuses {
            let application = application(
                status: status,
                deadline: instant,
                rounds: [Round(day(4, hour: 14), label: "二面")]
            )
            #expect(ApplicationNodeCopy.title(forNodeAt: instant, of: application) == "截止")
        }
    }

    @Test("two rounds on one instant resolve to the lower id, whatever the array order")
    func roundsOnOneInstantResolveByID() {
        let instant = day(3, hour: 14)
        let first = InterviewRound(scheduledAt: instant, format: .video, label: "一面")
        let second = InterviewRound(scheduledAt: instant, format: .video, label: "二面")
        let ordered = [first, second].sorted { $0.id.uuidString < $1.id.uuidString }
        let application = application(deadline: instant)
        application.interviewRounds = [ordered[1], ordered[0]]

        #expect(ApplicationNodeCopy.round(at: instant, of: application)?.id == ordered[0].id)
        #expect(ApplicationNodeCopy.title(forNodeAt: instant, of: application) == ordered[0].label)
    }

    @Test("the round title seam names a round on its own")
    func roundTitleSeamNamesARound() {
        let instant = day(3, hour: 14)

        #expect(ApplicationNodeCopy.title(forRound: InterviewRound(
            scheduledAt: instant,
            format: .video,
            label: "终面"
        )) == "终面")
        #expect(ApplicationNodeCopy.title(forRound: InterviewRound(
            scheduledAt: instant,
            format: .video,
            label: ""
        )) == "面试")
    }

    @Test("a future round without a deadline produces no node")
    func futureRoundWithoutDeadlineProducesNoNode() {
        let now = day(0, hour: 10)
        let application = application(rounds: [Round(day(2, hour: 14), label: "一面")])

        #expect(ApplicationNodeCopy.node(for: application, now: now) == nil)
    }

    @Test("the node carries the deadline and marks it overdue once it has passed")
    func nodeCarriesTheDeadlineAndItsOverdueState() {
        let now = day(0, hour: 10)
        let upcomingDeadline = day(1, hour: 14)
        let overdueDeadline = day(0, hour: 9)

        let upcoming = ApplicationNodeCopy.node(
            for: application(deadline: upcomingDeadline),
            now: now
        )
        #expect(upcoming == ApplicationNode(date: upcomingDeadline, title: "截止", isOverdue: false))

        let overdue = ApplicationNodeCopy.node(
            for: application(deadline: overdueDeadline, rounds: [Round(overdueDeadline, label: "一面")]),
            now: now
        )
        #expect(overdue == ApplicationNode(date: overdueDeadline, title: "一面", isOverdue: true))
    }

    @Test("an ended application has no node even with a deadline")
    func endedApplicationHasNoNode() {
        let now = day(0, hour: 10)
        let deadline = day(1, hour: 9)

        for status in [ApplicationStatus.rejected, .withdrawn] {
            let application = application(status: status, deadline: deadline)
            #expect(ApplicationNodeCopy.node(for: application, now: now) == nil)
        }
    }
}
