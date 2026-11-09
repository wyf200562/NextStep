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
    /// Chinese copy for a failed status change or deletion; raw errors are never shown.
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
                note: Self.normalizedNote(note),
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

    private static func normalizedNote(_ note: String?) -> String? {
        guard let note else { return nil }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
