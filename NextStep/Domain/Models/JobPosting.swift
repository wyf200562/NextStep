import Foundation
import SwiftData

/// A job posting cached locally from Remotive or entered manually.
///
/// `identityKey` is the source-qualified stable identity used for upserts. Deleting a posting
/// nullifies `Application.jobPosting`; application snapshot fields remain intact.
@Model
final class JobPosting {
    var id: UUID
    var title: String
    var companyName: String
    var intakeMethodRaw: String
    var descriptionPlainText: String
    var createdAt: Date
    @Attribute(.unique) var identityKey: String
    var externalJobID: String?
    var jobURL: URL?
    var location: String?
    var jobType: String?
    var tags: [String] = []
    var publishedAt: Date?
    var salary: String?
    var companyLogoURL: URL?

    @Relationship(deleteRule: .nullify, inverse: \Application.jobPosting)
    var applications: [Application] = []

    /// Typed view over `intakeMethodRaw`.
    var intakeMethod: JobIntakeMethod {
        get { JobIntakeMethod(rawValue: intakeMethodRaw) ?? .manual }
        set { intakeMethodRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        identityKey: String,
        title: String,
        companyName: String,
        intakeMethod: JobIntakeMethod,
        descriptionPlainText: String,
        createdAt: Date,
        externalJobID: String? = nil,
        jobURL: URL? = nil,
        location: String? = nil,
        jobType: String? = nil,
        tags: [String] = [],
        publishedAt: Date? = nil,
        salary: String? = nil,
        companyLogoURL: URL? = nil
    ) {
        self.id = id
        self.identityKey = identityKey
        self.title = title
        self.companyName = companyName
        self.intakeMethodRaw = intakeMethod.rawValue
        self.descriptionPlainText = descriptionPlainText
        self.createdAt = createdAt
        self.externalJobID = externalJobID
        self.jobURL = jobURL
        self.location = location
        self.jobType = jobType
        self.tags = tags
        self.publishedAt = publishedAt
        self.salary = salary
        self.companyLogoURL = companyLogoURL
    }
}
