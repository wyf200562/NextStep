import Foundation

/// The single persistence entry for job postings: cache reads, refresh upserts, and manual imports.
///
/// `cachedJobs()` sorts by `createdAt` descending with `id` as the tie-breaker. `lastRefreshAt`
/// reports the most recent *successful* refresh for a source.
@MainActor
protocol JobRepository: AnyObject {
    func cachedJobs() throws -> [JobPosting]
    func refreshDiscover(query: JobQuery) async -> RefreshOutcome
    func importManual(_ input: ManualJobInput) async throws -> JobPosting
    func lastRefreshAt(for source: JobIntakeMethod) -> Date?
}
