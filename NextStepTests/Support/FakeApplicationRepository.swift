import Foundation
@testable import NextStep

/// Test double for the application writing seam. It records creation arguments and returns a
/// synthetic `Application`, so ViewModel tests observe behavior without SwiftData.
@MainActor
final class FakeApplicationRepository: ApplicationRepository {
    struct CreateCall {
        let companyName: String
        let roleTitle: String
        let initialStatus: ApplicationStatus
        let statusDate: Date
        let deadline: Date?
        let jobURL: URL?
        let location: String?
        let notes: String?
        let jobPosting: JobPosting?
    }

    var createCalls: [CreateCall] = []
    var createError: (any Error)?
    var createdApplicationID = UUID()
    var onCreate: (() -> Void)?

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
        createCalls.append(CreateCall(
            companyName: companyName,
            roleTitle: roleTitle,
            initialStatus: initialStatus,
            statusDate: statusDate,
            deadline: deadline,
            jobURL: jobURL,
            location: location,
            notes: notes,
            jobPosting: jobPosting
        ))
        onCreate?()
        if let createError {
            throw createError
        }
        return Application(
            id: createdApplicationID,
            companyName: companyName,
            roleTitle: roleTitle,
            status: initialStatus,
            createdAt: statusDate,
            lastModifiedAt: statusDate,
            jobPosting: jobPosting,
            deadline: deadline,
            notes: notes,
            jobURL: jobURL,
            location: location
        )
    }

    func allApplications() throws -> [Application] { [] }

    func application(id: UUID) throws -> Application? { nil }

    func applications(for jobPosting: JobPosting) throws -> [Application] { [] }

    func statusChanges(for application: Application) throws -> [StatusChange] { [] }

    func updateApplication(
        _ application: Application,
        companyName: String,
        roleTitle: String,
        jobURL: URL?,
        location: String?,
        notes: String?,
        deadline: Date?
    ) throws {
        throw RepositoryError.unavailable
    }

    func deleteApplication(_ application: Application) throws {
        throw RepositoryError.unavailable
    }

    func changeStatus(
        of application: Application,
        to newStatus: ApplicationStatus,
        note: String?,
        at date: Date
    ) throws {
        throw RepositoryError.unavailable
    }

    func addInterviewRound(
        to application: Application,
        scheduledAt: Date,
        format: InterviewFormat,
        label: String?,
        contact: String?,
        notes: String?,
        result: InterviewResult
    ) throws -> InterviewRound {
        throw RepositoryError.unavailable
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
        throw RepositoryError.unavailable
    }

    func deleteInterviewRound(_ round: InterviewRound) throws {
        throw RepositoryError.unavailable
    }
}
