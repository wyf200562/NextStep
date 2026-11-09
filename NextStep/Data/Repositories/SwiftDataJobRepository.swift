import Foundation
import os
import SwiftData

/// SwiftData implementation of the job persistence seam.
///
/// Sources only produce drafts; this repository is the single write entry and upserts by
/// `identityKey`. Refresh attempts are throttled per source by the injected `RefreshLedger`; old
/// postings are never deleted because an `Application` may reference them.
@MainActor
final class SwiftDataJobRepository: JobRepository {
    private let context: ModelContext
    private let dateProvider: any DateProvider
    private let jobSourceFactory: JobSourceFactory
    private let refreshLedger: RefreshLedger

    init(
        context: ModelContext,
        dateProvider: any DateProvider,
        jobSourceFactory: JobSourceFactory,
        refreshLedger: RefreshLedger
    ) {
        self.context = context
        self.dateProvider = dateProvider
        self.jobSourceFactory = jobSourceFactory
        self.refreshLedger = refreshLedger
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
        if let reason = refreshLedger.nextAttemptBlock(for: .remotive) {
            AppLogger.data.info("Remotive refresh skipped: \(reason.rawValue, privacy: .public)")
            return .skipped(reason: reason)
        }
        // Record before the request: a cancelled or failed attempt still consumes the quota.
        refreshLedger.recordAttempt(for: .remotive)

        let source = jobSourceFactory.makeRemote(query)
        let drafts: [JobPostingDraft]
        do {
            drafts = try await source.loadJobs()
        } catch {
            AppLogger.data.error(
                "Remotive refresh failed: \(String(describing: error), privacy: .public)"
            )
            let reportedError: any Error = error is CancellationError ? CancellationError() : error
            return .failed(error: reportedError, cachedCount: cachedCount())
        }

        var added = 0
        var updated = 0
        do {
            for draft in drafts {
                let result = try upsert(draft)
                if result.isNew {
                    added += 1
                } else {
                    updated += 1
                }
            }
        } catch {
            AppLogger.data.error(
                "Failed to persist the Remotive sample: \(String(describing: error), privacy: .public)"
            )
            return .failed(error: error, cachedCount: cachedCount())
        }

        refreshLedger.recordSuccess(for: .remotive)
        AppLogger.data.info(
            "Remotive refresh complete: \(added) added, \(updated) updated"
        )
        return .refreshed(added: added, updated: updated)
    }

    func importManual(_ input: ManualJobInput) async throws -> JobPosting {
        let source = jobSourceFactory.makeManual(input)
        let drafts = try await source.loadJobs()
        guard let draft = drafts.first else {
            AppLogger.data.error("Manual job source returned no drafts")
            throw JobSourceError.invalidInput
        }
        // Manual imports never touch the Remotive `RefreshLedger`.
        return try upsert(draft).posting
    }

    func lastRefreshAt(for source: JobIntakeMethod) -> Date? {
        refreshLedger.lastSuccess(for: source)
    }

    private func cachedCount() -> Int {
        (try? cachedJobs().count) ?? 0
    }

    @discardableResult
    private func upsert(_ draft: JobPostingDraft) throws -> (posting: JobPosting, isNew: Bool) {
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
        return (posting, existing == nil)
    }
}
