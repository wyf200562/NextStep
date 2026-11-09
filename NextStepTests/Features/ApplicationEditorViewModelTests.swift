import Foundation
import Observation
import Testing
@testable import NextStep

@Suite("ApplicationEditorViewModel")
struct ApplicationEditorViewModelTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))!
    }

    private var pastStatusDate: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9))!
    }

    private func makeViewModel(
        fake: FakeApplicationRepository
    ) -> ApplicationEditorViewModel {
        ApplicationEditorViewModel(
            repository: fake,
            dateProvider: FixedDateProvider(now: now, calendar: calendar)
        )
    }

    private func fillRequiredFields(_ viewModel: ApplicationEditorViewModel) {
        viewModel.companyName = "星尘科技"
        viewModel.roleTitle = "iOS 开发实习生"
    }

    @Test("company and role are required after trimming")
    func requiredFieldsAreTrimmedAndValidated() {
        let fake = FakeApplicationRepository()
        let viewModel = makeViewModel(fake: fake)

        viewModel.save()

        #expect(viewModel.companyError == "请填写公司")
        #expect(viewModel.roleError == "请填写职位")
        #expect(fake.createCalls.isEmpty)
        #expect(viewModel.savedApplicationID == nil)

        viewModel.companyName = "  \n"
        viewModel.roleTitle = "\t"
        viewModel.save()
        #expect(viewModel.companyError == "请填写公司")
        #expect(viewModel.roleError == "请填写职位")
        #expect(fake.createCalls.isEmpty)

        viewModel.companyName = " 星尘科技 "
        viewModel.roleTitle = " iOS 开发实习生 "
        viewModel.save()

        #expect(viewModel.companyError == nil)
        #expect(viewModel.roleError == nil)
        #expect(fake.createCalls.count == 1)
        #expect(fake.createCalls.first?.companyName == "星尘科技")
        #expect(fake.createCalls.first?.roleTitle == "iOS 开发实习生")
    }

    @Test("a filled job URL must be a valid web URL")
    func jobURLMustBeValidWhenFilled() throws {
        let fake = FakeApplicationRepository()
        let viewModel = makeViewModel(fake: fake)
        fillRequiredFields(viewModel)

        for invalid in ["not a url", "example.com", "ftp://example.com"] {
            viewModel.jobURLText = invalid
            viewModel.save()
            #expect(viewModel.jobURLError == "请输入合法的岗位链接", "\(invalid) should be rejected")
            #expect(fake.createCalls.isEmpty)
        }

        viewModel.jobURLText = " https://example.com/jobs/7 "
        viewModel.save()

        #expect(viewModel.jobURLError == nil)
        #expect(fake.createCalls.count == 1)
        #expect(fake.createCalls.first?.jobURL == URL(string: "https://example.com/jobs/7"))
    }

    @Test("a deadline defaults to 09:00 and uses the chosen time only when enabled")
    func deadlineDefaultsToNineAM() throws {
        let deadlineDay = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 12))
        )

        let fakeWithoutDeadline = FakeApplicationRepository()
        let withoutDeadline = makeViewModel(fake: fakeWithoutDeadline)
        fillRequiredFields(withoutDeadline)
        withoutDeadline.hasDeadline = false
        withoutDeadline.deadlineDay = deadlineDay
        withoutDeadline.save()
        #expect(fakeWithoutDeadline.createCalls.first?.deadline == nil)

        let fakeDefaultTime = FakeApplicationRepository()
        let defaultTime = makeViewModel(fake: fakeDefaultTime)
        fillRequiredFields(defaultTime)
        defaultTime.hasDeadline = true
        defaultTime.deadlineDay = deadlineDay
        defaultTime.includesDeadlineTime = false
        defaultTime.save()
        #expect(
            fakeDefaultTime.createCalls.first?.deadline
                == calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 9))
        )

        let fakeChosenTime = FakeApplicationRepository()
        let chosenTime = makeViewModel(fake: fakeChosenTime)
        fillRequiredFields(chosenTime)
        chosenTime.hasDeadline = true
        chosenTime.deadlineDay = deadlineDay
        chosenTime.includesDeadlineTime = true
        chosenTime.deadlineTime = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 14, minute: 30))
        )
        chosenTime.save()
        #expect(
            fakeChosenTime.createCalls.first?.deadline
                == calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 14, minute: 30))
        )
    }

    @Test("the status date only applies when the initial status is not wishlist")
    func statusDateAppliesOnlyToNonWishlist() {
        let wishlistFake = FakeApplicationRepository()
        let wishlist = makeViewModel(fake: wishlistFake)
        fillRequiredFields(wishlist)
        wishlist.statusDate = pastStatusDate
        wishlist.save()

        #expect(wishlist.showsStatusDate == false)
        #expect(wishlistFake.createCalls.first?.statusDate == now)

        let appliedFake = FakeApplicationRepository()
        let applied = makeViewModel(fake: appliedFake)
        fillRequiredFields(applied)
        applied.initialStatus = .applied
        applied.statusDate = pastStatusDate
        applied.save()

        #expect(applied.showsStatusDate)
        #expect(appliedFake.createCalls.first?.initialStatus == .applied)
        #expect(appliedFake.createCalls.first?.statusDate == pastStatusDate)
    }

    @Test("a save failure shows the Chinese retry copy and leaves the form usable")
    func saveFailureShowsRetryCopy() {
        let fake = FakeApplicationRepository()
        fake.createError = RepositoryError.saveFailed
        let viewModel = makeViewModel(fake: fake)
        fillRequiredFields(viewModel)

        viewModel.save()

        #expect(viewModel.saveErrorMessage == "保存失败，请重试")
        #expect(viewModel.savedApplicationID == nil)
        #expect(viewModel.isSaving == false)
        #expect(fake.createCalls.count == 1)
    }

    @Test("a successful save trims optional text and exposes the new application id")
    func successfulSaveTrimsTextAndReturnsID() {
        let fake = FakeApplicationRepository()
        let viewModel = makeViewModel(fake: fake)
        fillRequiredFields(viewModel)
        viewModel.locationText = " 上海 "
        viewModel.notesText = " 内推 "

        viewModel.save()

        #expect(viewModel.savedApplicationID == fake.createdApplicationID)
        #expect(viewModel.saveErrorMessage == nil)
        #expect(fake.createCalls.first?.location == "上海")
        #expect(fake.createCalls.first?.notes == "内推")
    }

    @Test("the save button is busy during the repository call")
    func saveIsBusyDuringTheRepositoryCall() {
        let fake = FakeApplicationRepository()
        let viewModel = makeViewModel(fake: fake)
        fillRequiredFields(viewModel)
        var observedBusyState = false
        fake.onCreate = { observedBusyState = viewModel.isSaving }

        viewModel.save()

        #expect(observedBusyState)
        #expect(viewModel.isSaving == false)
    }

    @Test("unsaved changes track edits that would be lost")
    func unsavedChangesTrackEditableFields() {
        let fake = FakeApplicationRepository()
        let viewModel = makeViewModel(fake: fake)

        #expect(viewModel.hasUnsavedChanges == false)

        viewModel.companyName = "A"
        #expect(viewModel.hasUnsavedChanges)

        viewModel.companyName = ""
        #expect(viewModel.hasUnsavedChanges == false)

        viewModel.initialStatus = .applied
        #expect(viewModel.hasUnsavedChanges)

        viewModel.initialStatus = .wishlist
        viewModel.hasDeadline = true
        #expect(viewModel.hasUnsavedChanges)

        viewModel.hasDeadline = false
        viewModel.jobURLText = "https://example.com/jobs/7"
        #expect(viewModel.hasUnsavedChanges)
    }

    // MARK: - Edit mode

    private func makeEditingApplication(
        status: ApplicationStatus = .applied,
        deadline: Date? = nil
    ) -> Application {
        Application(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!,
            companyName: "星尘科技",
            roleTitle: "iOS 开发实习生",
            status: status,
            createdAt: pastStatusDate,
            lastModifiedAt: pastStatusDate,
            deadline: deadline ?? calendar.date(
                from: DateComponents(year: 2026, month: 11, day: 20, hour: 14, minute: 30)
            ),
            notes: "内推",
            jobURL: URL(string: "https://example.com/jobs/42"),
            location: "上海"
        )
    }

    private func makeEditViewModel(
        fake: FakeApplicationRepository,
        application: Application
    ) -> ApplicationEditorViewModel {
        ApplicationEditorViewModel(
            repository: fake,
            dateProvider: FixedDateProvider(now: now, calendar: calendar),
            application: application
        )
    }

    @Test("create mode is not editing")
    func createModeIsNotEditing() {
        let viewModel = makeViewModel(fake: FakeApplicationRepository())

        #expect(viewModel.isEditing == false)
    }

    @Test("edit mode prefills the draft from the application snapshot")
    func editModePrefillsDraft() {
        let application = makeEditingApplication()
        let viewModel = makeEditViewModel(fake: FakeApplicationRepository(), application: application)

        #expect(viewModel.isEditing)
        #expect(viewModel.companyName == "星尘科技")
        #expect(viewModel.roleTitle == "iOS 开发实习生")
        #expect(viewModel.jobURLText == "https://example.com/jobs/42")
        #expect(viewModel.locationText == "上海")
        #expect(viewModel.notesText == "内推")
        #expect(viewModel.hasDeadline)
        #expect(viewModel.includesDeadlineTime)
        #expect(viewModel.deadline == application.deadline)
        #expect(viewModel.hasUnsavedChanges == false)
    }

    @Test("edit mode saves through updateApplication and never changes status")
    func editModeSavesThroughUpdateApplication() {
        let application = makeEditingApplication(status: .applied)
        let fake = FakeApplicationRepository()
        let viewModel = makeEditViewModel(fake: fake, application: application)
        viewModel.companyName = " 新公司 "
        viewModel.roleTitle = "新职位"
        viewModel.locationText = " 北京 "
        viewModel.notesText = " 改了备注 "
        viewModel.jobURLText = " https://example.com/jobs/7 "
        // The status picker is hidden in edit mode; even if it changes, save must ignore it.
        viewModel.initialStatus = .offer

        viewModel.save()

        #expect(fake.createCalls.isEmpty)
        #expect(fake.statusChangeCalls.isEmpty)
        #expect(fake.updateCalls.count == 1)
        let call = fake.updateCalls.first
        #expect(call?.application === application)
        #expect(call?.companyName == "新公司")
        #expect(call?.roleTitle == "新职位")
        #expect(call?.location == "北京")
        #expect(call?.notes == "改了备注")
        #expect(call?.jobURL == URL(string: "https://example.com/jobs/7"))
        #expect(call?.deadline == application.deadline)
        #expect(application.status == .applied)
        #expect(viewModel.savedApplicationID == application.id)
        #expect(viewModel.saveErrorMessage == nil)
    }

    @Test("edit mode validates the same required fields and URL as create mode")
    func editModeValidatesLikeCreateMode() {
        let fake = FakeApplicationRepository()
        let viewModel = makeEditViewModel(fake: fake, application: makeEditingApplication())

        viewModel.companyName = "   "
        viewModel.save()
        #expect(viewModel.companyError == "请填写公司")
        #expect(fake.updateCalls.isEmpty)

        viewModel.companyName = "星尘科技"
        viewModel.jobURLText = "not a url"
        viewModel.save()
        #expect(viewModel.jobURLError == "请输入合法的岗位链接")
        #expect(fake.updateCalls.isEmpty)

        viewModel.jobURLText = ""
        viewModel.save()
        #expect(viewModel.jobURLError == nil)
        #expect(fake.updateCalls.count == 1)
        #expect(fake.updateCalls.first?.jobURL == nil)
    }

    @Test("edit-mode unsaved changes compare against the loaded snapshot")
    func editModeUnsavedChangesCompareAgainstSnapshot() {
        let viewModel = makeEditViewModel(
            fake: FakeApplicationRepository(),
            application: makeEditingApplication()
        )

        #expect(viewModel.hasUnsavedChanges == false)

        viewModel.notesText = "新备注"
        #expect(viewModel.hasUnsavedChanges)

        viewModel.notesText = "内推"
        #expect(viewModel.hasUnsavedChanges == false)

        viewModel.companyName = "星尘科技 "
        #expect(viewModel.hasUnsavedChanges == false, "trimmed text is equal")

        viewModel.hasDeadline = false
        #expect(viewModel.hasUnsavedChanges)

        viewModel.hasDeadline = true
        #expect(viewModel.hasUnsavedChanges == false)
    }

    @Test("a 09:00 deadline loads as the default time")
    func deadlineAtNineLoadsAsDefaultTime() throws {
        let deadline = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 9))
        )
        let viewModel = makeEditViewModel(
            fake: FakeApplicationRepository(),
            application: makeEditingApplication(deadline: deadline)
        )

        #expect(viewModel.hasDeadline)
        #expect(viewModel.includesDeadlineTime == false)
        #expect(viewModel.deadline == deadline)
    }

    @Test("an edit save failure shows the Chinese retry copy")
    func editModeSaveFailureShowsRetryCopy() {
        let fake = FakeApplicationRepository()
        fake.updateError = RepositoryError.saveFailed
        let viewModel = makeEditViewModel(fake: fake, application: makeEditingApplication())
        viewModel.companyName = "新公司"

        viewModel.save()

        #expect(viewModel.saveErrorMessage == "保存失败，请重试")
        #expect(viewModel.savedApplicationID == nil)
        #expect(fake.updateCalls.count == 1)
    }
}
