import Foundation
import SwiftData
import Testing
@testable import NextStep

@Suite("ApplicationRepository")
struct ApplicationRepositoryTests {
    nonisolated struct StatusTransition: Sendable, CustomTestStringConvertible {
        let from: ApplicationStatus
        let to: ApplicationStatus

        var testDescription: String { "\(from.rawValue)→\(to.rawValue)" }
    }

    private nonisolated static let validTransitions: [StatusTransition] = ApplicationStatus.allCases.flatMap { from in
        ApplicationStateMachine.allowedTransitions(from: from).map {
            StatusTransition(from: from, to: $0)
        }
    }

    private nonisolated static let invalidTransitions: [StatusTransition] = ApplicationStatus.allCases.flatMap { from in
        ApplicationStatus.allCases
            .filter { !ApplicationStateMachine.isValidTransition(from: from, to: $0) }
            .map { StatusTransition(from: from, to: $0) }
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    /// Creates an in-memory repository. The caller must keep the returned container alive for the
    /// repository's lifetime; `ModelContext` relies on its container.
    private func makeRepository(
        now: Date,
        calendar: Calendar
    ) throws -> (repository: SwiftDataApplicationRepository, container: ModelContainer) {
        try makeRepository(
            dateProvider: FixedDateProvider(now: now, calendar: calendar)
        )
    }

    private func makeRepository(
        dateProvider: any DateProvider
    ) throws -> (repository: SwiftDataApplicationRepository, container: ModelContainer) {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let repository = SwiftDataApplicationRepository(
            context: container.mainContext,
            dateProvider: dateProvider
        )
        return (repository, container)
    }

    private func createApplication(
        in repository: SwiftDataApplicationRepository,
        status: ApplicationStatus,
        statusDate: Date,
        jobPosting: JobPosting? = nil
    ) throws -> Application {
        try repository.createApplication(
            companyName: "星尘科技",
            roleTitle: "iOS 开发实习生",
            initialStatus: status,
            statusDate: statusDate,
            deadline: nil,
            jobURL: nil,
            location: nil,
            notes: nil,
            jobPosting: jobPosting
        )
    }

    @Test("createApplication writes snapshot fields and the initial StatusChange")
    func createApplicationWritesSnapshotAndInitialStatusChange() throws {
        let calendar = makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10, minute: 30))
        )
        let statusDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9))
        )
        let deadline = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 9))
        )
        let jobURL = try #require(URL(string: "https://example.com/jobs/42"))
        let made = try makeRepository(now: now, calendar: calendar)

        try withExtendedLifetime(made.container) {
            let repository = made.repository
            let application = try repository.createApplication(
                companyName: "星尘科技",
                roleTitle: "iOS 开发实习生",
                initialStatus: .applied,
                statusDate: statusDate,
                deadline: deadline,
                jobURL: jobURL,
                location: "上海",
                notes: "内推",
                jobPosting: nil
            )

            #expect(application.companyName == "星尘科技")
            #expect(application.roleTitle == "iOS 开发实习生")
            #expect(application.status == .applied)
            #expect(application.deadline == deadline)
            #expect(application.jobURL == jobURL)
            #expect(application.location == "上海")
            #expect(application.notes == "内推")
            #expect(application.createdAt == now)
            #expect(application.lastModifiedAt == now)

            let changes = try repository.statusChanges(for: application)
            #expect(changes.count == 1)
            let initial = try #require(changes.first)
            #expect(initial.fromStatus == nil)
            #expect(initial.toStatus == .applied)
            #expect(initial.changedAt == statusDate)
            #expect(initial.application === application)

            #expect(try repository.allApplications().map(\.id) == [application.id])
        }
    }

    @Test("reads find applications by id and by job posting")
    func readsFindApplicationsByIDAndJobPosting() throws {
        let calendar = makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))
        )
        let made = try makeRepository(now: now, calendar: calendar)

        try withExtendedLifetime(made.container) {
            let repository = made.repository
            let posting = JobPosting(
                identityKey: JobIdentityKey.manual(),
                title: "iOS 开发实习生",
                companyName: "星尘科技",
                intakeMethod: .manual,
                descriptionPlainText: "虚构 JD",
                createdAt: now
            )
            made.container.mainContext.insert(posting)

            let linked = try repository.createApplication(
                companyName: "星尘科技",
                roleTitle: "iOS 开发实习生",
                initialStatus: .wishlist,
                statusDate: now,
                deadline: nil,
                jobURL: nil,
                location: nil,
                notes: nil,
                jobPosting: posting
            )
            let unlinked = try repository.createApplication(
                companyName: "另一家公司",
                roleTitle: "iOS 实习生",
                initialStatus: .wishlist,
                statusDate: now,
                deadline: nil,
                jobURL: nil,
                location: nil,
                notes: nil,
                jobPosting: nil
            )

            #expect(Set(try repository.allApplications().map(\.id)) == [linked.id, unlinked.id])
            #expect(try repository.application(id: linked.id)?.id == linked.id)
            #expect(try repository.application(id: UUID()) == nil)
            #expect(try repository.applications(for: posting).map(\.id) == [linked.id])
        }
    }

    @Test("statusChanges sorts newest first and falls back to id on equal timestamps")
    func statusChangesSortByDateThenID() throws {
        let calendar = makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))
        )
        let earliest = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9))
        )
        let middle = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 9))
        )
        let latest = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 9))
        )
        let made = try makeRepository(now: now, calendar: calendar)

        try withExtendedLifetime(made.container) {
            let repository = made.repository
            let application = try repository.createApplication(
                companyName: "星尘科技",
                roleTitle: "iOS 开发实习生",
                initialStatus: .applied,
                statusDate: earliest,
                deadline: nil,
                jobURL: nil,
                location: nil,
                notes: nil,
                jobPosting: nil
            )
            let initialID = try #require(try repository.statusChanges(for: application).first?.id)

            let newest = StatusChange(
                id: fixedID(20),
                fromStatus: .oa,
                toStatus: .interview,
                changedAt: latest
            )
            let tiedLaterID = StatusChange(
                id: fixedID(30),
                fromStatus: .applied,
                toStatus: .oa,
                changedAt: middle
            )
            let tiedEarlierID = StatusChange(
                id: fixedID(10),
                fromStatus: .applied,
                toStatus: .oa,
                changedAt: middle
            )
            for change in [newest, tiedLaterID, tiedEarlierID] {
                made.container.mainContext.insert(change)
                change.application = application
            }
            try made.container.mainContext.save()

            #expect(
                try repository.statusChanges(for: application).map(\.id)
                    == [fixedID(20), fixedID(10), fixedID(30), initialID]
            )
        }
    }

    // MARK: - Derived appliedAt

    @Test("appliedAt comes from the initial StatusChange when the application starts as applied")
    func appliedAtUsesTheInitialAppliedStatusChange() throws {
        let calendar = makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))
        )
        let statusDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9))
        )
        let made = try makeRepository(now: now, calendar: calendar)

        try withExtendedLifetime(made.container) {
            let repository = made.repository
            let application = try createApplication(
                in: repository,
                status: .applied,
                statusDate: statusDate
            )
            let changes = try repository.statusChanges(for: application)

            #expect(application.appliedAt == statusDate)
            #expect(application.firstAppliedChange?.id == changes.first?.id)
            #expect(application.firstAppliedChange?.fromStatus == nil)
        }
    }

    @Test("appliedAt stays nil for wishlist and becomes the applied transition date later")
    func appliedAtAdvancesFromWishlistToApplied() throws {
        let calendar = makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))
        )
        let wishlistDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9))
        )
        let appliedDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 15))
        )
        let clock = MutableDateProvider(now: now, calendar: calendar)
        let made = try makeRepository(dateProvider: clock)

        try withExtendedLifetime(made.container) {
            let repository = made.repository
            let application = try createApplication(
                in: repository,
                status: .wishlist,
                statusDate: wishlistDate
            )

            #expect(application.appliedAt == nil)

            clock.now = appliedDate
            try repository.changeStatus(of: application, to: .applied, note: nil, at: appliedDate)

            #expect(application.appliedAt == appliedDate)
            let firstApplied = try #require(application.firstAppliedChange)
            #expect(firstApplied.toStatus == .applied)
            #expect(firstApplied.changedAt == appliedDate)
        }
    }

    @Test("appliedAt picks the earliest applied record and breaks ties by id")
    func appliedAtSortsByChangedAtThenID() throws {
        let calendar = makeCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))
        )
        let wishlistDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 9))
        )
        let early = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9))
        )
        let tiedEarliest = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 9))
        )
        let late = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 9))
        )
        let made = try makeRepository(now: now, calendar: calendar)

        try withExtendedLifetime(made.container) {
            let repository = made.repository
            let context = made.container.mainContext
            let application = try createApplication(
                in: repository,
                status: .wishlist,
                statusDate: wishlistDate
            )

            let earlyApplied = StatusChange(
                id: fixedID(40),
                toStatus: .applied,
                changedAt: early
            )
            let lateApplied = StatusChange(
                id: fixedID(50),
                toStatus: .applied,
                changedAt: late
            )
            for change in [lateApplied, earlyApplied] {
                context.insert(change)
                change.application = application
            }
            try context.save()

            #expect(application.appliedAt == early)
            #expect(application.firstAppliedChange?.id == fixedID(40))

            let tiedHigherID = StatusChange(
                id: fixedID(20),
                toStatus: .applied,
                changedAt: tiedEarliest
            )
            let tiedLowerID = StatusChange(
                id: fixedID(10),
                toStatus: .applied,
                changedAt: tiedEarliest
            )
            let tiedMiddleID = StatusChange(
                id: fixedID(30),
                toStatus: .applied,
                changedAt: tiedEarliest
            )
            for change in [tiedHigherID, tiedMiddleID, tiedLowerID] {
                context.insert(change)
                change.application = application
            }
            try context.save()

            #expect(application.appliedAt == tiedEarliest)
            #expect(application.firstAppliedChange?.id == fixedID(10))
        }
    }

    // MARK: - Status changes

    @Test("changeStatus appends a StatusChange and updates status and lastModifiedAt", arguments: Self.validTransitions)
    func changeStatusWritesHistoryAndStampsModifiedTime(for transition: StatusTransition) throws {
        let calendar = makeCalendar()
        let createdAt = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))
        )
        let statusDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9))
        )
        let changedAt = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 15))
        )
        let clock = MutableDateProvider(now: createdAt, calendar: calendar)
        let made = try makeRepository(dateProvider: clock)

        try withExtendedLifetime(made.container) {
            let repository = made.repository
            let application = try createApplication(
                in: repository,
                status: transition.from,
                statusDate: statusDate
            )
            clock.now = changedAt

            try repository.changeStatus(of: application, to: transition.to, note: "内推", at: changedAt)

            #expect(application.status == transition.to)
            #expect(application.lastModifiedAt == changedAt)

            let changes = try repository.statusChanges(for: application)
            #expect(changes.count == 2)
            let change = try #require(changes.first)
            #expect(change.fromStatus == transition.from)
            #expect(change.toStatus == transition.to)
            #expect(change.changedAt == changedAt)
            #expect(change.note == "内推")
            #expect(change.application === application)
        }
    }

    @Test("illegal transitions throw a typed error and leave the application untouched", arguments: Self.invalidTransitions)
    func illegalTransitionsThrowAndLeaveStateUntouched(for transition: StatusTransition) throws {
        let calendar = makeCalendar()
        let createdAt = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))
        )
        let statusDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9))
        )
        let changedAt = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 15))
        )
        let clock = MutableDateProvider(now: createdAt, calendar: calendar)
        let made = try makeRepository(dateProvider: clock)

        try withExtendedLifetime(made.container) {
            let repository = made.repository
            let application = try createApplication(
                in: repository,
                status: transition.from,
                statusDate: statusDate
            )
            clock.now = changedAt

            #expect(throws: ApplicationTransitionError(from: transition.from, to: transition.to)) {
                try repository.changeStatus(of: application, to: transition.to, note: nil, at: changedAt)
            }

            #expect(application.status == transition.from)
            #expect(application.lastModifiedAt == createdAt)
            #expect(try repository.statusChanges(for: application).count == 1)
        }
    }

    // MARK: - Update

    @Test("updateApplication replaces snapshot fields and lastModifiedAt without touching status history")
    func updateApplicationUpdatesFieldsAndModifiedTime() throws {
        let calendar = makeCalendar()
        let createdAt = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))
        )
        let statusDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9))
        )
        let editedAt = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 8, minute: 30))
        )
        let newDeadline = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 18))
        )
        let newURL = try #require(URL(string: "https://example.com/jobs/99"))
        let clock = MutableDateProvider(now: createdAt, calendar: calendar)
        let made = try makeRepository(dateProvider: clock)

        try withExtendedLifetime(made.container) {
            let repository = made.repository
            let application = try createApplication(
                in: repository,
                status: .applied,
                statusDate: statusDate
            )
            let historyBefore = try repository.statusChanges(for: application).map(\.id)
            clock.now = editedAt

            try repository.updateApplication(
                application,
                companyName: "新公司",
                roleTitle: "新职位",
                jobURL: newURL,
                location: "北京",
                notes: "改期了",
                deadline: newDeadline
            )

            #expect(application.companyName == "新公司")
            #expect(application.roleTitle == "新职位")
            #expect(application.jobURL == newURL)
            #expect(application.location == "北京")
            #expect(application.notes == "改期了")
            #expect(application.deadline == newDeadline)
            #expect(application.lastModifiedAt == editedAt)
            #expect(application.status == .applied)
            #expect(try repository.statusChanges(for: application).map(\.id) == historyBefore)
        }
    }

    @Test("updateApplication can clear optional snapshot fields")
    func updateApplicationClearsOptionalFields() throws {
        let calendar = makeCalendar()
        let createdAt = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))
        )
        let made = try makeRepository(now: createdAt, calendar: calendar)

        try withExtendedLifetime(made.container) {
            let repository = made.repository
            let application = try repository.createApplication(
                companyName: "星尘科技",
                roleTitle: "iOS 开发实习生",
                initialStatus: .wishlist,
                statusDate: createdAt,
                deadline: createdAt,
                jobURL: URL(string: "https://example.com/jobs/1"),
                location: "上海",
                notes: "备注",
                jobPosting: nil
            )

            try repository.updateApplication(
                application,
                companyName: "星尘科技",
                roleTitle: "iOS 开发实习生",
                jobURL: nil,
                location: nil,
                notes: nil,
                deadline: nil
            )

            #expect(application.jobURL == nil)
            #expect(application.location == nil)
            #expect(application.notes == nil)
            #expect(application.deadline == nil)
        }
    }

    // MARK: - Delete

    @Test("deleteApplication cascades rounds and status history but keeps the JobPosting")
    func deleteApplicationCascadesChildrenAndKeepsJobPosting() throws {
        let calendar = makeCalendar()
        let createdAt = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))
        )
        let made = try makeRepository(now: createdAt, calendar: calendar)

        try withExtendedLifetime(made.container) {
            let repository = made.repository
            let context = made.container.mainContext
            let posting = JobPosting(
                identityKey: JobIdentityKey.manual(),
                title: "iOS 开发实习生",
                companyName: "星尘科技",
                intakeMethod: .manual,
                descriptionPlainText: "虚构 JD",
                createdAt: createdAt
            )
            context.insert(posting)
            let application = try createApplication(
                in: repository,
                status: .interview,
                statusDate: createdAt,
                jobPosting: posting
            )
            let round = InterviewRound(scheduledAt: createdAt, format: .video, label: "一面")
            let extraChange = StatusChange(
                fromStatus: .applied,
                toStatus: .interview,
                changedAt: createdAt
            )
            context.insert(round)
            round.application = application
            context.insert(extraChange)
            extraChange.application = application
            try context.save()

            try repository.deleteApplication(application)

            #expect(try repository.application(id: application.id) == nil)
            #expect(try context.fetch(FetchDescriptor<InterviewRound>()).isEmpty)
            #expect(try context.fetch(FetchDescriptor<StatusChange>()).isEmpty)
            let postings = try context.fetch(FetchDescriptor<JobPosting>())
            #expect(postings.map(\.id) == [posting.id])
            #expect(postings.first?.applications.isEmpty == true)
        }
    }

    // MARK: - Interview rounds

    @Test("addInterviewRound links the round to the application and stamps lastModifiedAt without changing status")
    func addInterviewRoundLinksAndStampsWithoutChangingStatus() throws {
        let calendar = makeCalendar()
        let createdAt = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))
        )
        let addedAt = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 16))
        )
        let scheduledAt = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 14, minute: 30))
        )
        let clock = MutableDateProvider(now: createdAt, calendar: calendar)
        let made = try makeRepository(dateProvider: clock)

        try withExtendedLifetime(made.container) {
            let repository = made.repository
            let application = try createApplication(
                in: repository,
                status: .applied,
                statusDate: createdAt
            )
            clock.now = addedAt

            let round = try repository.addInterviewRound(
                to: application,
                scheduledAt: scheduledAt,
                format: .video,
                label: "一面",
                contact: "王女士",
                notes: "线上会议",
                result: .pending
            )

            #expect(round.application === application)
            #expect(application.interviewRounds.contains { $0.id == round.id })
            #expect(round.scheduledAt == scheduledAt)
            #expect(round.format == .video)
            #expect(round.label == "一面")
            #expect(round.contact == "王女士")
            #expect(round.notes == "线上会议")
            #expect(round.result == .pending)
            #expect(application.lastModifiedAt == addedAt)
            #expect(application.status == .applied)
            #expect(try repository.statusChanges(for: application).count == 1)
        }
    }

    @Test("updateInterviewRound replaces every field and stamps the owning application without changing status")
    func updateInterviewRoundStampsOwnerWithoutChangingStatus() throws {
        let calendar = makeCalendar()
        let createdAt = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))
        )
        let originalDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 14))
        )
        let rescheduledDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 16, minute: 45))
        )
        let editedAt = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 9))
        )
        let clock = MutableDateProvider(now: createdAt, calendar: calendar)
        let made = try makeRepository(dateProvider: clock)

        try withExtendedLifetime(made.container) {
            let repository = made.repository
            let application = try createApplication(
                in: repository,
                status: .oa,
                statusDate: createdAt
            )
            let round = try repository.addInterviewRound(
                to: application,
                scheduledAt: originalDate,
                format: .video,
                label: "一面",
                contact: nil,
                notes: nil,
                result: .pending
            )
            let historyBefore = try repository.statusChanges(for: application).map(\.id)
            let modifiedBeforeEdit = application.lastModifiedAt
            clock.now = editedAt

            try repository.updateInterviewRound(
                round,
                scheduledAt: rescheduledDate,
                format: .onsite,
                label: "二面",
                contact: "李先生",
                notes: "带简历",
                result: .passed
            )

            #expect(round.scheduledAt == rescheduledDate)
            #expect(round.format == .onsite)
            #expect(round.label == "二面")
            #expect(round.contact == "李先生")
            #expect(round.notes == "带简历")
            #expect(round.result == .passed)
            #expect(round.application === application)
            #expect(application.lastModifiedAt == editedAt)
            #expect(application.lastModifiedAt != modifiedBeforeEdit)
            #expect(application.status == .oa)
            #expect(try repository.statusChanges(for: application).map(\.id) == historyBefore)
        }
    }

    @Test("deleteInterviewRound removes only that round and stamps the owning application without changing status")
    func deleteInterviewRoundRemovesRoundAndStampsOwner() throws {
        let calendar = makeCalendar()
        let createdAt = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))
        )
        let firstDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 14))
        )
        let secondDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 11))
        )
        let deletedAt = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 9))
        )
        let clock = MutableDateProvider(now: createdAt, calendar: calendar)
        let made = try makeRepository(dateProvider: clock)

        try withExtendedLifetime(made.container) {
            let repository = made.repository
            let context = made.container.mainContext
            let application = try createApplication(
                in: repository,
                status: .interview,
                statusDate: createdAt
            )
            let first = try repository.addInterviewRound(
                to: application,
                scheduledAt: firstDate,
                format: .phone,
                label: "一面",
                contact: nil,
                notes: nil,
                result: .pending
            )
            let second = try repository.addInterviewRound(
                to: application,
                scheduledAt: secondDate,
                format: .onsite,
                label: "二面",
                contact: nil,
                notes: nil,
                result: .pending
            )
            let historyBefore = try repository.statusChanges(for: application).map(\.id)
            clock.now = deletedAt

            try repository.deleteInterviewRound(first)

            #expect(application.interviewRounds.map(\.id) == [second.id])
            #expect(application.lastModifiedAt == deletedAt)
            #expect(application.status == .interview)
            #expect(try repository.statusChanges(for: application).map(\.id) == historyBefore)
            #expect(
                try context.fetch(FetchDescriptor<InterviewRound>()).map(\.id) == [second.id]
            )
        }
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
