import Foundation
import SwiftData
import Testing
@testable import NextStep

@Suite("SwiftDataJobRepository")
@MainActor
struct SwiftDataJobRepositoryTests {
    private actor SourceCallRecorder {
        private(set) var count = 0

        func record() {
            count += 1
        }
    }

    private struct StubJobSource: JobSource {
        enum Outcome: Sendable {
            case drafts([JobPostingDraft])
            case failure(JobSourceError)
            case cancelled
        }

        let intakeMethod: JobIntakeMethod
        let outcome: Outcome
        var recorder: SourceCallRecorder?

        init(
            intakeMethod: JobIntakeMethod,
            drafts: [JobPostingDraft],
            recorder: SourceCallRecorder? = nil
        ) {
            self.intakeMethod = intakeMethod
            self.outcome = .drafts(drafts)
            self.recorder = recorder
        }

        init(
            intakeMethod: JobIntakeMethod,
            outcome: Outcome,
            recorder: SourceCallRecorder? = nil
        ) {
            self.intakeMethod = intakeMethod
            self.outcome = outcome
            self.recorder = recorder
        }

        func loadJobs() async throws -> [JobPostingDraft] {
            await recorder?.record()
            switch outcome {
            case .drafts(let drafts):
                return drafts
            case .failure(let error):
                throw error
            case .cancelled:
                throw CancellationError()
            }
        }
    }

    private struct TestLedger {
        let ledger: RefreshLedger
        let clock: MutableDateProvider
        let defaults: UserDefaults
        let suiteName: String

        @MainActor
        init(now: Date) {
            suiteName = "NextStepTests.SwiftDataJobRepository.\(UUID().uuidString)"
            defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            clock = MutableDateProvider(now: now)
            ledger = RefreshLedger(userDefaults: defaults, dateProvider: clock)
        }

        func cleanUp() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeFactory(
        remoteOutcome: StubJobSource.Outcome = .drafts([]),
        recorder: SourceCallRecorder? = nil,
        manualDrafts: @escaping @Sendable (ManualJobInput) -> [JobPostingDraft] = { _ in [] }
    ) -> JobSourceFactory {
        JobSourceFactory(
            makeRemote: { _ in
                StubJobSource(intakeMethod: .remotive, outcome: remoteOutcome, recorder: recorder)
            },
            makeManual: { input in
                StubJobSource(intakeMethod: .manual, drafts: manualDrafts(input))
            }
        )
    }

    private func makeRepository(
        context: ModelContext,
        ledger: RefreshLedger,
        clock: MutableDateProvider,
        remoteOutcome: StubJobSource.Outcome = .drafts([]),
        recorder: SourceCallRecorder? = nil,
        manualDrafts: @escaping @Sendable (ManualJobInput) -> [JobPostingDraft] = { _ in [] }
    ) -> SwiftDataJobRepository {
        SwiftDataJobRepository(
            context: context,
            dateProvider: clock,
            jobSourceFactory: makeFactory(
                remoteOutcome: remoteOutcome,
                recorder: recorder,
                manualDrafts: manualDrafts
            ),
            refreshLedger: ledger
        )
    }

    private func makeDraft(
        id: Int,
        title: String = "iOS Intern",
        descriptionPlainText: String = "Build with Swift."
    ) -> JobPostingDraft {
        JobPostingDraft(
            identityKey: "remotive:\(id)",
            intakeMethod: .remotive,
            title: title,
            companyName: "Sample Company",
            descriptionPlainText: descriptionPlainText,
            externalJobID: String(id),
            jobURL: URL(string: "https://remotive.com/jobs/\(id)"),
            location: "Worldwide",
            jobType: "internship",
            tags: ["Swift"],
            publishedAt: Date(timeIntervalSince1970: 1_600_000_000 + Double(id))
        )
    }

    // MARK: - Manual import

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
        let testLedger = TestLedger(now: fixedNow)
        defer { testLedger.cleanUp() }
        let repository = makeRepository(
            context: container.mainContext,
            ledger: testLedger.ledger,
            clock: testLedger.clock,
            manualDrafts: { _ in [draft] }
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
        let fixedLedger = TestLedger(now: firstDate)
        defer { fixedLedger.cleanUp() }
        let firstRepository = SwiftDataJobRepository(
            context: container.mainContext,
            dateProvider: FixedDateProvider(now: firstDate),
            jobSourceFactory: factory,
            refreshLedger: fixedLedger.ledger
        )
        let secondRepository = SwiftDataJobRepository(
            context: container.mainContext,
            dateProvider: FixedDateProvider(now: secondDate),
            jobSourceFactory: factory,
            refreshLedger: fixedLedger.ledger
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

        let testLedger = TestLedger(now: newerDate)
        defer { testLedger.cleanUp() }
        let repository = makeRepository(
            context: context,
            ledger: testLedger.ledger,
            clock: testLedger.clock
        )

        let cached = try repository.cachedJobs()

        #expect(cached.map(\.id) == [newerHighID.id, newerLowID.id, older.id])
    }

    // MARK: - Refresh

    @Test func refreshInsertsNewDraftsAndReportsAdded() async throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let testLedger = TestLedger(now: start)
        defer { testLedger.cleanUp() }
        let recorder = SourceCallRecorder()
        let repository = makeRepository(
            context: container.mainContext,
            ledger: testLedger.ledger,
            clock: testLedger.clock,
            remoteOutcome: .drafts([makeDraft(id: 1), makeDraft(id: 2)]),
            recorder: recorder
        )

        let outcome = await repository.refreshDiscover(query: JobQuery())

        guard case .refreshed(let added, let updated) = outcome else {
            Issue.record("Expected refreshed, got \(outcome)")
            return
        }
        #expect(added == 2)
        #expect(updated == 0)
        #expect(try repository.cachedJobs().count == 2)
        #expect(repository.lastRefreshAt(for: .remotive) == start)
        #expect(repository.lastRefreshAt(for: .manual) == nil)
        let recordedCount = await recorder.count
        #expect(recordedCount == 1)
    }

    @Test func refreshUpsertsByIdentityKeyAndCountsEveryTouchedDraft() async throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let testLedger = TestLedger(now: start)
        defer { testLedger.cleanUp() }
        let context = container.mainContext

        let firstRepository = makeRepository(
            context: context,
            ledger: testLedger.ledger,
            clock: testLedger.clock,
            remoteOutcome: .drafts([makeDraft(id: 1, title: "iOS Intern v1")])
        )
        let firstOutcome = await firstRepository.refreshDiscover(query: JobQuery())
        guard case .refreshed(let firstAdded, let firstUpdated) = firstOutcome else {
            Issue.record("Expected refreshed, got \(firstOutcome)")
            return
        }
        #expect(firstAdded == 1)
        #expect(firstUpdated == 0)
        let firstCreatedAt = try #require(try firstRepository.cachedJobs().first?.createdAt)

        testLedger.clock.now = start.addingTimeInterval(61)
        let secondRepository = makeRepository(
            context: context,
            ledger: testLedger.ledger,
            clock: testLedger.clock,
            remoteOutcome: .drafts([
                makeDraft(id: 1, title: "iOS Intern v2"),
                makeDraft(id: 2),
            ])
        )

        let secondOutcome = await secondRepository.refreshDiscover(query: JobQuery())

        guard case .refreshed(let added, let updated) = secondOutcome else {
            Issue.record("Expected refreshed, got \(secondOutcome)")
            return
        }
        #expect(added == 1)
        #expect(updated == 1)
        let cached = try secondRepository.cachedJobs()
        #expect(cached.count == 2)
        let updatedPosting = try #require(cached.first { $0.identityKey == "remotive:1" })
        #expect(updatedPosting.title == "iOS Intern v2")
        #expect(updatedPosting.createdAt == firstCreatedAt)
        #expect(secondRepository.lastRefreshAt(for: .remotive) == start.addingTimeInterval(61))
    }

    @Test func duplicateIdentityKeysWithinOneRefreshCountAsOneAddAndOneUpdate() async throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let testLedger = TestLedger(now: start)
        defer { testLedger.cleanUp() }
        let repository = makeRepository(
            context: container.mainContext,
            ledger: testLedger.ledger,
            clock: testLedger.clock,
            remoteOutcome: .drafts([
                makeDraft(id: 1, title: "v1"),
                makeDraft(id: 1, title: "v2"),
            ])
        )

        let outcome = await repository.refreshDiscover(query: JobQuery())

        guard case .refreshed(let added, let updated) = outcome else {
            Issue.record("Expected refreshed, got \(outcome)")
            return
        }
        #expect(added == 1)
        #expect(updated == 1)
        let cached = try repository.cachedJobs()
        #expect(cached.count == 1)
        #expect(cached.first?.title == "v2")
    }

    @Test func refreshNeverDeletesPreviouslyCachedPostings() async throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let testLedger = TestLedger(now: start)
        defer { testLedger.cleanUp() }
        let manualDraft = JobPostingDraft(
            identityKey: "manual:00000000-0000-0000-0000-000000000123",
            intakeMethod: .manual,
            title: "Manual iOS Intern",
            companyName: "本机公司",
            descriptionPlainText: "本地 JD"
        )
        let repository = makeRepository(
            context: container.mainContext,
            ledger: testLedger.ledger,
            clock: testLedger.clock,
            remoteOutcome: .drafts([makeDraft(id: 1)]),
            manualDrafts: { _ in [manualDraft] }
        )
        _ = try await repository.importManual(
            ManualJobInput(title: "iOS Intern", companyName: "本机公司", descriptionPlainText: "本地 JD")
        )

        _ = await repository.refreshDiscover(query: JobQuery())

        let cached = try repository.cachedJobs()
        #expect(cached.count == 2)
        #expect(cached.contains { $0.identityKey == manualDraft.identityKey })
        #expect(cached.contains { $0.identityKey == "remotive:1" })
    }

    @Test func successfulEmptyRefreshCountsAsSuccessAndUpdatesLastRefresh() async throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let testLedger = TestLedger(now: start)
        defer { testLedger.cleanUp() }
        let repository = makeRepository(
            context: container.mainContext,
            ledger: testLedger.ledger,
            clock: testLedger.clock,
            remoteOutcome: .drafts([])
        )

        let outcome = await repository.refreshDiscover(query: JobQuery())

        guard case .refreshed(let added, let updated) = outcome else {
            Issue.record("Expected refreshed, got \(outcome)")
            return
        }
        #expect(added == 0)
        #expect(updated == 0)
        #expect(try repository.cachedJobs().isEmpty)
        #expect(repository.lastRefreshAt(for: .remotive) == start)
    }

    @Test func failedRefreshConsumesAnAttemptAndKeepsTheLastSuccessTime() async throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let testLedger = TestLedger(now: start)
        defer { testLedger.cleanUp() }
        let context = container.mainContext
        let successfulRepository = makeRepository(
            context: context,
            ledger: testLedger.ledger,
            clock: testLedger.clock,
            remoteOutcome: .drafts([])
        )
        _ = await successfulRepository.refreshDiscover(query: JobQuery())

        testLedger.clock.now = start.addingTimeInterval(61)
        let failingRepository = makeRepository(
            context: context,
            ledger: testLedger.ledger,
            clock: testLedger.clock,
            remoteOutcome: .failure(.offline)
        )
        let outcome = await failingRepository.refreshDiscover(query: JobQuery())

        guard case .failed(let error, let cachedCount) = outcome else {
            Issue.record("Expected failed, got \(outcome)")
            return
        }
        #expect(error as? JobSourceError == .offline)
        #expect(cachedCount == 0)
        #expect(failingRepository.lastRefreshAt(for: .remotive) == start)

        // The failed attempt still consumes the 60-second interval.
        let immediateOutcome = await failingRepository.refreshDiscover(query: JobQuery())
        guard case .skipped(let reason) = immediateOutcome else {
            Issue.record("Expected skipped, got \(immediateOutcome)")
            return
        }
        #expect(reason == .tooSoon)
    }

    @Test func failedRefreshReportsTheCurrentCachedCount() async throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let testLedger = TestLedger(now: start)
        defer { testLedger.cleanUp() }
        let repository = makeRepository(
            context: container.mainContext,
            ledger: testLedger.ledger,
            clock: testLedger.clock,
            remoteOutcome: .failure(.timedOut),
            manualDrafts: { input in
                [JobPostingDraft(
                    identityKey: "manual:00000000-0000-0000-0000-000000000055",
                    intakeMethod: .manual,
                    title: input.title,
                    companyName: input.companyName,
                    descriptionPlainText: input.descriptionPlainText
                )]
            }
        )
        _ = try await repository.importManual(
            ManualJobInput(title: "iOS Intern", companyName: "Acme", descriptionPlainText: "JD")
        )

        let outcome = await repository.refreshDiscover(query: JobQuery())

        guard case .failed(let error, let cachedCount) = outcome else {
            Issue.record("Expected failed, got \(outcome)")
            return
        }
        #expect(error as? JobSourceError == .timedOut)
        #expect(cachedCount == 1)
    }

    @Test func fourNetworkAttemptsExhaustTheRollingQuotaWithoutCallingTheSourceAgain() async throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let testLedger = TestLedger(now: start)
        defer { testLedger.cleanUp() }
        let recorder = SourceCallRecorder()
        let repository = makeRepository(
            context: container.mainContext,
            ledger: testLedger.ledger,
            clock: testLedger.clock,
            remoteOutcome: .failure(.offline),
            recorder: recorder
        )

        for index in 0..<4 {
            let outcome = await repository.refreshDiscover(query: JobQuery())
            guard case .failed = outcome else {
                Issue.record("Attempt \(index) should reach the source and fail, got \(outcome)")
                return
            }
            testLedger.clock.now = testLedger.clock.now.addingTimeInterval(61)
        }

        let fifthOutcome = await repository.refreshDiscover(query: JobQuery())

        guard case .skipped(let reason) = fifthOutcome else {
            Issue.record("Expected quota skip, got \(fifthOutcome)")
            return
        }
        #expect(reason == .quotaExhausted)
        let recordedCount = await recorder.count
        #expect(recordedCount == 4)
        #expect(repository.lastRefreshAt(for: .remotive) == nil)
    }

    @Test func quotaPersistsAcrossRepositoryInstances() async throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let testLedger = TestLedger(now: start)
        defer { testLedger.cleanUp() }
        let firstRepository = makeRepository(
            context: container.mainContext,
            ledger: testLedger.ledger,
            clock: testLedger.clock,
            remoteOutcome: .drafts([])
        )
        for _ in 0..<4 {
            _ = await firstRepository.refreshDiscover(query: JobQuery())
            testLedger.clock.now = testLedger.clock.now.addingTimeInterval(61)
        }

        let relaunchedRepository = makeRepository(
            context: container.mainContext,
            ledger: RefreshLedger(
                userDefaults: testLedger.defaults,
                dateProvider: testLedger.clock
            ),
            clock: testLedger.clock,
            remoteOutcome: .drafts([])
        )
        let outcome = await relaunchedRepository.refreshDiscover(query: JobQuery())

        guard case .skipped(let reason) = outcome else {
            Issue.record("Expected quota skip after relaunch, got \(outcome)")
            return
        }
        #expect(reason == .quotaExhausted)
    }

    @Test func manualImportsDoNotConsumeRefreshQuota() async throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let testLedger = TestLedger(now: start)
        defer { testLedger.cleanUp() }
        let recorder = SourceCallRecorder()
        let repository = makeRepository(
            context: container.mainContext,
            ledger: testLedger.ledger,
            clock: testLedger.clock,
            remoteOutcome: .drafts([]),
            recorder: recorder,
            manualDrafts: { input in
                [JobPostingDraft(
                    identityKey: "manual:\(UUID().uuidString.lowercased())",
                    intakeMethod: .manual,
                    title: input.title,
                    companyName: input.companyName,
                    descriptionPlainText: input.descriptionPlainText
                )]
            }
        )

        for index in 0..<5 {
            _ = try await repository.importManual(
                ManualJobInput(title: "Intern \(index)", companyName: "Acme", descriptionPlainText: "JD")
            )
        }

        let outcome = await repository.refreshDiscover(query: JobQuery())

        guard case .refreshed = outcome else {
            Issue.record("A manual import must not block the first Remotive attempt, got \(outcome)")
            return
        }
        let recordedCount = await recorder.count
        #expect(recordedCount == 1)
        #expect(repository.lastRefreshAt(for: .manual) == nil)
    }

    @Test func cancelledRefreshStillConsumesAnAttemptAndReportsCancellation() async throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let testLedger = TestLedger(now: start)
        defer { testLedger.cleanUp() }
        let repository = makeRepository(
            context: container.mainContext,
            ledger: testLedger.ledger,
            clock: testLedger.clock,
            remoteOutcome: .cancelled
        )

        let outcome = await repository.refreshDiscover(query: JobQuery())

        guard case .failed(let error, _) = outcome else {
            Issue.record("Expected cancellation to surface as failed, got \(outcome)")
            return
        }
        #expect(error is CancellationError)
        #expect(repository.lastRefreshAt(for: .remotive) == nil)

        let immediateOutcome = await repository.refreshDiscover(query: JobQuery())
        guard case .skipped(let reason) = immediateOutcome else {
            Issue.record("Expected tooSoon after a cancelled attempt, got \(immediateOutcome)")
            return
        }
        #expect(reason == .tooSoon)
    }
}
