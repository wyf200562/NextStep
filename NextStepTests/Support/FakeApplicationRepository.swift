import Foundation
@testable import NextStep

/// Test double for the application writing seam. It records calls and returns synthetic models, so
/// ViewModel tests observe behavior without SwiftData.
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

    struct UpdateCall {
        let application: Application
        let companyName: String
        let roleTitle: String
        let jobURL: URL?
        let location: String?
        let notes: String?
        let deadline: Date?
    }

    struct StatusChangeCall {
        let application: Application
        let toStatus: ApplicationStatus
        let note: String?
        let date: Date
    }

    var createCalls: [CreateCall] = []
    var createError: (any Error)?
    var createdApplicationID = UUID()
    var onCreate: (() -> Void)?

    var storedApplications: [UUID: Application] = [:]
    var applicationLoadError: (any Error)?

    var updateCalls: [UpdateCall] = []
    var updateError: (any Error)?

    var deleteCalls: [Application] = []
    var deleteError: (any Error)?

    var statusChangeCalls: [StatusChangeCall] = []
    var statusChangeError: (any Error)?

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

    func allApplications() throws -> [Application] {
        Array(storedApplications.values)
    }

    func application(id: UUID) throws -> Application? {
        if let applicationLoadError {
            throw applicationLoadError
        }
        return storedApplications[id]
    }

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
        updateCalls.append(UpdateCall(
            application: application,
            companyName: companyName,
            roleTitle: roleTitle,
            jobURL: jobURL,
            location: location,
            notes: notes,
            deadline: deadline
        ))
        if let updateError {
            throw updateError
        }
        application.companyName = companyName
        application.roleTitle = roleTitle
        application.jobURL = jobURL
        application.location = location
        application.notes = notes
        application.deadline = deadline
    }

    func deleteApplication(_ application: Application) throws {
        deleteCalls.append(application)
        if let deleteError {
            throw deleteError
        }
        storedApplications[application.id] = nil
    }

    func changeStatus(
        of application: Application,
        to newStatus: ApplicationStatus,
        note: String?,
        at date: Date
    ) throws {
        statusChangeCalls.append(StatusChangeCall(
            application: application,
            toStatus: newStatus,
            note: note,
            date: date
        ))
        if let statusChangeError {
            throw statusChangeError
        }
        application.status = newStatus
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
