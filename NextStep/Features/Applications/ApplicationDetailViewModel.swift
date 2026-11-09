import Foundation
import Observation
import os

/// Owns the application detail screen: loading, status-transition intents, and deletion.
///
/// The status targets, confirmation flags, and validity all come from `ApplicationStateMachine`, so
/// the UI never duplicates the transition table. The ViewModel never touches `ModelContext`; every
/// write goes through `ApplicationRepository`.
@Observable
@MainActor
final class ApplicationDetailViewModel {
    static let invalidTransitionMessage = "当前状态不能这样变更"

    private let repository: any ApplicationRepository
    private let dateProvider: any DateProvider
    private let applicationID: UUID

    private(set) var state: LoadState<Application> = .idle
    private(set) var isChangingStatus = false
    private(set) var isDeleting = false
    private(set) var isSavingRound = false
    /// True after a future round was added while the application is applied or oa; the UI asks
    /// whether to move the application to interview.
    private(set) var isPromptingMarkAsInterview = false
    /// Chinese copy for a failed status change, round write, or deletion; raw errors are never shown.
    private(set) var actionErrorMessage: String?

    init(
        repository: any ApplicationRepository,
        dateProvider: any DateProvider,
        applicationID: UUID
    ) {
        self.repository = repository
        self.dateProvider = dateProvider
        self.applicationID = applicationID
    }

    var application: Application? {
        state.value
    }

    /// Calendar-relative UI copy uses this injected clock, never the system clock.
    var currentDate: Date {
        dateProvider.now
    }

    /// All rounds sorted by `scheduledAt` ascending with `id` as the tie-breaker; to-many
    /// relationships are unordered.
    var rounds: [InterviewRound] {
        application?.interviewRounds.sorted { lhs, rhs in
            if lhs.scheduledAt != rhs.scheduledAt {
                return lhs.scheduledAt < rhs.scheduledAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        } ?? []
    }

    /// The earlier of the upcoming deadline and the nearest pending round.
    var nextNode: ApplicationNextNode? {
        application.flatMap {
            ApplicationNextNode.nearest(for: $0, at: dateProvider.now)
        }
    }

    /// Allowed targets for the current status, in canonical display order.
    var targets: [ApplicationStatus] {
        guard let application else { return [] }
        return ApplicationStateMachine.allowedTransitions(from: application.status)
    }

    func requiresConfirmation(to target: ApplicationStatus) -> Bool {
        guard let application else { return false }
        return ApplicationStateMachine.requiresConfirmation(from: application.status, to: target)
    }

    /// True when reaching `target` means explicitly reopening a terminated application.
    func isReopen(to target: ApplicationStatus) -> Bool {
        guard let application else { return false }
        return ApplicationStateMachine.reopenTargets(from: application.status).contains(target)
    }

    func load() {
        state = .loading
        reload()
    }

    /// Refetches the application without flashing the loading state; used after an edit save.
    func refresh() {
        reload()
    }

    /// Attempts a status change. Returns false and exposes Chinese copy when the transition is
    /// illegal or the save fails.
    @discardableResult
    func changeStatus(to newStatus: ApplicationStatus, note: String?) -> Bool {
        guard let application, !isChangingStatus else { return false }

        guard ApplicationStateMachine.isValidTransition(from: application.status, to: newStatus) else {
            actionErrorMessage = Self.invalidTransitionMessage
            return false
        }

        isChangingStatus = true
        defer { isChangingStatus = false }
        actionErrorMessage = nil

        do {
            try repository.changeStatus(
                of: application,
                to: newStatus,
                note: Self.normalizedText(note),
                at: dateProvider.now
            )
            refresh()
            return true
        } catch is ApplicationTransitionError {
            actionErrorMessage = Self.invalidTransitionMessage
            return false
        } catch {
            AppLogger.ui.error(
                "Failed to change application status: \(error.localizedDescription, privacy: .public)"
            )
            actionErrorMessage = "保存失败，请重试"
            return false
        }
    }

    /// Deletes the application. Returns false and exposes Chinese copy when the save fails.
    @discardableResult
    func delete() -> Bool {
        guard let application, !isDeleting else { return false }

        isDeleting = true
        defer { isDeleting = false }
        actionErrorMessage = nil

        do {
            try repository.deleteApplication(application)
            return true
        } catch {
            AppLogger.ui.error(
                "Failed to delete application: \(error.localizedDescription, privacy: .public)"
            )
            actionErrorMessage = "删除失败，请重试"
            return false
        }
    }

    // MARK: - Interview rounds

    /// Adds a round. A future round for an applied/oa application asks whether to mark the
    /// application as interviewing; adding never changes the status by itself.
    @discardableResult
    func addRound(
        scheduledAt: Date,
        format: InterviewFormat,
        label: String?,
        contact: String?,
        notes: String?,
        result: InterviewResult
    ) -> Bool {
        guard let application, !isSavingRound else { return false }

        isSavingRound = true
        defer { isSavingRound = false }
        actionErrorMessage = nil
        let statusBeforeSave = application.status

        do {
            try repository.addInterviewRound(
                to: application,
                scheduledAt: scheduledAt,
                format: format,
                label: Self.normalizedText(label),
                contact: Self.normalizedText(contact),
                notes: Self.normalizedText(notes),
                result: result
            )
            refresh()
            isPromptingMarkAsInterview =
                scheduledAt > dateProvider.now
                && (statusBeforeSave == .applied || statusBeforeSave == .oa)
            return true
        } catch {
            AppLogger.ui.error(
                "Failed to add an interview round: \(error.localizedDescription, privacy: .public)"
            )
            actionErrorMessage = "保存失败，请重试"
            return false
        }
    }

    /// Edits a round. Neither the round result nor a future time changes the application status.
    @discardableResult
    func updateRound(
        _ round: InterviewRound,
        scheduledAt: Date,
        format: InterviewFormat,
        label: String?,
        contact: String?,
        notes: String?,
        result: InterviewResult
    ) -> Bool {
        guard !isSavingRound else { return false }

        isSavingRound = true
        defer { isSavingRound = false }
        actionErrorMessage = nil

        do {
            try repository.updateInterviewRound(
                round,
                scheduledAt: scheduledAt,
                format: format,
                label: Self.normalizedText(label),
                contact: Self.normalizedText(contact),
                notes: Self.normalizedText(notes),
                result: result
            )
            refresh()
            return true
        } catch {
            AppLogger.ui.error(
                "Failed to update an interview round: \(error.localizedDescription, privacy: .public)"
            )
            actionErrorMessage = "保存失败，请重试"
            return false
        }
    }

    /// Deletes a round; the application status is never touched.
    @discardableResult
    func deleteRound(_ round: InterviewRound) -> Bool {
        guard !isSavingRound else { return false }

        isSavingRound = true
        defer { isSavingRound = false }
        actionErrorMessage = nil

        do {
            try repository.deleteInterviewRound(round)
            refresh()
            return true
        } catch {
            AppLogger.ui.error(
                "Failed to delete an interview round: \(error.localizedDescription, privacy: .public)"
            )
            actionErrorMessage = "删除失败，请重试"
            return false
        }
    }

    /// Confirms the mark-as-interview prompt through the state machine-backed status change.
    @discardableResult
    func confirmMarkAsInterview() -> Bool {
        guard isPromptingMarkAsInterview else { return false }
        isPromptingMarkAsInterview = false
        return changeStatus(to: .interview, note: nil)
    }

    /// Dismisses the prompt without touching the application.
    func cancelMarkAsInterviewPrompt() {
        isPromptingMarkAsInterview = false
    }

    func clearActionError() {
        actionErrorMessage = nil
    }

    private func reload() {
        do {
            if let application = try repository.application(id: applicationID) {
                state = .loaded(application)
            } else {
                state = .failed(RepositoryError.loadFailed)
            }
        } catch {
            AppLogger.ui.error(
                "Failed to load application detail: \(error.localizedDescription, privacy: .public)"
            )
            state = .failed(error)
        }
    }

    private static func normalizedText(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
