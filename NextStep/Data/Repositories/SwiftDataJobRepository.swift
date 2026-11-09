import Foundation
import os
import SwiftData

/// SwiftData implementation of the job persistence seam.
///
/// Sources only produce drafts; this repository is the single write entry and upserts by
/// `identityKey`. Refresh throttling, the Remotive source, and `lastRefreshAt` arrive with ticket 23.
@MainActor
final class SwiftDataJobRepository: JobRepository {
    private let context: ModelContext
    private let dateProvider: any DateProvider
    private let jobSourceFactory: JobSourceFactory

    init(
        context: ModelContext,
        dateProvider: any DateProvider,
        jobSourceFactory: JobSourceFactory
    ) {
        self.context = context
        self.dateProvider = dateProvider
        self.jobSourceFactory = jobSourceFactory
    }

    func cachedJobs() throws -> [JobPosting] {
        let descriptor = FetchDescriptor<JobPosting>(sortBy: [
            SortDescriptor(\.createdAt, order: .reverse),
            SortDescriptor(\.id, order: .forward),
        ])
        do {
            return try context.fetch(descriptor)
        } catch {
            AppLogger.data.error("Failed to load cached jobs: \(error.localizedDescription, privacy: .public)")
            throw RepositoryError.loadFailed
        }
    }

    func refreshDiscover(query: JobQuery) async -> RefreshOutcome {
        // Ticket 23 replaces this with the Remotive refresh, throttling, TTL, and quota handling.
        AppLogger.data.info("refreshDiscover is not implemented until ticket 23")
        let cachedCount = (try? cachedJobs().count) ?? 0
        return .failed(error: RepositoryError.unavailable, cachedCount: cachedCount)
    }

    func importManual(_ input: ManualJobInput) async throws -> JobPosting {
        let source = jobSourceFactory.makeManual(input)
        let drafts = try await source.loadJobs()
        guard let draft = drafts.first else {
            AppLogger.data.error("Manual job source returned no drafts")
            throw JobSourceError.invalidInput
        }
        return try upsert(draft)
    }

    func lastRefreshAt(for source: JobIntakeMethod) -> Date? {
        // Ticket 23 adds the RefreshLedger and reports the last successful refresh per source.
        nil
    }

    private func upsert(_ draft: JobPostingDraft) throws -> JobPosting {
        let key = draft.identityKey
        var descriptor = FetchDescriptor<JobPosting>(
            predicate: #Predicate<JobPosting> { posting in posting.identityKey == key }
        )
        descriptor.fetchLimit = 1

        let existing: JobPosting?
        do {
            existing = try context.fetch(descriptor).first
        } catch {
            AppLogger.data.error("Failed to look up JobPosting: \(error.localizedDescription, privacy: .public)")
            throw RepositoryError.loadFailed
        }

        let posting: JobPosting
        if let existing {
            existing.title = draft.title
            existing.companyName = draft.companyName
            existing.intakeMethod = draft.intakeMethod
            existing.descriptionPlainText = draft.descriptionPlainText
            existing.externalJobID = draft.externalJobID
            existing.jobURL = draft.jobURL
            existing.location = draft.location
            existing.jobType = draft.jobType
            existing.tags = draft.tags
            existing.publishedAt = draft.publishedAt
            existing.salary = draft.salary
            existing.companyLogoURL = draft.companyLogoURL
            posting = existing
        } else {
            let newPosting = JobPosting(
                identityKey: draft.identityKey,
                title: draft.title,
                companyName: draft.companyName,
                intakeMethod: draft.intakeMethod,
                descriptionPlainText: draft.descriptionPlainText,
                createdAt: dateProvider.now,
                externalJobID: draft.externalJobID,
                jobURL: draft.jobURL,
                location: draft.location,
                jobType: draft.jobType,
                tags: draft.tags,
                publishedAt: draft.publishedAt,
                salary: draft.salary,
                companyLogoURL: draft.companyLogoURL
            )
            context.insert(newPosting)
            posting = newPosting
        }

        do {
            try context.save()
        } catch {
            AppLogger.data.error("Failed to save JobPosting: \(error.localizedDescription, privacy: .public)")
            throw RepositoryError.saveFailed
        }
        return posting
    }
}
