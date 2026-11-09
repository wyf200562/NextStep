import Foundation
import os

/// Scaffolding implementation for the application writing seam.
///
/// The tracking slices (13/14/16) replace this with a SwiftData-backed repository. Until then every
/// operation fails with a typed error rather than trapping, so the app shell stays launchable.
@MainActor
final class UnavailableApplicationRepository: ApplicationRepository {
    private func unavailable(_ operation: String) -> RepositoryError {
        AppLogger.data.error("ApplicationRepository.\(operation, privacy: .public) is unavailable in this scaffolding slice")
        return .unavailable
    }

    func allApplications() throws -> [Application] {
        throw unavailable("allApplications")
    }

    func application(id: UUID) throws -> Application? {
        throw unavailable("application(id:)")
    }

    func applications(for jobPosting: JobPosting) throws -> [Application] {
        throw unavailable("applications(for:)")
    }

    func statusChanges(for application: Application) throws -> [StatusChange] {
        throw unavailable("statusChanges(for:)")
    }

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
        throw unavailable("createApplication")
    }

    func updateApplication(
        _ application: Application,
        companyName: String,
        roleTitle: String,
        jobURL: URL?,
        location: String?,
        notes: String?,
        deadline: Date?
    ) throws {
        throw unavailable("updateApplication")
    }

    func deleteApplication(_ application: Application) throws {
        throw unavailable("deleteApplication")
    }

    func changeStatus(
        of application: Application,
        to newStatus: ApplicationStatus,
        note: String?,
        at date: Date
    ) throws {
        throw unavailable("changeStatus")
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
        throw unavailable("addInterviewRound")
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
        throw unavailable("updateInterviewRound")
    }

    func deleteInterviewRound(_ round: InterviewRound) throws {
        throw unavailable("deleteInterviewRound")
    }
}
