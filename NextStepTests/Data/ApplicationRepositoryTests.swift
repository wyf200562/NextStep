import Foundation
import SwiftData
import Testing
@testable import NextStep

@Suite("ApplicationRepository")
struct ApplicationRepositoryTests {
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
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let repository = SwiftDataApplicationRepository(
            context: container.mainContext,
            dateProvider: FixedDateProvider(now: now, calendar: calendar)
        )
        return (repository, container)
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

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
