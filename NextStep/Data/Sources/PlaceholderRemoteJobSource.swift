import Foundation

/// Minimal remote source until ticket 23 adds `RemotiveJobSource` (DTO, HTTP mapping, and ledger).
///
/// The factory seam stays complete so the app always has a remote source; refresh is wired to fail
/// fast instead of pretending a sample exists.
nonisolated struct PlaceholderRemoteJobSource: JobSource {
    let intakeMethod: JobIntakeMethod = .remotive

    func loadJobs() async throws -> [JobPostingDraft] {
        throw JobSourceError.offline
    }
}
