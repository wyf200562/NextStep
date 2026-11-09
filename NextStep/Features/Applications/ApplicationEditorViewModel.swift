import Foundation
import Observation
import os

/// Owns the application form in both create and edit modes: draft fields, inline validation, save
/// state, and the unsaved-changes signal used to confirm discarding edits.
///
/// Edit mode prefills the draft from the application snapshot and saves through
/// `ApplicationRepository.updateApplication`. Status is intentionally not editable here; it only
/// changes through the detail status flow so the state machine and history stay consistent.
///
/// The ViewModel never touches `ModelContext`; writes go through `ApplicationRepository`.
@Observable
@MainActor
final class ApplicationEditorViewModel {
    private enum Mode {
        case create
        case edit(Application)
    }

    /// The values a save would persist, used to decide whether edits would be lost.
    private struct Draft: Equatable {
        let companyName: String
        let roleTitle: String
        let jobURLText: String
        let locationText: String
        let notesText: String
        let deadline: Date?
    }

    private let repository: any ApplicationRepository
    private let dateProvider: any DateProvider
    private let mode: Mode
    private let initialDraft: Draft?

    var companyName = ""
    var roleTitle = ""
    var initialStatus: ApplicationStatus = .wishlist
    var statusDate: Date
    var hasDeadline = false
    var deadlineDay: Date
    var includesDeadlineTime = false
    var deadlineTime: Date
    var jobURLText = ""
    var locationText = ""
    var notesText = ""

    private(set) var companyError: String?
    private(set) var roleError: String?
    private(set) var jobURLError: String?
    private(set) var saveErrorMessage: String?
    private(set) var isSaving = false
    private(set) var savedApplicationID: UUID?

    /// Create mode: blank draft, initial status defaults to wishlist.
    init(repository: any ApplicationRepository, dateProvider: any DateProvider) {
        self.repository = repository
        self.dateProvider = dateProvider
        self.mode = .create
        self.initialDraft = nil
        self.statusDate = dateProvider.now
        let today = dateProvider.calendar.startOfDay(for: dateProvider.now)
        self.deadlineDay = today
        self.deadlineTime = dateProvider.calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: today
        ) ?? today
    }

    /// Edit mode: prefilled from the snapshot; status is not editable and is not saved.
    init(
        repository: any ApplicationRepository,
        dateProvider: any DateProvider,
        application: Application
    ) {
        self.repository = repository
        self.dateProvider = dateProvider
        self.mode = .edit(application)

        let calendar = dateProvider.calendar
        let today = calendar.startOfDay(for: dateProvider.now)
        let deadline = application.deadline
        let deadlineDay = deadline.map { calendar.startOfDay(for: $0) } ?? today
        let defaultTime = calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: deadlineDay
        ) ?? deadlineDay
        let timeComponents = deadline.map { calendar.dateComponents([.hour, .minute], from: $0) }
        let usesDefaultTime = timeComponents.map { $0.hour == 9 && $0.minute == 0 } ?? true

        self.companyName = application.companyName
        self.roleTitle = application.roleTitle
        self.initialStatus = application.status
        self.statusDate = dateProvider.now
        self.hasDeadline = deadline != nil
        self.deadlineDay = deadlineDay
        self.includesDeadlineTime = !usesDefaultTime
        self.deadlineTime = usesDefaultTime ? defaultTime : (deadline ?? defaultTime)
        self.jobURLText = application.jobURL?.absoluteString ?? ""
        self.locationText = application.location ?? ""
        self.notesText = application.notes ?? ""
        self.initialDraft = Draft(
            companyName: application.companyName,
            roleTitle: application.roleTitle,
            jobURLText: application.jobURL?.absoluteString ?? "",
            locationText: application.location ?? "",
            notesText: application.notes ?? "",
            deadline: application.deadline
        )
    }

    var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    /// The status date is only editable for historical backfill; wishlist means "not applied yet".
    var showsStatusDate: Bool {
        initialStatus != .wishlist
    }

    /// Upper bound for the status date picker; backfilling past dates is allowed.
    var currentDate: Date {
        dateProvider.now
    }

    /// The deadline instant: the chosen day plus either the chosen time or the 09:00 default.
    var deadline: Date? {
        guard hasDeadline else { return nil }

        let calendar = dateProvider.calendar
        var components = calendar.dateComponents([.year, .month, .day], from: deadlineDay)
        if includesDeadlineTime {
            let time = calendar.dateComponents([.hour, .minute], from: deadlineTime)
            components.hour = time.hour
            components.minute = time.minute
        } else {
            components.hour = 9
            components.minute = 0
        }
        components.second = 0
        return calendar.date(from: components)
    }

    /// True when dismissing the form would lose user input.
    var hasUnsavedChanges: Bool {
        if let initialDraft {
            return currentDraft != initialDraft
        }
        return !trimmed(companyName).isEmpty
            || !trimmed(roleTitle).isEmpty
            || initialStatus != .wishlist
            || hasDeadline
            || !trimmed(jobURLText).isEmpty
            || !trimmed(locationText).isEmpty
            || !trimmed(notesText).isEmpty
    }

    func save() {
        guard !isSaving else { return }
        guard validate() else { return }

        saveErrorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            switch mode {
            case .create:
                let application = try repository.createApplication(
                    companyName: trimmed(companyName),
                    roleTitle: trimmed(roleTitle),
                    initialStatus: initialStatus,
                    statusDate: showsStatusDate ? statusDate : dateProvider.now,
                    deadline: deadline,
                    jobURL: parsedJobURL,
                    location: nilIfBlank(locationText),
                    notes: nilIfBlank(notesText),
                    jobPosting: nil
                )
                savedApplicationID = application.id
            case .edit(let application):
                try repository.updateApplication(
                    application,
                    companyName: trimmed(companyName),
                    roleTitle: trimmed(roleTitle),
                    jobURL: parsedJobURL,
                    location: nilIfBlank(locationText),
                    notes: nilIfBlank(notesText),
                    deadline: deadline
                )
                savedApplicationID = application.id
            }
        } catch {
            AppLogger.ui.error(
                "Failed to save an application: \(error.localizedDescription, privacy: .public)"
            )
            saveErrorMessage = "保存失败，请重试"
        }
    }

    private var currentDraft: Draft {
        Draft(
            companyName: trimmed(companyName),
            roleTitle: trimmed(roleTitle),
            jobURLText: trimmed(jobURLText),
            locationText: trimmed(locationText),
            notesText: trimmed(notesText),
            deadline: deadline
        )
    }

    @discardableResult
    private func validate() -> Bool {
        companyError = trimmed(companyName).isEmpty ? "请填写公司" : nil
        roleError = trimmed(roleTitle).isEmpty ? "请填写职位" : nil

        let rawURL = trimmed(jobURLText)
        if rawURL.isEmpty {
            jobURLError = nil
        } else {
            jobURLError = WebURL.parse(rawURL) == nil ? "请输入合法的岗位链接" : nil
        }

        return companyError == nil && roleError == nil && jobURLError == nil
    }

    private var parsedJobURL: URL? {
        let rawURL = trimmed(jobURLText)
        return rawURL.isEmpty ? nil : WebURL.parse(rawURL)
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func nilIfBlank(_ value: String) -> String? {
        let trimmedValue = trimmed(value)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
