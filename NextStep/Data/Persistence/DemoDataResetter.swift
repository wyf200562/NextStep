import SwiftData

/// Debug-only helper that returns the app to a first-launch state: every persisted record is
/// deleted and the per-source refresh ledger is cleared.
///
/// Children are deleted before their parents so the cascade rules never have to fire twice:
/// `InterviewRound` / `StatusChange` (owned by `Application`), then `Application` (cascades to any
/// leftovers), then `JobPosting` (nullify leaves application snapshots untouched), then
/// `UserProfile`. The ledger is cleared only after the store save succeeds, so a failed save leaves
/// the refresh quota unchanged and the action can be retried.
@MainActor
struct DemoDataResetter {
    private let context: ModelContext
    private let refreshLedger: RefreshLedger

    init(context: ModelContext, refreshLedger: RefreshLedger) {
        self.context = context
        self.refreshLedger = refreshLedger
    }

    /// Deletes all five model types and resets the refresh ledger.
    func reset() throws {
        try deleteAll(InterviewRound.self)
        try deleteAll(StatusChange.self)
        try deleteAll(Application.self)
        try deleteAll(JobPosting.self)
        try deleteAll(UserProfile.self)
        do {
            try context.save()
        } catch {
            // Restore the in-memory context so a failed save does not leave half-deleted state.
            context.rollback()
            throw error
        }
        refreshLedger.reset()
    }

    private func deleteAll<Model: PersistentModel>(_ type: Model.Type) throws {
        for model in try context.fetch(FetchDescriptor<Model>()) {
            context.delete(model)
        }
    }
}
