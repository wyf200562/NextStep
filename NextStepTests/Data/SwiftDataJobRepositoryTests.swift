import Foundation
import SwiftData
import Testing
@testable import NextStep

@Suite("SwiftDataJobRepository")
struct SwiftDataJobRepositoryTests {
    private struct StubJobSource: JobSource {
        let intakeMethod: JobIntakeMethod
        let drafts: [JobPostingDraft]

        func loadJobs() async throws -> [JobPostingDraft] { drafts }
    }

    private func makeFactory(
        manualDrafts: @escaping @Sendable (ManualJobInput) -> [JobPostingDraft]
    ) -> JobSourceFactory {
        JobSourceFactory(
            makeRemote: { _ in StubJobSource(intakeMethod: .remotive, drafts: []) },
            makeManual: { input in
                StubJobSource(intakeMethod: .manual, drafts: manualDrafts(input))
            }
        )
    }

    @Test func importManualPersistsTheDraftAndReturnsTheJobPosting() async throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let jobURL = URL(string: "https://example.com/jobs/ios-intern")!
        let draft = JobPostingDraft(
            identityKey: "manual:00000000-0000-0000-0000-000000000001",
            intakeMethod: .manual,
            title: "iOS 开发实习生",
            companyName: "星舟科技",
            descriptionPlainText: "参与 iOS App 开发。",
            jobURL: jobURL,
            location: "远程 · 中国",
            jobType: "internship",
            tags: ["Swift", "SwiftUI"]
        )
        let repository = SwiftDataJobRepository(
            context: container.mainContext,
            dateProvider: FixedDateProvider(now: fixedNow),
            jobSourceFactory: makeFactory { _ in [draft] }
        )

        let posting = try await repository.importManual(
            ManualJobInput(title: "表单标题", companyName: "表单公司", descriptionPlainText: "表单 JD")
        )

        #expect(posting.identityKey == draft.identityKey)
        #expect(posting.intakeMethod == .manual)
        #expect(posting.title == draft.title)
        #expect(posting.companyName == draft.companyName)
        #expect(posting.descriptionPlainText == draft.descriptionPlainText)
        #expect(posting.jobURL == jobURL)
        #expect(posting.location == "远程 · 中国")
        #expect(posting.jobType == "internship")
        #expect(posting.tags == ["Swift", "SwiftUI"])
        #expect(posting.createdAt == fixedNow)
        #expect(posting.externalJobID == nil)
        #expect(posting.publishedAt == nil)

        let cached = try repository.cachedJobs()
        #expect(cached.count == 1)
        #expect(cached.first?.id == posting.id)

        // A fresh context sees the saved row, matching what a relaunch would read.
        let relaunchedContext = ModelContext(container)
        let persisted = try relaunchedContext.fetch(FetchDescriptor<JobPosting>())
        #expect(persisted.count == 1)
        #expect(persisted.first?.identityKey == draft.identityKey)
    }

    @Test func importManualUpsertsBySameIdentityKeyAndPreservesCreationTime() async throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let firstDate = Date(timeIntervalSince1970: 1_700_000_000)
        let secondDate = firstDate.addingTimeInterval(3_600)
        let fixedIdentityKey = "manual:00000000-0000-0000-0000-000000000042"
        let factory = makeFactory { input in
            [JobPostingDraft(
                identityKey: fixedIdentityKey,
                intakeMethod: .manual,
                title: input.title,
                companyName: input.companyName,
                descriptionPlainText: input.descriptionPlainText,
                jobURL: input.jobURL,
                location: input.location,
                jobType: input.jobType,
                tags: input.tags
            )]
        }
        let firstRepository = SwiftDataJobRepository(
            context: container.mainContext,
            dateProvider: FixedDateProvider(now: firstDate),
            jobSourceFactory: factory
        )
        let secondRepository = SwiftDataJobRepository(
            context: container.mainContext,
            dateProvider: FixedDateProvider(now: secondDate),
            jobSourceFactory: factory
        )

        let first = try await firstRepository.importManual(
            ManualJobInput(title: "iOS Intern", companyName: "Acme", descriptionPlainText: "v1")
        )
        let second = try await secondRepository.importManual(
            ManualJobInput(
                title: "iOS Intern (Updated)",
                companyName: "Acme 2",
                descriptionPlainText: "v2",
                jobURL: URL(string: "https://example.com/jobs/42"),
                location: "远程",
                jobType: "internship",
                tags: ["Swift"]
            )
        )

        #expect(second.id == first.id)
        #expect(second.identityKey == fixedIdentityKey)
        #expect(second.createdAt == firstDate)
        #expect(second.title == "iOS Intern (Updated)")
        #expect(second.companyName == "Acme 2")
        #expect(second.descriptionPlainText == "v2")
        #expect(second.location == "远程")
        #expect(second.jobType == "internship")
        #expect(second.tags == ["Swift"])

        let cached = try firstRepository.cachedJobs()
        #expect(cached.count == 1)
        #expect(cached.first?.id == first.id)
    }

    @Test func cachedJobsSortsByCreatedAtDescendingWithIDAscendingAsTieBreaker() throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let olderDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newerDate = olderDate.addingTimeInterval(60)

        let newerLowID = JobPosting(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
            identityKey: "remotive:1",
            title: "Newer A",
            companyName: "Acme",
            intakeMethod: .remotive,
            descriptionPlainText: "JD",
            createdAt: newerDate
        )
        let newerHighID = JobPosting(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
            identityKey: "remotive:2",
            title: "Newer B",
            companyName: "Acme",
            intakeMethod: .remotive,
            descriptionPlainText: "JD",
            createdAt: newerDate
        )
        let older = JobPosting(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            identityKey: "remotive:3",
            title: "Older",
            companyName: "Acme",
            intakeMethod: .remotive,
            descriptionPlainText: "JD",
            createdAt: olderDate
        )
        // Insert in the opposite order from the expected result so an unsorted fetch cannot pass.
        context.insert(older)
        context.insert(newerHighID)
        context.insert(newerLowID)
        try context.save()

        let repository = SwiftDataJobRepository(
            context: context,
            dateProvider: FixedDateProvider(now: newerDate),
            jobSourceFactory: makeFactory { _ in [] }
        )

        let cached = try repository.cachedJobs()

        #expect(cached.map(\.id) == [newerHighID.id, newerLowID.id, older.id])
    }

    @Test func refreshDiscoverReportsUnavailableWithCachedCountUntilTicket23() async throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        context.insert(JobPosting(
            identityKey: "manual:00000000-0000-0000-0000-000000000077",
            title: "iOS Intern",
            companyName: "Acme",
            intakeMethod: .manual,
            descriptionPlainText: "JD",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        ))
        try context.save()
        let repository = SwiftDataJobRepository(
            context: context,
            dateProvider: FixedDateProvider(now: Date(timeIntervalSince1970: 1_700_000_000)),
            jobSourceFactory: makeFactory { _ in [] }
        )

        let outcome = await repository.refreshDiscover(query: JobQuery())

        guard case .failed(let error, let cachedCount) = outcome else {
            Issue.record("Expected a failed refresh outcome")
            return
        }
        #expect((error as? RepositoryError) == .unavailable)
        #expect(cachedCount == 1)
        #expect(repository.lastRefreshAt(for: .remotive) == nil)
        #expect(repository.lastRefreshAt(for: .manual) == nil)
    }
}
