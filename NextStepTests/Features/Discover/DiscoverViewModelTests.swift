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
}
