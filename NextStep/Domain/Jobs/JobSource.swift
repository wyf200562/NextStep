import Foundation

/// Every job source (Remotive, manual paste, future URL import) conforms to this seam.
///
/// Sources only fetch and normalize; they never persist. `JobRepository` is the single write entry.
nonisolated protocol JobSource: Sendable {
    var intakeMethod: JobIntakeMethod { get }

    /// Returns normalized drafts. The repository assigns local ids and `createdAt`.
    func loadJobs() async throws -> [JobPostingDraft]
}
