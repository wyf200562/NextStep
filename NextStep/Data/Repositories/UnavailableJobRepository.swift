import Foundation
import os

/// Scaffolding implementation for the job persistence seam.
///
/// The ingestion slices (20/23) replace this with a SwiftData-backed repository that owns upserts,
/// throttling, and cache reads. Until then operations fail with a typed error instead of trapping.
@MainActor
final class UnavailableJobRepository: JobRepository {
    private func unavailable(_ operation: String) -> RepositoryError {
        AppLogger.data.error("JobRepository.\(operation, privacy: .public) is unavailable in this scaffolding slice")
        return .unavailable
    }

    func cachedJobs() throws -> [JobPosting] {
        throw unavailable("cachedJobs")
    }

    func refreshDiscover(query: JobQuery) async -> RefreshOutcome {
        AppLogger.data.error("JobRepository.refreshDiscover is unavailable in this scaffolding slice")
        return .failed(error: RepositoryError.unavailable, cachedCount: 0)
    }

    func importManual(_ input: ManualJobInput) async throws -> JobPosting {
        throw unavailable("importManual")
    }

    func lastRefreshAt(for source: JobIntakeMethod) -> Date? {
        nil
    }
}
