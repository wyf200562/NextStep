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

    private func makeApplication(
        status: ApplicationStatus,
        deadline: Date? = nil,
        rounds: [InterviewRound] = [],
        jobPosting: JobPosting? = nil
    ) -> Application {
        let application = Application(
            id: applicationID,
            companyName: "星尘科技",
            roleTitle: "iOS 开发实习生",
            status: status,
            createdAt: past,
            lastModifiedAt: past,
            jobPosting: jobPosting,
            deadline: deadline
        )
        application.interviewRounds = rounds
        return application
    }

    private func makePosting() -> JobPosting {
        MatchFixtures.job(
            identityKey: "manual:application-detail",
            title: "iOS 开发实习生",
            companyName: "星尘科技",
            intakeMethod: .manual
        )
    }

    private func hoursLater(_ hours: Double) -> Date {
        now.addingTimeInterval(hours * 3_600)
    }

    private func round(
        id: Int,
        at date: Date,
        result: InterviewResult = .pending,
        label: String? = nil
    ) -> InterviewRound {
        InterviewRound(
            id: fixedID(id),
            scheduledAt: date,
            format: .video,
            result: result,
            label: label
        )
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    private func makeViewModel(
        fake: FakeApplicationRepository,
        application: Application? = nil,
        matchProvider: (any MatchProviding)? = nil
    ) -> ApplicationDetailViewModel {
        if let application {
            fake.storedApplications[application.id] = application
        }
        return ApplicationDetailViewModel(
            repository: fake,
            dateProvider: FixedDateProvider(now: now, calendar: calendar),
            applicationID: applicationID,
            matchProvider: matchProvider
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

    // MARK: - The node card

    @Test("the detail node is the same node the list row shows")
    func detailNodeMatchesTheListRow() {
        let application = makeApplication(
            status: .oa,
            deadline: hoursLater(72),
            rounds: [round(id: 2, at: hoursLater(72), label: "一面")]
        )
        let fake = FakeApplicationRepository()
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        let snapshot = ApplicationListBuilder.snapshot(
            for: .all,
            applications: [application],
            now: now,
            calendar: calendar
        )

        #expect(viewModel.nextNode != nil)
        #expect(viewModel.nextNode == snapshot.rows.first?.node)
    }

    @Test("a round sitting on the deadline supplies the node title")
    func nodeTitleComesFromTheRoundOnTheInstant() {
        let deadline = hoursLater(24)
        let application = makeApplication(
            status: .interview,
            deadline: deadline,
            rounds: [round(id: 1, at: deadline, label: "终面")]
        )
        let fake = FakeApplicationRepository()
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        #expect(viewModel.nextNode?.date == deadline)
        #expect(viewModel.nextNode?.title == "终面")
    }

    @Test("a round with a blank label supplies 「面试」")
    func nodeTitleFallsBackToInterviewForABlankLabel() {
        let deadline = hoursLater(24)
        let application = makeApplication(
            status: .interview,
            deadline: deadline,
            rounds: [round(id: 1, at: deadline, label: nil)]
        )
        let fake = FakeApplicationRepository()
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        #expect(viewModel.nextNode?.title == "面试")
    }

    @Test("no round on the deadline makes the node 「截止」")
    func nodeTitleIsDeadlineWithoutAMatchingRound() {
        let application = makeApplication(
            status: .oa,
            deadline: hoursLater(24),
            rounds: [round(id: 1, at: hoursLater(48), label: "二面")]
        )
        let fake = FakeApplicationRepository()
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        #expect(viewModel.nextNode?.title == "截止")
    }

    @Test("an ended application has no node even with a deadline", arguments: [ApplicationStatus.rejected, .withdrawn])
    func endedApplicationShowsNoNode(status: ApplicationStatus) {
        let fake = FakeApplicationRepository()
        let application = makeApplication(status: status, deadline: hoursLater(24))
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        #expect(viewModel.nextNode == nil)
    }

    @Test("an application without a deadline has no node")
    func applicationWithoutDeadlineHasNoNode() {
        let fake = FakeApplicationRepository()
        let application = makeApplication(
            status: .interview,
            deadline: nil,
            rounds: [round(id: 1, at: hoursLater(24), label: "一面")]
        )
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        #expect(viewModel.nextNode == nil)
    }

    @Test("a past deadline is still shown as an overdue node")
    func pastDeadlineStaysVisibleAndOverdue() {
        let deadline = past
        let application = makeApplication(status: .interview, deadline: deadline)
        let fake = FakeApplicationRepository()
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        #expect(viewModel.nextNode?.date == deadline)
        #expect(viewModel.nextNode?.isOverdue == true)
        #expect(viewModel.nextNode?.title == "截止")
    }

    // MARK: - Interview rounds

    @Test(
        "adding a future round asks about marking the application as interviewing for applied and oa",
        arguments: [ApplicationStatus.applied, .oa]
    )
    func futureRoundPromptsForAppliedAndOA(status: ApplicationStatus) {
        let fake = FakeApplicationRepository()
        let application = makeApplication(status: status)
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        let added = viewModel.addRound(
            scheduledAt: hoursLater(24),
            format: .video,
            label: "一面",
            contact: "王女士",
            notes: "线上会议",
            result: .pending
        )

        #expect(added)
        #expect(fake.roundAddCalls.count == 1)
        let call = fake.roundAddCalls.first
        #expect(call?.application === application)
        #expect(call?.scheduledAt == hoursLater(24))
        #expect(call?.format == .video)
        #expect(call?.label == "一面")
        #expect(call?.contact == "王女士")
        #expect(call?.notes == "线上会议")
        #expect(call?.result == .pending)
        #expect(application.interviewRounds.count == 1)
        #expect(viewModel.isPromptingMarkAsInterview)
        #expect(viewModel.actionErrorMessage == nil)
    }

    @Test(
        "adding a future round never prompts for other statuses",
        arguments: [ApplicationStatus.wishlist, .interview, .offer, .rejected, .withdrawn]
    )
    func futureRoundDoesNotPromptForOtherStatuses(status: ApplicationStatus) {
        let fake = FakeApplicationRepository()
        let application = makeApplication(status: status)
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        #expect(viewModel.addRound(
            scheduledAt: hoursLater(24),
            format: .phone,
            label: nil,
            contact: nil,
            notes: nil,
            result: .pending
        ))

        #expect(fake.roundAddCalls.count == 1)
        #expect(!viewModel.isPromptingMarkAsInterview)
    }

    @Test("a round that is not strictly in the future never prompts", arguments: [0.0, -3_600.0])
    func pastOrPresentRoundDoesNotPrompt(secondsFromNow: Double) {
        let fake = FakeApplicationRepository()
        let application = makeApplication(status: .applied)
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        #expect(viewModel.addRound(
            scheduledAt: now.addingTimeInterval(secondsFromNow),
            format: .onsite,
            label: nil,
            contact: nil,
            notes: nil,
            result: .pending
        ))

        #expect(!viewModel.isPromptingMarkAsInterview)
    }

    @Test("round text is trimmed and blank optionals become nil")
    func roundTextIsNormalized() {
        let fake = FakeApplicationRepository()
        let viewModel = makeViewModel(fake: fake, application: makeApplication(status: .applied))
        viewModel.load()

        #expect(viewModel.addRound(
            scheduledAt: hoursLater(24),
            format: .video,
            label: "  一面 ",
            contact: "   ",
            notes: "\n",
            result: .pending
        ))

        let call = fake.roundAddCalls.first
        #expect(call?.label == "一面")
        #expect(call?.contact == nil)
        #expect(call?.notes == nil)
    }

    @Test("a failed round save surfaces the Chinese retry copy and no prompt")
    func failingRoundSaveShowsRetryCopy() {
        let fake = FakeApplicationRepository()
        fake.roundAddError = RepositoryError.saveFailed
        let application = makeApplication(status: .applied)
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        let added = viewModel.addRound(
            scheduledAt: hoursLater(24),
            format: .video,
            label: nil,
            contact: nil,
            notes: nil,
            result: .pending
        )

        #expect(added == false)
        #expect(viewModel.actionErrorMessage == "保存失败，请重试")
        #expect(!viewModel.isPromptingMarkAsInterview)
    }

    @Test("confirming the prompt changes the status to interview through the repository")
    func confirmingPromptChangesStatus() {
        let fake = FakeApplicationRepository()
        let application = makeApplication(status: .applied)
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()
        #expect(viewModel.addRound(
            scheduledAt: hoursLater(24),
            format: .video,
            label: "一面",
            contact: nil,
            notes: nil,
            result: .pending
        ))
        #expect(viewModel.isPromptingMarkAsInterview)

        let confirmed = viewModel.confirmMarkAsInterview()

        #expect(confirmed)
        #expect(!viewModel.isPromptingMarkAsInterview)
        #expect(fake.statusChangeCalls.count == 1)
        let call = fake.statusChangeCalls.first
        #expect(call?.application === application)
        #expect(call?.toStatus == .interview)
        #expect(call?.note == nil)
        #expect(call?.date == now)
        #expect(application.status == .interview)
        #expect(viewModel.actionErrorMessage == nil)
    }

    @Test("confirming without a pending prompt does nothing")
    func confirmingWithoutPromptDoesNothing() {
        let fake = FakeApplicationRepository()
        let viewModel = makeViewModel(fake: fake, application: makeApplication(status: .applied))
        viewModel.load()

        #expect(viewModel.confirmMarkAsInterview() == false)

        #expect(fake.statusChangeCalls.isEmpty)
    }

    @Test("cancelling the prompt leaves status and history untouched")
    func cancellingPromptChangesNothing() {
        let fake = FakeApplicationRepository()
        let application = makeApplication(status: .oa)
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()
        #expect(viewModel.addRound(
            scheduledAt: hoursLater(24),
            format: .video,
            label: nil,
            contact: nil,
            notes: nil,
            result: .pending
        ))

        viewModel.cancelMarkAsInterviewPrompt()

        #expect(!viewModel.isPromptingMarkAsInterview)
        #expect(fake.statusChangeCalls.isEmpty)
        #expect(application.status == .oa)
        #expect(application.interviewRounds.count == 1)
    }

    @Test("updating a round saves the fields and never prompts or changes status")
    func updateRoundSavesWithoutStatusChange() {
        let fake = FakeApplicationRepository()
        let original = round(id: 1, at: hoursLater(24), label: "一面")
        let application = makeApplication(status: .applied, rounds: [original])
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        let updated = viewModel.updateRound(
            original,
            scheduledAt: hoursLater(48),
            format: .onsite,
            label: "  二面 ",
            contact: "   ",
            notes: " 带简历 ",
            result: .passed
        )

        #expect(updated)
        #expect(fake.roundUpdateCalls.count == 1)
        let call = fake.roundUpdateCalls.first
        #expect(call?.round === original)
        #expect(call?.scheduledAt == hoursLater(48))
        #expect(call?.format == .onsite)
        #expect(call?.label == "二面")
        #expect(call?.contact == nil)
        #expect(call?.notes == "带简历")
        #expect(call?.result == .passed)
        #expect(original.result == .passed)
        #expect(application.status == .applied)
        #expect(!viewModel.isPromptingMarkAsInterview)
    }

    @Test("a failed round update maps to the Chinese retry copy")
    func failingRoundUpdateShowsRetryCopy() {
        let fake = FakeApplicationRepository()
        fake.roundUpdateError = RepositoryError.saveFailed
        let existing = round(id: 1, at: hoursLater(24), label: "一面")
        let viewModel = makeViewModel(
            fake: fake,
            application: makeApplication(status: .oa, rounds: [existing])
        )
        viewModel.load()

        #expect(viewModel.updateRound(
            existing,
            scheduledAt: hoursLater(48),
            format: .video,
            label: nil,
            contact: nil,
            notes: nil,
            result: .failed
        ) == false)

        #expect(viewModel.actionErrorMessage == "保存失败，请重试")
    }

    @Test("deleting a round goes through the repository and leaves status untouched")
    func deleteRoundLeavesStatusUntouched() {
        let fake = FakeApplicationRepository()
        let first = round(id: 1, at: hoursLater(24), label: "一面")
        let second = round(id: 2, at: hoursLater(48), label: "二面")
        let application = makeApplication(status: .interview, rounds: [first, second])
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        #expect(viewModel.deleteRound(first))

        #expect(fake.roundDeleteCalls.count == 1)
        #expect(fake.roundDeleteCalls.first === first)
        #expect(application.interviewRounds.map(\.id) == [fixedID(2)])
        #expect(application.status == .interview)
        #expect(!viewModel.isPromptingMarkAsInterview)
    }

    @Test("a failed round delete maps to the Chinese retry copy")
    func failingRoundDeleteShowsRetryCopy() {
        let fake = FakeApplicationRepository()
        fake.roundDeleteError = RepositoryError.saveFailed
        let existing = round(id: 1, at: hoursLater(24), label: "一面")
        let application = makeApplication(status: .oa, rounds: [existing])
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        #expect(viewModel.deleteRound(existing) == false)

        #expect(viewModel.actionErrorMessage == "删除失败，请重试")
        #expect(application.interviewRounds.count == 1)
    }

    @Test("rounds sort by scheduled time ascending and tie-break by id")
    func roundsSortByScheduledTimeThenID() {
        let fake = FakeApplicationRepository()
        let application = makeApplication(
            status: .interview,
            rounds: [
                round(id: 30, at: hoursLater(30), label: "三面"),
                round(id: 20, at: hoursLater(2), label: "同时间较大 id"),
                round(id: 10, at: hoursLater(2), label: "同时间较小 id"),
                round(id: 40, at: now.addingTimeInterval(-3_600), label: "过去"),
            ]
        )
        let viewModel = makeViewModel(fake: fake, application: application)
        viewModel.load()

        #expect(viewModel.rounds.map(\.id) == [fixedID(40), fixedID(10), fixedID(20), fixedID(30)])
    }

    // MARK: - Associated job match

    @Test func loadComputesTheAssociatedJobMatchOnDemand() {
        let posting = makePosting()
        let application = makeApplication(status: .applied, jobPosting: posting)
        let fake = FakeApplicationRepository()
        let provider = FakeMatchProvider()
        let result = MatchFixtures.result(
            score: 82,
            band: .strong,
            matchedSkills: ["swift"],
            missingSkills: ["combine"]
        )
        provider.results = [posting.identityKey: result]
        let viewModel = makeViewModel(
            fake: fake,
            application: application,
            matchProvider: provider
        )

        viewModel.load()

        #expect(viewModel.matchAvailability == .ready)
        #expect(viewModel.matchResult == result)
        #expect(provider.evaluateJobCalls.map(\.id) == [posting.id])
    }

    @Test func profileIncompleteHidesTheSummaryButKeepsTheApplicationLoaded() {
        let posting = makePosting()
        let application = makeApplication(status: .applied, jobPosting: posting)
        let fake = FakeApplicationRepository()
        let provider = FakeMatchProvider()
        provider.results = [:]
        let viewModel = makeViewModel(
            fake: fake,
            application: application,
            matchProvider: provider
        )

        viewModel.load()

        #expect(viewModel.state.value === application)
        #expect(viewModel.matchAvailability == .profileIncomplete)
        #expect(viewModel.matchResult == nil)
    }

    @Test func aMissingProviderShowsMatchUnavailable() {
        let posting = makePosting()
        let application = makeApplication(status: .applied, jobPosting: posting)
        let viewModel = makeViewModel(fake: FakeApplicationRepository(), application: application)

        viewModel.load()

        #expect(viewModel.matchAvailability == .unavailable)
        #expect(viewModel.matchResult == nil)
    }

    @Test func anApplicationWithoutAnAssociatedPostingSkipsMatchEvaluation() {
        let application = makeApplication(status: .applied)
        let provider = FakeMatchProvider()
        let viewModel = makeViewModel(
            fake: FakeApplicationRepository(),
            application: application,
            matchProvider: provider
        )

        viewModel.load()

        #expect(provider.evaluateJobCalls.isEmpty)
        #expect(viewModel.matchResult == nil)
    }

    @Test func aProviderFailureDegradesToUnavailableWithoutBlockingTheApplication() {
        let posting = makePosting()
        let application = makeApplication(status: .applied, jobPosting: posting)
        let provider = FakeMatchProvider()
        provider.evaluateError = RepositoryError.unavailable
        let viewModel = makeViewModel(
            fake: FakeApplicationRepository(),
            application: application,
            matchProvider: provider
        )

        viewModel.load()

        #expect(viewModel.state.value === application)
        #expect(viewModel.matchAvailability == .unavailable)
    }

    @Test func refreshRecomputesTheAssociatedJobMatch() {
        let posting = makePosting()
        let application = makeApplication(status: .applied, jobPosting: posting)
        let provider = FakeMatchProvider()
        provider.results = [posting.identityKey: MatchFixtures.result(score: 75)]
        let viewModel = makeViewModel(
            fake: FakeApplicationRepository(),
            application: application,
            matchProvider: provider
        )

        viewModel.load()
        viewModel.refresh()

        #expect(provider.evaluateJobCalls.count == 2)
    }
}
