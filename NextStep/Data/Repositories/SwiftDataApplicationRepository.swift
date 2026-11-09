import Foundation
import os
import SwiftData

/// SwiftData implementation of the application writing seam.
///
/// Creation inserts the `Application` and its initial `StatusChange` in one save. Status changes,
/// snapshot edits, deletion, and interview-round management are owned by tickets 14 and 16; until
/// those land, calling them fails with `RepositoryError.unavailable` instead of trapping.
@MainActor
final class SwiftDataApplicationRepository: ApplicationRepository {
    private let context: ModelContext
    private let dateProvider: any DateProvider

    init(context: ModelContext, dateProvider: any DateProvider) {
        self.context = context
        self.dateProvider = dateProvider
    }

    // MARK: - Reads

    func allApplications() throws -> [Application] {
        do {
            return try context.fetch(FetchDescriptor<Application>())
        } catch {
            AppLogger.data.error(
                "Failed to load applications: \(error.localizedDescription, privacy: .public)"
            )
            throw RepositoryError.loadFailed
        }
    }

    func application(id: UUID) throws -> Application? {
        var descriptor = FetchDescriptor<Application>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            AppLogger.data.error(
                "Failed to load application \(id, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            throw RepositoryError.loadFailed
        }
    }

    func applications(for jobPosting: JobPosting) throws -> [Application] {
        // The v1 data set is small; filtering here avoids fragile optional-relationship predicates.
        try allApplications().filter { $0.jobPosting?.id == jobPosting.id }
    }

    func statusChanges(for application: Application) throws -> [StatusChange] {
        application.statusChanges.sorted { lhs, rhs in
            if lhs.changedAt != rhs.changedAt {
                return lhs.changedAt > rhs.changedAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    // MARK: - Creation

    @discardableResult
    func createApplication(
        companyName: String,
        roleTitle: String,
        initialStatus: ApplicationStatus,
        statusDate: Date,
        deadline: Date?,
        jobURL: URL?,
        location: String?,
        notes: String?,
        jobPosting: JobPosting?
    ) throws -> Application {
        let now = dateProvider.now
        let application = Application(
            companyName: companyName,
            roleTitle: roleTitle,
            status: initialStatus,
            createdAt: now,
            lastModifiedAt: now,
            jobPosting: jobPosting,
            deadline: deadline,
            notes: notes,
            jobURL: jobURL,
            location: location
        )
        let initialChange = StatusChange(
            fromStatus: nil,
            toStatus: initialStatus,
            changedAt: statusDate
        )

        context.insert(application)
        context.insert(initialChange)
        initialChange.application = application

        do {
            try context.save()
        } catch {
            context.rollback()
            AppLogger.data.error(
                "Failed to create application: \(error.localizedDescription, privacy: .public)"
            )
            throw RepositoryError.saveFailed
        }
        AppLogger.data.info("Created an application with its initial status change")
        return application
    }

    // MARK: - Owned by later tickets

    func updateApplication(
        _ application: Application,
        companyName: String,
        roleTitle: String,
        jobURL: URL?,
        location: String?,
        notes: String?,
        deadline: Date?
    ) throws {
        throw deferred("updateApplication", tickets: "14")
    }

    func deleteApplication(_ application: Application) throws {
        throw deferred("deleteApplication", tickets: "14")
    }

    func changeStatus(
        of application: Application,
        to newStatus: ApplicationStatus,
        note: String?,
        at date: Date
    ) throws {
        throw deferred("changeStatus", tickets: "14")
    }

    @discardableResult
    func addInterviewRound(
        to application: Application,
        scheduledAt: Date,
        format: InterviewFormat,
        label: String?,
        contact: String?,
        notes: String?,
        result: InterviewResult
    ) throws -> InterviewRound {
        throw deferred("addInterviewRound", tickets: "14/16")
    }

    func updateInterviewRound(
        _ round: InterviewRound,
        scheduledAt: Date,
        format: InterviewFormat,
        label: String?,
        contact: String?,
        notes: String?,
        result: InterviewResult
    ) throws {
        throw deferred("updateInterviewRound", tickets: "14/16")
    }

    func deleteInterviewRound(_ round: InterviewRound) throws {
        throw deferred("deleteInterviewRound", tickets: "14/16")
    }

    private func deferred(_ operation: String, tickets: String) -> RepositoryError {
        AppLogger.data.error(
            "ApplicationRepository.\(operation, privacy: .public) is implemented by ticket(s) \(tickets, privacy: .public)"
        )
        return .unavailable
    }
}
