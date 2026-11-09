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
}
