import Foundation
import Testing
@testable import NextStep

@Suite("DiscoverViewModel")
struct DiscoverViewModelTests {
    @MainActor
    private final class FakeJobRepository: JobRepository {
        var cachedJobsResult: Result<[JobPosting], any Error> = .success([])
        private(set) var cachedJobsCallCount = 0
        var refreshResult: RefreshOutcome = .failed(error: RepositoryError.unavailable, cachedCount: 0)
        private(set) var refreshQueries: [JobQuery] = []
        var refreshEffect: (@MainActor () -> Void)?
        var lastRefreshAtBySource: [JobIntakeMethod: Date] = [:]

        func cachedJobs() throws -> [JobPosting] {
            cachedJobsCallCount += 1
            return try cachedJobsResult.get()
        }

        func refreshDiscover(query: JobQuery) async -> RefreshOutcome {
            refreshQueries.append(query)
            refreshEffect?()
            return refreshResult
        }

        func importManual(_ input: ManualJobInput) async throws -> JobPosting {
            throw RepositoryError.unavailable
        }

        func lastRefreshAt(for source: JobIntakeMethod) -> Date? {
            lastRefreshAtBySource[source]
        }
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

    // MARK: - Refresh flow

    struct RefreshMessageCase: Sendable {
        let error: JobSourceError
        let message: String
    }

    private func makeRefreshingViewModel(
        _ repository: FakeJobRepository,
        provider: (any MatchProviding)? = nil
    ) -> DiscoverViewModel {
        DiscoverViewModel(
            jobRepository: repository,
            dateProvider: makeDateProvider(),
            matchProvider: provider
        )
    }

    @Test func automaticRefreshWithNoCacheLoadsTheRemoteSample() async {
        let repository = FakeJobRepository()
        let refreshedJobs = [
            makePosting(title: "Remotive Intern", intakeMethod: .remotive, jobType: "internship"),
            makePosting(title: "Remotive Full Time", intakeMethod: .remotive, jobType: "full_time"),
        ]
        repository.cachedJobsResult = .success([])
        repository.refreshResult = .refreshed(added: 2, updated: 0)
        repository.refreshEffect = {
            repository.cachedJobsResult = .success(refreshedJobs)
            repository.lastRefreshAtBySource[.remotive] = self.fixedNow
        }
        let viewModel = makeRefreshingViewModel(repository)

        await viewModel.loadAndRefreshIfNeeded()

        #expect(repository.refreshQueries == [JobQuery()])
        #expect(viewModel.jobs.count == 2)
        #expect(viewModel.remotiveCount == 2)
        #expect(viewModel.refreshState == .refreshed(added: 2, updated: 0))
        #expect(viewModel.lastRefreshSummary == "本次刷新 2 条")
        #expect(viewModel.lastRefreshAt == fixedNow)
        #expect(viewModel.isRefreshing == false)
        #expect(viewModel.refreshNotice == nil)
        #expect(viewModel.blockingRefreshPrompt == nil)
    }

    @Test func automaticRefreshWithinSixHoursUsesOnlyTheCache() async {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([
            makePosting(title: "Cached Intern", intakeMethod: .remotive, jobType: "internship"),
        ])
        repository.lastRefreshAtBySource[.remotive] = fixedNow.addingTimeInterval(-6 * 3_600 + 1)
        let viewModel = makeRefreshingViewModel(repository)

        await viewModel.loadAndRefreshIfNeeded()

        #expect(repository.refreshQueries.isEmpty)
        #expect(viewModel.jobs.count == 1)
        #expect(viewModel.refreshState == .skipped(.fresh))
        #expect(viewModel.refreshNotice == nil)
        #expect(viewModel.blockingRefreshPrompt == nil)
        #expect(viewModel.lastRefreshAt == fixedNow.addingTimeInterval(-6 * 3_600 + 1))
    }

    @Test func automaticRefreshAtTheSixHourBoundaryCallsTheRepository() async {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([
            makePosting(title: "Cached Intern", intakeMethod: .remotive, jobType: "internship"),
        ])
        repository.lastRefreshAtBySource[.remotive] = fixedNow.addingTimeInterval(-6 * 3_600)
        repository.refreshResult = .refreshed(added: 0, updated: 1)
        let viewModel = makeRefreshingViewModel(repository)

        await viewModel.loadAndRefreshIfNeeded()

        #expect(repository.refreshQueries.count == 1)
        #expect(viewModel.refreshState == .refreshed(added: 0, updated: 1))
    }

    @Test func automaticRefreshWithAnEmptyCacheIgnoresARecentSuccess() async {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([])
        repository.lastRefreshAtBySource[.remotive] = fixedNow
        repository.refreshResult = .refreshed(added: 0, updated: 0)
        let viewModel = makeRefreshingViewModel(repository)

        await viewModel.loadAndRefreshIfNeeded()

        #expect(repository.refreshQueries.count == 1)
    }

    @Test func pullToRefreshIgnoresTheSixHourTtl() async {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([
            makePosting(title: "Cached Intern", intakeMethod: .remotive, jobType: "internship"),
        ])
        repository.lastRefreshAtBySource[.remotive] = fixedNow.addingTimeInterval(-60)
        repository.refreshResult = .refreshed(added: 1, updated: 1)
        let viewModel = makeRefreshingViewModel(repository)
        viewModel.loadCachedJobs()

        await viewModel.refresh()

        #expect(repository.refreshQueries.count == 1)
        #expect(viewModel.refreshState == .refreshed(added: 1, updated: 1))
    }

    @Test func refreshedReloadsTheCacheAndRecomputesMatches() async {
        let repository = FakeJobRepository()
        let oldJob = MatchFixtures.job(identityKey: "remotive:old")
        repository.cachedJobsResult = .success([oldJob])
        repository.lastRefreshAtBySource[.remotive] = fixedNow.addingTimeInterval(-7 * 3_600)
        let newJob = MatchFixtures.job(identityKey: "remotive:new")
        repository.refreshResult = .refreshed(added: 1, updated: 0)
        repository.refreshEffect = {
            repository.cachedJobsResult = .success([newJob])
        }
        let provider = FakeMatchProvider()
        provider.results = [
            "remotive:old": MatchFixtures.result(score: 70),
            "remotive:new": MatchFixtures.result(score: 90),
        ]
        let viewModel = makeRefreshingViewModel(repository, provider: provider)

        await viewModel.loadAndRefreshIfNeeded()

        #expect(viewModel.jobs.map(\.identityKey) == ["remotive:new"])
        #expect(viewModel.eligibleJobs.first?.match?.score == 90)
        #expect(provider.evaluateJobsCalls.count == 2)
    }

    @Test func failedRefreshWithCacheKeepsBrowsingAndShowsANonBlockingNotice() async {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([
            makePosting(title: "Cached Intern", intakeMethod: .remotive, jobType: "internship"),
        ])
        repository.lastRefreshAtBySource[.remotive] = fixedNow.addingTimeInterval(-3_600)
        repository.refreshResult = .failed(error: JobSourceError.offline, cachedCount: 1)
        let viewModel = makeRefreshingViewModel(repository)
        viewModel.loadCachedJobs()

        await viewModel.refresh()

        #expect(viewModel.jobs.count == 1)
        let notice = viewModel.refreshNotice
        #expect(notice?.title == "今天没能刷新 · 显示 11 月 14 日的缓存")
        #expect(notice?.message == "网络不可用，请检查连接")
        #expect(viewModel.blockingRefreshPrompt == nil)
        #expect(viewModel.isRefreshing == false)
    }

    @Test func failedRefreshWithoutCacheShowsTheBlockingState() async {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([])
        repository.refreshResult = .failed(error: JobSourceError.timedOut, cachedCount: 0)
        let viewModel = makeRefreshingViewModel(repository)

        await viewModel.loadAndRefreshIfNeeded()

        #expect(viewModel.refreshNotice == nil)
        let blocking = viewModel.blockingRefreshPrompt
        #expect(blocking?.title == "暂时拿不到岗位")
        #expect(blocking?.message?.contains("请求超时，请稍后重试") == true)
        #expect(blocking?.message?.contains("手动粘贴") == true)
    }

    @Test func quotaExhaustedWithCacheShowsTheQuotaNotice() async {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([
            makePosting(title: "Cached Intern", intakeMethod: .remotive, jobType: "internship"),
        ])
        repository.lastRefreshAtBySource[.remotive] = fixedNow.addingTimeInterval(-3_600)
        repository.refreshResult = .skipped(reason: .quotaExhausted)
        let viewModel = makeRefreshingViewModel(repository)
        viewModel.loadCachedJobs()

        await viewModel.refresh()

        let notice = viewModel.refreshNotice
        #expect(notice?.title == "今天的刷新次数已用完 · 显示 11 月 14 日的缓存")
        #expect(notice?.message?.contains("配额明天恢复") == true)
        #expect(viewModel.blockingRefreshPrompt == nil)
    }

    @Test func tooSoonWithCacheShowsTheFrequencyNotice() async {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([
            makePosting(title: "Cached Intern", intakeMethod: .remotive, jobType: "internship"),
        ])
        repository.refreshResult = .skipped(reason: .tooSoon)
        let viewModel = makeRefreshingViewModel(repository)
        viewModel.loadCachedJobs()

        await viewModel.refresh()

        #expect(viewModel.refreshNotice?.title == "刷新太频繁，请稍后再试")
        #expect(viewModel.blockingRefreshPrompt == nil)
    }

    @Test func quotaExhaustedWithoutCacheShowsTheBlockingState() async {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([])
        repository.refreshResult = .skipped(reason: .quotaExhausted)
        let viewModel = makeRefreshingViewModel(repository)

        await viewModel.loadAndRefreshIfNeeded()

        let blocking = viewModel.blockingRefreshPrompt
        #expect(blocking?.title == "暂时拿不到岗位")
        #expect(blocking?.message?.contains("刷新次数已用完") == true)
        #expect(blocking?.message?.contains("配额明天恢复") == true)
        #expect(viewModel.refreshNotice == nil)
    }

    @Test func aFreshSkipShowsNoPrompt() async {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([])
        repository.refreshResult = .skipped(reason: .fresh)
        let viewModel = makeRefreshingViewModel(repository)

        await viewModel.loadAndRefreshIfNeeded()

        #expect(viewModel.refreshState == .skipped(.fresh))
        #expect(viewModel.refreshNotice == nil)
        #expect(viewModel.blockingRefreshPrompt == nil)
    }

    @Test func aCancelledRefreshShowsNoError() async {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([])
        repository.refreshResult = .failed(error: CancellationError(), cachedCount: 0)
        let viewModel = makeRefreshingViewModel(repository)

        await viewModel.loadAndRefreshIfNeeded()

        #expect(viewModel.refreshState == .idle)
        #expect(viewModel.refreshNotice == nil)
        #expect(viewModel.blockingRefreshPrompt == nil)
        #expect(viewModel.isRefreshing == false)
    }

    @Test(arguments: [
        RefreshMessageCase(error: .offline, message: "网络不可用，请检查连接"),
        RefreshMessageCase(error: .timedOut, message: "请求超时，请稍后重试"),
        RefreshMessageCase(error: .rateLimited, message: "请求过于频繁，请稍后再试"),
        RefreshMessageCase(error: .server(503), message: "服务器暂时不可用（HTTP 503）"),
        RefreshMessageCase(error: .decoding, message: "数据格式暂时无法识别"),
    ])
    func refreshFailureMapsTypedErrorsToChineseCopy(testCase: RefreshMessageCase) async {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([
            makePosting(title: "Cached Intern", intakeMethod: .remotive, jobType: "internship"),
        ])
        repository.refreshResult = .failed(error: testCase.error, cachedCount: 1)
        let viewModel = makeRefreshingViewModel(repository)
        viewModel.loadCachedJobs()

        await viewModel.refresh()

        #expect(viewModel.refreshNotice?.message == testCase.message)
    }

    @Test func anUnknownRefreshErrorUsesTheGenericChineseCopy() async {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([
            makePosting(title: "Cached Intern", intakeMethod: .remotive, jobType: "internship"),
        ])
        repository.refreshResult = .failed(error: RepositoryError.unavailable, cachedCount: 1)
        let viewModel = makeRefreshingViewModel(repository)
        viewModel.loadCachedJobs()

        await viewModel.refresh()

        #expect(viewModel.refreshNotice?.message == "加载失败，请稍后重试")
    }

    @Test func aFailureAfterASuccessClearsTheRefreshSummary() async {
        let repository = FakeJobRepository()
        repository.cachedJobsResult = .success([
            makePosting(title: "Cached Intern", intakeMethod: .remotive, jobType: "internship"),
        ])
        repository.refreshResult = .refreshed(added: 1, updated: 0)
        let viewModel = makeRefreshingViewModel(repository)

        await viewModel.refresh()
        #expect(viewModel.lastRefreshSummary == "本次刷新 1 条")

        repository.refreshResult = .failed(error: JobSourceError.offline, cachedCount: 1)
        await viewModel.refresh()

        #expect(viewModel.lastRefreshSummary == nil)
    }
}
