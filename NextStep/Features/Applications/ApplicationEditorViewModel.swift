import Foundation
import Observation
import os

/// Owns the create-application form: draft fields, inline validation, save state, and the
/// unsaved-changes signal used to confirm discarding edits.
///
/// The ViewModel never touches `ModelContext`; writes go through `ApplicationRepository`.
@Observable
@MainActor
final class ApplicationEditorViewModel {
    private let repository: any ApplicationRepository
    private let dateProvider: any DateProvider

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

    init(repository: any ApplicationRepository, dateProvider: any DateProvider) {
        self.repository = repository
        self.dateProvider = dateProvider
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
        !trimmed(companyName).isEmpty
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
        } catch {
            AppLogger.ui.error(
                "Failed to save an application: \(error.localizedDescription, privacy: .public)"
            )
            saveErrorMessage = "保存失败，请重试"
        }
    }

    @discardableResult
    private func validate() -> Bool {
        companyError = trimmed(companyName).isEmpty ? "请填写公司" : nil
        roleError = trimmed(roleTitle).isEmpty ? "请填写职位" : nil

        let rawURL = trimmed(jobURLText)
        if rawURL.isEmpty {
            jobURLError = nil
        } else {
            jobURLError = Self.webURL(from: rawURL) == nil ? "请输入合法的岗位链接" : nil
        }

        return companyError == nil && roleError == nil && jobURLError == nil
    }

    private var parsedJobURL: URL? {
        let rawURL = trimmed(jobURLText)
        return rawURL.isEmpty ? nil : Self.webURL(from: rawURL)
    }

    private static func webURL(from rawValue: String) -> URL? {
        guard
            let url = URL(string: rawValue),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = url.host,
            !host.isEmpty
        else {
            return nil
        }
        return url
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func nilIfBlank(_ value: String) -> String? {
        let trimmedValue = trimmed(value)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
