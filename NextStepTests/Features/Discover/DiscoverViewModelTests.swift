import Foundation
import Testing
@testable import NextStep

@Suite("DiscoverViewModel")
struct DiscoverViewModelTests {
    @MainActor
    private final class FakeJobRepository: JobRepository {
        var cachedJobsResult: Result<[JobPosting], any Error> = .success([])
        private(set) var cachedJobsCallCount = 0

        func cachedJobs() throws -> [JobPosting] {
            cachedJobsCallCount += 1
            return try cachedJobsResult.get()
        }

        func refreshDiscover(query: JobQuery) async -> RefreshOutcome {
            .failed(error: RepositoryError.unavailable, cachedCount: 0)
        }

        func importManual(_ input: ManualJobInput) async throws -> JobPosting {
            throw RepositoryError.unavailable
        }

        func lastRefreshAt(for source: JobIntakeMethod) -> Date? { nil }
    }

    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDateProvider() -> FixedDateProvider {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return FixedDateProvider(now: fixedNow, calendar: calendar)
    }

    private func makePosting(
        title: String,
        intakeMethod: JobIntakeMethod,
        jobType: String?
    ) -> JobPosting {
        JobPosting(
            identityKey: "\(intakeMethod.rawValue):\(UUID().uuidString.lowercased())",
            title: title,
            companyName: "Acme",
            intakeMethod: intakeMethod,
            descriptionPlainText: "JD",
            createdAt: fixedNow,
            jobType: jobType
        )
    }

    @Test func loadCachedJobsPublishesJobsAndSampleCounts() {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([
            makePosting(title: "Remotive Intern", intakeMethod: .remotive, jobType: "internship"),
            makePosting(title: "Remotive Full Time", intakeMethod: .remotive, jobType: "full_time"),
            makePosting(title: "Manual Intern", intakeMethod: .manual, jobType: "internship"),
            makePosting(title: "Manual Full Time", intakeMethod: .manual, jobType: "full_time"),
        ])
        let viewModel = DiscoverViewModel(
            jobRepository: repository,
            dateProvider: makeDateProvider()
        )

        viewModel.loadCachedJobs()

        #expect(repository.cachedJobsCallCount == 1)
        #expect(viewModel.cacheState.value?.count == 4)
        #expect(viewModel.jobs.count == 4)
        #expect(viewModel.visibleJobs.count == 4)
        #expect(viewModel.remotiveCount == 2)
        #expect(viewModel.remotiveInternshipCount == 1)
        #expect(viewModel.manualCount == 2)
        #expect(viewModel.cacheErrorMessage == nil)
        #expect(viewModel.sampleDateText == "11 月 14 日 · 今日样本")
    }

    @Test func onlyInternshipsFiltersVisibleJobsWithoutChangingSampleCounts() {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([
            makePosting(title: "Remotive Intern", intakeMethod: .remotive, jobType: "internship"),
            makePosting(title: "Remotive Full Time", intakeMethod: .remotive, jobType: "full_time"),
            makePosting(title: "Manual Intern", intakeMethod: .manual, jobType: "internship"),
            makePosting(title: "Manual Full Time", intakeMethod: .manual, jobType: "full_time"),
        ])
        let viewModel = DiscoverViewModel(
            jobRepository: repository,
            dateProvider: makeDateProvider()
        )
        viewModel.loadCachedJobs()

        viewModel.onlyInternships = true

        #expect(viewModel.visibleJobs.map(\.title) == ["Remotive Intern", "Manual Intern"])
        #expect(viewModel.remotiveCount == 2)
        #expect(viewModel.remotiveInternshipCount == 1)
        #expect(viewModel.manualCount == 2)

        viewModel.onlyInternships = false

        #expect(viewModel.visibleJobs.count == 4)
    }

    @Test func cacheLoadFailureMapsToChineseMessage() {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .failure(RepositoryError.loadFailed)
        let viewModel = DiscoverViewModel(
            jobRepository: repository,
            dateProvider: makeDateProvider()
        )

        viewModel.loadCachedJobs()

        #expect(viewModel.jobs.isEmpty)
        #expect(viewModel.cacheState.error is RepositoryError)
        #expect(viewModel.cacheErrorMessage == "加载失败，请稍后重试")
    }

    // MARK: - Match grouping

    @Test func readyMatchesGroupJobsAndSortEligibleByScore() {
        let repository = FakeJobRepository()
        let eligibleHigh = MatchFixtures.job(identityKey: "remotive:a")
        let eligibleLow = MatchFixtures.job(identityKey: "manual:b", intakeMethod: .manual)
        let ineligible = MatchFixtures.job(
            identityKey: "remotive:c",
            title: "iOS Engineer",
            jobType: "full_time"
        )
        repository.cachedJobsResult = .success([eligibleLow, ineligible, eligibleHigh])

        let provider = FakeMatchProvider()
        provider.results = [
            "remotive:a": MatchFixtures.result(score: 90),
            "manual:b": MatchFixtures.result(score: 60, band: .medium),
            "remotive:c": MatchFixtures.result(
                score: nil,
                band: nil,
                eligibility: .ineligible(reason: .notInternship)
            ),
        ]
        let viewModel = DiscoverViewModel(
            jobRepository: repository,
            dateProvider: makeDateProvider(),
            matchProvider: provider
        )

        viewModel.loadCachedJobs()

        #expect(viewModel.matchAvailability == .ready)
        #expect(viewModel.eligibleJobs.map(\.job.identityKey) == ["remotive:a", "manual:b"])
        #expect(viewModel.ineligibleJobs.map(\.job.identityKey) == ["remotive:c"])
        #expect(viewModel.eligibleJobs.first?.match?.score == 90)
        #expect(provider.evaluateJobsCalls.count == 1)
        #expect(provider.eligibilityCalls.isEmpty)
    }

    @Test func profileIncompleteUsesGateIndependentEligibilityForGrouping() {
        let repository = FakeJobRepository()
        let europeMismatch = MatchFixtures.job(
            identityKey: "remotive:europe",
            location: "Europe"
        )
        let remote = MatchFixtures.job(identityKey: "remotive:remote")
        repository.cachedJobsResult = .success([europeMismatch, remote])

        let provider = FakeMatchProvider()
        provider.results = [:]
        provider.fallbackEligibility = [
            "remotive:europe": .ineligible(reason: .locationMismatch),
            "remotive:remote": .eligible,
        ]
        let viewModel = DiscoverViewModel(
            jobRepository: repository,
            dateProvider: makeDateProvider(),
            matchProvider: provider
        )

        viewModel.loadCachedJobs()

        #expect(viewModel.matchAvailability == .profileIncomplete)
        #expect(viewModel.eligibleJobs.map(\.job.identityKey) == ["remotive:remote"])
        #expect(viewModel.ineligibleJobs.map(\.job.identityKey) == ["remotive:europe"])
        #expect(viewModel.eligibleJobs.first?.match == nil)
        #expect(provider.eligibilityCalls.count == 1)
    }

    @Test func missingProviderShowsUnavailableButStillGroupsByStoredJobType() {
        let repository = FakeJobRepository()
        let internship = MatchFixtures.job(identityKey: "manual:intern")
        let fullTime = MatchFixtures.job(
            identityKey: "manual:full",
            title: "iOS Engineer",
            jobType: "full_time"
        )
        repository.cachedJobsResult = .success([internship, fullTime])

        let viewModel = DiscoverViewModel(
            jobRepository: repository,
            dateProvider: makeDateProvider()
        )

        viewModel.loadCachedJobs()

        #expect(viewModel.matchAvailability == .unavailable)
        #expect(viewModel.eligibleJobs.map(\.job.identityKey) == ["manual:intern"])
        #expect(viewModel.ineligibleJobs.map(\.job.identityKey) == ["manual:full"])
        #expect(viewModel.ineligibleJobs.first?.eligibility == .ineligible(reason: .notInternship))
    }

    @Test func evaluationFailureDegradesToUnavailableWithoutLosingCachedJobs() {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([
            MatchFixtures.job(identityKey: "manual:a"),
            MatchFixtures.job(identityKey: "manual:b", jobType: "full_time"),
        ])
        let provider = FakeMatchProvider()
        provider.evaluateError = RepositoryError.unavailable
        let viewModel = DiscoverViewModel(
            jobRepository: repository,
            dateProvider: makeDateProvider(),
            matchProvider: provider
        )

        viewModel.loadCachedJobs()

        #expect(viewModel.jobs.count == 2)
        #expect(viewModel.matchAvailability == .unavailable)
        #expect(viewModel.eligibleJobs.count == 1)
        #expect(viewModel.ineligibleJobs.count == 1)
    }

    @Test func onlyInternshipsFiltersDisplayedGroupsWithoutReevaluatingMatches() {
        let repository = FakeJobRepository()
        let fullTimeHigh = MatchFixtures.job(
            identityKey: "remotive:full",
            title: "iOS Engineer",
            jobType: "full_time"
        )
        let internHigh = MatchFixtures.job(identityKey: "remotive:intern-high")
        let internLow = MatchFixtures.job(identityKey: "manual:intern-low", intakeMethod: .manual)
        repository.cachedJobsResult = .success([internLow, fullTimeHigh, internHigh])

        let provider = FakeMatchProvider()
        provider.results = [
            "remotive:full": MatchFixtures.result(score: 99),
            "remotive:intern-high": MatchFixtures.result(score: 80),
            "manual:intern-low": MatchFixtures.result(score: 60, band: .medium),
        ]
        let viewModel = DiscoverViewModel(
            jobRepository: repository,
            dateProvider: makeDateProvider(),
            matchProvider: provider
        )
        viewModel.loadCachedJobs()

        viewModel.onlyInternships = true

        #expect(viewModel.eligibleJobs.map(\.job.identityKey) == [
            "remotive:intern-high", "manual:intern-low",
        ])
        #expect(viewModel.ineligibleJobs.isEmpty)
        #expect(provider.evaluateJobsCalls.count == 1)
        #expect(viewModel.remotiveCount == 2)
        #expect(viewModel.manualCount == 1)
    }

    @Test func ineligibleExpansionShowsTheFirstFourThenAll() {
        let repository = FakeJobRepository()
        let jobs = (0..<6).map { index in
            MatchFixtures.job(
                identityKey: "remotive:\(index)",
                title: "iOS Engineer",
                createdAt: Date(timeIntervalSince1970: TimeInterval(100 + index)),
                jobType: "full_time"
            )
        }
        repository.cachedJobsResult = .success(jobs)
        let provider = FakeMatchProvider()
        provider.results = Dictionary(uniqueKeysWithValues: jobs.map { job in
            (job.identityKey, MatchFixtures.result(
                score: nil,
                band: nil,
                eligibility: .ineligible(reason: .notInternship)
            ))
        })
        let viewModel = DiscoverViewModel(
            jobRepository: repository,
            dateProvider: makeDateProvider(),
            matchProvider: provider
        )
        viewModel.loadCachedJobs()

        #expect(viewModel.ineligibleJobs.count == 6)
        #expect(viewModel.visibleIneligibleJobs.count == 4)
        #expect(viewModel.hasMoreIneligible)
        #expect(viewModel.isShowingAllIneligible == false)

        viewModel.toggleIneligibleExpansion()

        #expect(viewModel.isShowingAllIneligible)
        #expect(viewModel.visibleIneligibleJobs.count == 6)

        viewModel.toggleIneligibleExpansion()

        #expect(viewModel.isShowingAllIneligible == false)
        #expect(viewModel.visibleIneligibleJobs.count == 4)
    }

    @Test func loadCachedJobsRecomputesMatchesOnEveryLoad() {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([
            MatchFixtures.job(identityKey: "manual:a"),
        ])
        let provider = FakeMatchProvider()
        provider.results = ["manual:a": MatchFixtures.result(score: 80)]
        let viewModel = DiscoverViewModel(
            jobRepository: repository,
            dateProvider: makeDateProvider(),
            matchProvider: provider
        )

        viewModel.loadCachedJobs()
        viewModel.loadCachedJobs()

        #expect(provider.evaluateJobsCalls.count == 2)
    }
}
