import Foundation
import Testing
@testable import NextStep

@Suite("ApplicationDetailViewModel")
struct ApplicationDetailViewModelTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))!
    }

    private var past: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9))!
    }

    private let applicationID = UUID(uuidString: "00000000-0000-0000-0000-000000000014")!

    /// Independent transcription of the spec §2 targets, in canonical order.
    private nonisolated static let expectedTargets: [ApplicationStatus: [ApplicationStatus]] = [
        .wishlist: [.applied, .withdrawn],
        .applied: [.wishlist, .oa, .interview, .offer, .rejected, .withdrawn],
        .oa: [.wishlist, .applied, .interview, .offer, .rejected, .withdrawn],
        .interview: [.wishlist, .applied, .oa, .offer, .rejected, .withdrawn],
        .offer: [],
        .rejected: [.applied, .oa, .interview, .offer],
        .withdrawn: [.wishlist, .applied, .oa, .interview, .offer],
    ]

    private func makeApplication(status: ApplicationStatus) -> Application {
        Application(
            id: applicationID,
            companyName: "星尘科技",
            roleTitle: "iOS 开发实习生",
            status: status,
            createdAt: past,
            lastModifiedAt: past
        )
    }

    private func makeViewModel(
        fake: FakeApplicationRepository,
        application: Application? = nil
    ) -> ApplicationDetailViewModel {
        if let application {
            fake.storedApplications[application.id] = application
        }
        return ApplicationDetailViewModel(
            repository: fake,
            dateProvider: FixedDateProvider(now: now, calendar: calendar),
            applicationID: applicationID
        )
    }

    @Test("load moves from idle to loaded or failed")
    func loadExposesTheApplication() {
        let application = makeApplication(status: .applied)
        let fake = FakeApplicationRepository()
        let viewModel = makeViewModel(fake: fake, application: application)

        viewModel.load()

        #expect(viewModel.state.value === application)

        let failingFake = FakeApplicationRepository()
        failingFake.applicationLoadError = RepositoryError.loadFailed
        let failing = makeViewModel(fake: failingFake)
        failing.load()
        #expect(failing.state.error as? RepositoryError == .loadFailed)

        let missingFake = FakeApplicationRepository()
        let missing = makeViewModel(fake: missingFake)
        missing.load()
        #expect(missing.state.error as? RepositoryError == .loadFailed)
    }

    @Test("targets list only the state machine's allowed statuses", arguments: ApplicationStatus.allCases)
    func targetsMatchAllowedStatuses(status: ApplicationStatus) {
        let fake = FakeApplicationRepository()
        let application = makeApplication(status: status)
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        #expect(viewModel.targets == Self.expectedTargets[status])
    }

    @Test("confirmation is required for backward moves and reopens only")
    func confirmationFlagsMatchSpec() {
        let appliedFake = FakeApplicationRepository()
        let applied = makeViewModel(fake: appliedFake, application: makeApplication(status: .applied))
        applied.load()
        #expect(applied.requiresConfirmation(to: .wishlist))
        #expect(!applied.requiresConfirmation(to: .oa))
        #expect(!applied.requiresConfirmation(to: .offer))

        let interviewFake = FakeApplicationRepository()
        let interview = makeViewModel(fake: interviewFake, application: makeApplication(status: .interview))
        interview.load()
        #expect(interview.requiresConfirmation(to: .applied))
        #expect(interview.requiresConfirmation(to: .oa))
        #expect(!interview.requiresConfirmation(to: .offer))

        let rejectedFake = FakeApplicationRepository()
        let rejected = makeViewModel(fake: rejectedFake, application: makeApplication(status: .rejected))
        rejected.load()
        #expect(rejected.requiresConfirmation(to: .applied))
        #expect(rejected.requiresConfirmation(to: .offer))

        let withdrawnFake = FakeApplicationRepository()
        let withdrawn = makeViewModel(fake: withdrawnFake, application: makeApplication(status: .withdrawn))
        withdrawn.load()
        #expect(withdrawn.requiresConfirmation(to: .wishlist))
        #expect(!withdrawn.requiresConfirmation(to: .rejected))
    }

    @Test("offer is terminal: no targets and no status change")
    func offerIsTerminal() {
        let fake = FakeApplicationRepository()
        let application = makeApplication(status: .offer)
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        #expect(viewModel.targets.isEmpty)
        #expect(viewModel.changeStatus(to: .applied, note: nil) == false)
        #expect(viewModel.actionErrorMessage == "当前状态不能这样变更")
        #expect(fake.statusChangeCalls.isEmpty)
    }

    @Test("a valid change goes through the repository with a trimmed note and refreshes")
    func successfulChangeUpdatesTheApplication() {
        let fake = FakeApplicationRepository()
        let application = makeApplication(status: .applied)
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        let changed = viewModel.changeStatus(to: .oa, note: " 约了笔试 ")

        #expect(changed)
        #expect(fake.statusChangeCalls.count == 1)
        let call = fake.statusChangeCalls.first
        #expect(call?.application === application)
        #expect(call?.toStatus == .oa)
        #expect(call?.note == "约了笔试")
        #expect(call?.date == now)
        #expect(application.status == .oa)
        #expect(viewModel.application?.status == .oa)
        #expect(viewModel.actionErrorMessage == nil)
    }

    @Test("a blank note is passed as nil")
    func blankNoteBecomesNil() {
        let fake = FakeApplicationRepository()
        let application = makeApplication(status: .applied)
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        #expect(viewModel.changeStatus(to: .oa, note: "   \n"))

        #expect(fake.statusChangeCalls.first?.note == nil)
    }

    @Test("an illegal transition is rejected without calling the repository")
    func illegalTransitionShowsChineseCopy() {
        let fake = FakeApplicationRepository()
        let application = makeApplication(status: .wishlist)
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        let changed = viewModel.changeStatus(to: .offer, note: "跳级")

        #expect(changed == false)
        #expect(viewModel.actionErrorMessage == "当前状态不能这样变更")
        #expect(fake.statusChangeCalls.isEmpty)
        #expect(application.status == .wishlist)
    }

    @Test("a typed transition error from the repository maps to the Chinese copy")
    func repositoryTransitionErrorMapsToChineseCopy() {
        let fake = FakeApplicationRepository()
        fake.statusChangeError = ApplicationTransitionError(from: .applied, to: .oa)
        let application = makeApplication(status: .applied)
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        let changed = viewModel.changeStatus(to: .oa, note: nil)

        #expect(changed == false)
        #expect(viewModel.actionErrorMessage == "当前状态不能这样变更")
    }

    @Test("a save failure maps to the Chinese retry copy")
    func saveFailureShowsRetryCopy() {
        let fake = FakeApplicationRepository()
        fake.statusChangeError = RepositoryError.saveFailed
        let application = makeApplication(status: .applied)
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        let changed = viewModel.changeStatus(to: .oa, note: nil)

        #expect(changed == false)
        #expect(viewModel.actionErrorMessage == "保存失败，请重试")
    }

    @Test("delete goes through the repository")
    func deleteSucceeds() {
        let fake = FakeApplicationRepository()
        let application = makeApplication(status: .wishlist)
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        #expect(viewModel.delete())

        #expect(fake.deleteCalls.count == 1)
        #expect(fake.deleteCalls.first === application)
        #expect(viewModel.actionErrorMessage == nil)
    }

    @Test("a delete failure maps to the Chinese retry copy and keeps the record")
    func deleteFailureShowsRetryCopy() {
        let fake = FakeApplicationRepository()
        fake.deleteError = RepositoryError.saveFailed
        let application = makeApplication(status: .wishlist)
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        #expect(viewModel.delete() == false)

        #expect(viewModel.actionErrorMessage == "删除失败，请重试")
        #expect(viewModel.application === application)
    }
}
