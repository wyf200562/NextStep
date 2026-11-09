import Foundation
import Observation
import os

/// Owns the job detail screen: cached-posting lookup and the import CTA's dedup state.
///
/// The ViewModel never touches `ModelContext` or navigation; every read and write goes through
/// `JobRepository` / `ApplicationRepository`, and the View routes with the returned ids.
@Observable
@MainActor
final class JobDetailViewModel {
    /// What the import CTA should offer, derived from the posting's existing applications.
    enum ImportAction: Equatable {
        /// No application references this posting yet.
        case importNew
        /// Every existing application is terminal (offer / rejected / withdrawn); confirm, then create.
        case importAgain
        /// An active application (wishlist / applied / oa / interview) already exists; never duplicate it.
        case viewExisting(applicationID: UUID)
    }

    private let jobRepository: any JobRepository
    private let applicationRepository: any ApplicationRepository
    private let dateProvider: any DateProvider
    private let jobID: UUID

    private(set) var state: LoadState<JobPosting> = .idle
    private(set) var importAction: ImportAction = .importNew
    private(set) var isImporting = false
    /// Chinese copy for a failed import; raw errors are never shown.
    private(set) var importErrorMessage: String?

    init(
        jobRepository: any JobRepository,
        applicationRepository: any ApplicationRepository,
        dateProvider: any DateProvider,
        jobID: UUID
    ) {
        self.jobRepository = jobRepository
        self.applicationRepository = applicationRepository
        self.dateProvider = dateProvider
        self.jobID = jobID
    }

    var job: JobPosting? {
        state.value
    }

    /// True when the CTA must ask for confirmation before creating a second application.
    var importRequiresConfirmation: Bool {
        importAction == .importAgain
    }

    /// Chinese load-failure copy; raw errors are never shown.
    var loadErrorMessage: String? {
        guard case .failed(let error) = state else { return nil }
        if error is JobDetailLoadError {
            return "岗位不存在或已被删除"
        }
        return "加载失败，请稍后重试"
    }

    /// Loads the cached posting and classifies the import CTA.
    func load() {
        state = .loading
        do {
            guard let posting = try jobRepository.cachedJobs().first(where: { $0.id == jobID }) else {
                state = .failed(JobDetailLoadError.notFound)
                return
            }
            state = .loaded(posting)
            importAction = classifyImportAction(for: posting)
        } catch {
            AppLogger.ui.error(
                "Failed to load job detail: \(error.localizedDescription, privacy: .public)"
            )
            state = .failed(error)
        }
    }

    /// Creates the application from the posting snapshot and returns its id so the View can route.
    ///
    /// Returns nil without writing when an active application already exists (no duplicates), when
    /// a terminal-only re-import has not been confirmed, when the posting is not loaded, or when the
    /// save fails (Chinese copy goes to `importErrorMessage`).
    @discardableResult
    func importApplication(confirmed: Bool = false) -> UUID? {
        guard case .loaded(let posting) = state, !isImporting else { return nil }
        switch importAction {
        case .viewExisting:
            return nil
        case .importAgain where !confirmed:
            return nil
        case .importNew, .importAgain:
            break
        }

        isImporting = true
        defer { isImporting = false }
        importErrorMessage = nil

        do {
            let application = try applicationRepository.createApplication(
                companyName: posting.companyName,
                roleTitle: posting.title,
                initialStatus: .wishlist,
                statusDate: dateProvider.now,
                deadline: nil,
                jobURL: posting.jobURL,
                location: posting.location,
                notes: nil,
                jobPosting: posting
            )
            importAction = .viewExisting(applicationID: application.id)
            return application.id
        } catch {
            AppLogger.ui.error(
                "Failed to import a job as an application: \(error.localizedDescription, privacy: .public)"
            )
            importErrorMessage = "保存失败，请重试"
            return nil
        }
    }

    func clearImportError() {
        importErrorMessage = nil
    }

    private func classifyImportAction(for posting: JobPosting) -> ImportAction {
        do {
            let applications = try applicationRepository.applications(for: posting)
            if let active = applications.first(where: { Self.isActive($0.status) }) {
                return .viewExisting(applicationID: active.id)
            }
            return applications.isEmpty ? .importNew : .importAgain
        } catch {
            AppLogger.ui.error(
                "Failed to check existing applications: \(error.localizedDescription, privacy: .public)"
            )
            return .importNew
        }
    }

    /// Active statuses keep the posting out of the re-import path: duplicates are never created.
    private static func isActive(_ status: ApplicationStatus) -> Bool {
        switch status {
        case .wishlist, .applied, .oa, .interview: true
        case .offer, .rejected, .withdrawn: false
        }
    }
}

/// Typed failures surfaced by `JobDetailViewModel.state`.
nonisolated enum JobDetailLoadError: Error, Equatable, Sendable {
    /// The cached posting no longer exists (for example, after local data was cleared).
    case notFound
}
