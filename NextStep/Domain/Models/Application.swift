import Foundation
import SwiftData

/// A single tracked job application.
///
/// Company, role, URL, and location are stored as snapshots so an application stays readable
/// after its optional `JobPosting` is deleted. Derived values such as `appliedAt` are never stored.
@Model
final class Application {
    var id: UUID
    var companyName: String
    var roleTitle: String
    var statusRaw: String
    var createdAt: Date
    var lastModifiedAt: Date
    var deadline: Date?
    var notes: String?
    var jobURL: URL?
    var location: String?

    var jobPosting: JobPosting?

    @Relationship(deleteRule: .cascade, inverse: \InterviewRound.application)
    var interviewRounds: [InterviewRound] = []

    @Relationship(deleteRule: .cascade, inverse: \StatusChange.application)
    var statusChanges: [StatusChange] = []

    /// Typed view over `statusRaw`. `statusRaw` is the persisted source of truth for predicates and sorting.
    var status: ApplicationStatus {
        get { ApplicationStatus(rawValue: statusRaw) ?? .wishlist }
        set { statusRaw = newValue.rawValue }
    }

    /// The first `StatusChange` that marked this application as applied.
    ///
    /// Records are ordered by `changedAt` ascending with `id` as the tie-breaker. The initial
    /// creation record participates when it is itself `.applied`. Derived, never persisted.
    var firstAppliedChange: StatusChange? {
        statusChanges
            .filter { $0.toStatus == .applied }
            .min { lhs, rhs in
                if lhs.changedAt != rhs.changedAt { return lhs.changedAt < rhs.changedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    /// `changedAt` of the first applied record; nil until the application has been applied.
    /// Derived, never persisted.
    var appliedAt: Date? {
        firstAppliedChange?.changedAt
    }

    init(
        id: UUID = UUID(),
        companyName: String,
        roleTitle: String,
        status: ApplicationStatus = .wishlist,
        createdAt: Date,
        lastModifiedAt: Date? = nil,
        jobPosting: JobPosting? = nil,
        deadline: Date? = nil,
        notes: String? = nil,
        jobURL: URL? = nil,
        location: String? = nil
    ) {
        self.id = id
        self.companyName = companyName
        self.roleTitle = roleTitle
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.lastModifiedAt = lastModifiedAt ?? createdAt
        self.jobPosting = jobPosting
        self.deadline = deadline
        self.notes = notes
        self.jobURL = jobURL
        self.location = location
    }
}
