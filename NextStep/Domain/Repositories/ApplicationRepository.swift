import Foundation

/// The single write entry for tracked applications.
///
/// Status changes are validated by `ApplicationStateMachine`, update `Application.status` and
/// `lastModifiedAt`, and append a `StatusChange` in the same operation. `statusChanges(for:)`
/// returns records sorted by `changedAt` descending with `id` as the tie-breaker.
@MainActor
protocol ApplicationRepository: AnyObject {
    func allApplications() throws -> [Application]
    func application(id: UUID) throws -> Application?
    func applications(for jobPosting: JobPosting) throws -> [Application]
    func statusChanges(for application: Application) throws -> [StatusChange]

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
    ) throws -> Application

    func updateApplication(
        _ application: Application,
        companyName: String,
        roleTitle: String,
        jobURL: URL?,
        location: String?,
        notes: String?,
        deadline: Date?
    ) throws

    func deleteApplication(_ application: Application) throws

    func changeStatus(
        of application: Application,
        to newStatus: ApplicationStatus,
        note: String?,
        at date: Date
    ) throws

    @discardableResult
    func addInterviewRound(
        to application: Application,
        scheduledAt: Date,
        format: InterviewFormat,
        label: String?,
        contact: String?,
        notes: String?,
        result: InterviewResult
    ) throws -> InterviewRound

    func updateInterviewRound(
        _ round: InterviewRound,
        scheduledAt: Date,
        format: InterviewFormat,
        label: String?,
        contact: String?,
        notes: String?,
        result: InterviewResult
    ) throws

    func deleteInterviewRound(_ round: InterviewRound) throws
}
