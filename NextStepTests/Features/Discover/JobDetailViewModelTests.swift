import Foundation
import SwiftData
import Testing
@testable import NextStep

@Suite("JobDetailViewModel")
struct JobDetailViewModelTests {
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

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))!
    }

    private let jobID = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
    private let applicationID = UUID(uuidString: "00000000-0000-0000-0000-000000000121")!

    private func makePosting(
        title: String = "iOS 开发实习生",
        companyName: String = "星舟科技",
        intakeMethod: JobIntakeMethod = .manual,
        jobURL: URL? = URL(string: "https://example.com/jobs/21"),
        location: String? = "上海",
        jobType: String? = "internship"
    ) -> JobPosting {
        JobPosting(
            id: jobID,
            identityKey: "\(intakeMethod.rawValue):\(jobID.uuidString.lowercased())",
            title: title,
            companyName: companyName,
            intakeMethod: intakeMethod,
            descriptionPlainText: "参与 iOS 开发",
            createdAt: now,
            jobURL: jobURL,
            location: location,
            jobType: jobType,
            tags: ["Swift"]
        )
    }

    private func makeApplication(
        id: UUID = UUID(),
        status: ApplicationStatus,
        jobPosting: JobPosting
    ) -> Application {
        Application(
            id: id,
            companyName: jobPosting.companyName,
            roleTitle: jobPosting.title,
            status: status,
            createdAt: now,
            jobPosting: jobPosting
        )
    }

    private func makeViewModel(
        jobRepository: FakeJobRepository,
        applicationRepository: FakeApplicationRepository,
        matchProvider: (any MatchProviding)? = nil
    ) -> JobDetailViewModel {
        JobDetailViewModel(
            jobRepository: jobRepository,
            applicationRepository: applicationRepository,
            dateProvider: FixedDateProvider(now: now, calendar: calendar),
            jobID: jobID,
            matchProvider: matchProvider
        )
    }

    @Test func loadWithNoApplicationsOffersImport() {
        let posting = makePosting()
        let jobRepository = FakeJobRepository()
        jobRepository.cachedJobsResult = .success([posting])
        let applications = FakeApplicationRepository()
        let viewModel = makeViewModel(
            jobRepository: jobRepository,
            applicationRepository: applications
        )

        viewModel.load()

        #expect(viewModel.job === posting)
        #expect(viewModel.importAction == .importNew)
    }

    @Test(arguments: [
        ApplicationStatus.wishlist,
        .applied,
        .oa,
        .interview,
    ])
    func loadWithActiveApplicationOffersViewingIt(status: ApplicationStatus) {
        let posting = makePosting()
        let jobRepository = FakeJobRepository()
        jobRepository.cachedJobsResult = .success([posting])
        let applications = FakeApplicationRepository()
        applications.applicationsForJob = [
            makeApplication(id: applicationID, status: status, jobPosting: posting),
        ]
        let viewModel = makeViewModel(
            jobRepository: jobRepository,
            applicationRepository: applications
        )

        viewModel.load()

        #expect(viewModel.importAction == .viewExisting(applicationID: applicationID))
    }

    @Test(arguments: [
        ApplicationStatus.offer,
        .rejected,
        .withdrawn,
    ])
    func loadWithOnlyTerminalApplicationOffersReimport(status: ApplicationStatus) {
        let posting = makePosting()
        let jobRepository = FakeJobRepository()
        jobRepository.cachedJobsResult = .success([posting])
        let applications = FakeApplicationRepository()
        applications.applicationsForJob = [
            makeApplication(status: status, jobPosting: posting),
        ]
        let viewModel = makeViewModel(
            jobRepository: jobRepository,
            applicationRepository: applications
        )

        viewModel.load()

        #expect(viewModel.importAction == .importAgain)
        #expect(viewModel.importRequiresConfirmation)
    }

    @Test func activeApplicationBeatsTerminalOnes() {
        let posting = makePosting()
        let jobRepository = FakeJobRepository()
        jobRepository.cachedJobsResult = .success([posting])
        let applications = FakeApplicationRepository()
        applications.applicationsForJob = [
            makeApplication(status: .rejected, jobPosting: posting),
            makeApplication(id: applicationID, status: .interview, jobPosting: posting),
            makeApplication(status: .offer, jobPosting: posting),
        ]
        let viewModel = makeViewModel(
            jobRepository: jobRepository,
            applicationRepository: applications
        )

        viewModel.load()

        #expect(viewModel.importAction == .viewExisting(applicationID: applicationID))
        #expect(viewModel.importRequiresConfirmation == false)
    }

    @Test func importingFromNewCreatesSnapshotLinkedToPosting() throws {
        let posting = makePosting()
        let jobRepository = FakeJobRepository()
        jobRepository.cachedJobsResult = .success([posting])
        let applications = FakeApplicationRepository()
        let createdID = applications.createdApplicationID
        let viewModel = makeViewModel(
            jobRepository: jobRepository,
            applicationRepository: applications
        )
        viewModel.load()

        let returnedID = viewModel.importApplication()

        #expect(returnedID == createdID)
        #expect(applications.createCalls.count == 1)
        let call = try #require(applications.createCalls.first)
        #expect(call.companyName == "星舟科技")
        #expect(call.roleTitle == "iOS 开发实习生")
        #expect(call.initialStatus == .wishlist)
        #expect(call.statusDate == now)
        #expect(call.deadline == nil)
        #expect(call.notes == nil)
        #expect(call.jobURL == URL(string: "https://example.com/jobs/21"))
        #expect(call.location == "上海")
        #expect(call.jobPosting === posting)
        #expect(viewModel.importAction == .viewExisting(applicationID: createdID))
        #expect(viewModel.importErrorMessage == nil)
        #expect(viewModel.isImporting == false)
    }

    @Test func reimportRequiresConfirmationBeforeCreating() throws {
        let posting = makePosting()
        let jobRepository = FakeJobRepository()
        jobRepository.cachedJobsResult = .success([posting])
        let applications = FakeApplicationRepository()
        applications.applicationsForJob = [
            makeApplication(status: .rejected, jobPosting: posting),
        ]
        let viewModel = makeViewModel(
            jobRepository: jobRepository,
            applicationRepository: applications
        )
        viewModel.load()

        let unconfirmedID = viewModel.importApplication()

        #expect(unconfirmedID == nil)
        #expect(applications.createCalls.isEmpty)
        #expect(viewModel.importAction == .importAgain)

        let confirmedID = try #require(viewModel.importApplication(confirmed: true))

        #expect(confirmedID == applications.createdApplicationID)
        #expect(applications.createCalls.count == 1)
        #expect(viewModel.importAction == .viewExisting(applicationID: confirmedID))
    }

    @Test func activeApplicationNeverCreatesADuplicate() {
        let posting = makePosting()
        let jobRepository = FakeJobRepository()
        jobRepository.cachedJobsResult = .success([posting])
        let applications = FakeApplicationRepository()
        applications.applicationsForJob = [
            makeApplication(id: applicationID, status: .applied, jobPosting: posting),
        ]
        let viewModel = makeViewModel(
            jobRepository: jobRepository,
            applicationRepository: applications
        )
        viewModel.load()

        let importedID = viewModel.importApplication(confirmed: true)

        #expect(importedID == nil)
        #expect(applications.createCalls.isEmpty)
    }

    @Test func loadWithMissingPostingShowsChineseNotFoundCopy() {
        let jobRepository = FakeJobRepository()
        jobRepository.cachedJobsResult = .success([])
        let viewModel = makeViewModel(
            jobRepository: jobRepository,
            applicationRepository: FakeApplicationRepository()
        )

        viewModel.load()

        #expect(viewModel.job == nil)
        #expect(viewModel.state.error is JobDetailLoadError)
        #expect(viewModel.loadErrorMessage == "岗位不存在或已被删除")
    }

    @Test func loadFailureShowsChineseRetryCopy() {
        let jobRepository = FakeJobRepository()
        jobRepository.cachedJobsResult = .failure(RepositoryError.loadFailed)
        let viewModel = makeViewModel(
            jobRepository: jobRepository,
            applicationRepository: FakeApplicationRepository()
        )

        viewModel.load()

        #expect(viewModel.state.error is RepositoryError)
        #expect(viewModel.loadErrorMessage == "加载失败，请稍后重试")
    }

    @Test func importFailureShowsChineseCopyAndKeepsTheImportState() {
        let posting = makePosting()
        let jobRepository = FakeJobRepository()
        jobRepository.cachedJobsResult = .success([posting])
        let applications = FakeApplicationRepository()
        applications.createError = RepositoryError.saveFailed
        let viewModel = makeViewModel(
            jobRepository: jobRepository,
            applicationRepository: applications
        )
        viewModel.load()

        let importedID = viewModel.importApplication()

        #expect(importedID == nil)
        #expect(viewModel.importErrorMessage == "保存失败，请重试")
        #expect(viewModel.importAction == .importNew)
        #expect(viewModel.isImporting == false)

        viewModel.clearImportError()
        #expect(viewModel.importErrorMessage == nil)
    }

    @Test func importWritesTheApplicationAndItsInitialStatusChange() throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        try withExtendedLifetime(container) {
            let posting = makePosting()
            container.mainContext.insert(posting)
            try container.mainContext.save()

            let jobRepository = FakeJobRepository()
            jobRepository.cachedJobsResult = .success([posting])
            let applicationRepository = SwiftDataApplicationRepository(
                context: container.mainContext,
                dateProvider: FixedDateProvider(now: now, calendar: calendar)
            )
            let viewModel = JobDetailViewModel(
                jobRepository: jobRepository,
                applicationRepository: applicationRepository,
                dateProvider: FixedDateProvider(now: now, calendar: calendar),
                jobID: jobID
            )
            viewModel.load()

            let applicationID = try #require(viewModel.importApplication())
            let stored = try applicationRepository.application(id: applicationID)
            let application = try #require(stored)

            #expect(application.companyName == posting.companyName)
            #expect(application.roleTitle == posting.title)
            #expect(application.status == .wishlist)
            #expect(application.jobURL == posting.jobURL)
            #expect(application.location == posting.location)
            #expect(application.jobPosting?.id == posting.id)

            let changes = try applicationRepository.statusChanges(for: application)
            #expect(changes.count == 1)
            let initial = try #require(changes.first)
            #expect(initial.fromStatus == nil)
            #expect(initial.toStatus == .wishlist)
            #expect(initial.changedAt == now)
        }
    }

    // MARK: - Match explanation

    @Test func loadPublishesTheReadyMatchResult() {
        let posting = makePosting()
        let jobRepository = FakeJobRepository()
        jobRepository.cachedJobsResult = .success([posting])
        let provider = FakeMatchProvider()
        let result = MatchFixtures.result(
            score: 85,
            band: .strong,
            matchedSkills: ["swift", "swiftui"],
            missingSkills: ["combine"]
        )
        provider.results = [posting.identityKey: result]
        let viewModel = makeViewModel(
            jobRepository: jobRepository,
            applicationRepository: FakeApplicationRepository(),
            matchProvider: provider
        )

        viewModel.load()

        #expect(viewModel.matchAvailability == .ready)
        #expect(viewModel.matchResult == result)
        #expect(provider.evaluateJobCalls.map(\.id) == [posting.id])
    }

    @Test func anUnmetProfileGateShowsProfileIncomplete() {
        let posting = makePosting()
        let jobRepository = FakeJobRepository()
        jobRepository.cachedJobsResult = .success([posting])
        let provider = FakeMatchProvider()
        provider.results = [:]
        let viewModel = makeViewModel(
            jobRepository: jobRepository,
            applicationRepository: FakeApplicationRepository(),
            matchProvider: provider
        )

        viewModel.load()

        #expect(viewModel.matchAvailability == .profileIncomplete)
        #expect(viewModel.matchResult == nil)
    }

    @Test func aMissingProviderShowsMatchUnavailable() {
        let posting = makePosting()
        let jobRepository = FakeJobRepository()
        jobRepository.cachedJobsResult = .success([posting])
        let viewModel = makeViewModel(
            jobRepository: jobRepository,
            applicationRepository: FakeApplicationRepository()
        )

        viewModel.load()

        #expect(viewModel.matchAvailability == .unavailable)
        #expect(viewModel.matchResult == nil)
    }

    @Test func aProviderFailureDegradesToUnavailableWithoutBlockingTheJob() {
        let posting = makePosting()
        let jobRepository = FakeJobRepository()
        jobRepository.cachedJobsResult = .success([posting])
        let provider = FakeMatchProvider()
        provider.evaluateError = RepositoryError.unavailable
        let viewModel = makeViewModel(
            jobRepository: jobRepository,
            applicationRepository: FakeApplicationRepository(),
            matchProvider: provider
        )

        viewModel.load()

        #expect(viewModel.job === posting)
        #expect(viewModel.matchAvailability == .unavailable)
        #expect(viewModel.matchResult == nil)
    }

    @Test func reloadRecomputesTheMatchResult() {
        let posting = makePosting()
        let jobRepository = FakeJobRepository()
        jobRepository.cachedJobsResult = .success([posting])
        let provider = FakeMatchProvider()
        provider.results = [posting.identityKey: MatchFixtures.result(score: 70, band: .medium)]
        let viewModel = makeViewModel(
            jobRepository: jobRepository,
            applicationRepository: FakeApplicationRepository(),
            matchProvider: provider
        )

        viewModel.load()
        viewModel.load()

        #expect(provider.evaluateJobCalls.count == 2)
    }
}
