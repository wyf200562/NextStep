import Foundation

/// A non-persisted job posting produced by a `JobSource`.
///
/// Fields mirror `JobPosting` minus the local primary key, `createdAt`, and relationships.
/// Normalization (trimming, HTML-to-text, date parsing) happens in the source, not the repository.
nonisolated struct JobPostingDraft: Sendable, Equatable {
    let identityKey: String
    let intakeMethod: JobIntakeMethod
    let title: String
    let companyName: String
    let descriptionPlainText: String
    let externalJobID: String?
    let jobURL: URL?
    let location: String?
    let jobType: String?
    let tags: [String]
    let publishedAt: Date?
    let salary: String?
    let companyLogoURL: URL?

    init(
        identityKey: String,
        intakeMethod: JobIntakeMethod,
        title: String,
        companyName: String,
        descriptionPlainText: String,
        externalJobID: String? = nil,
        jobURL: URL? = nil,
        location: String? = nil,
        jobType: String? = nil,
        tags: [String] = [],
        publishedAt: Date? = nil,
        salary: String? = nil,
        companyLogoURL: URL? = nil
    ) {
        self.identityKey = identityKey
        self.intakeMethod = intakeMethod
        self.title = title
        self.companyName = companyName
        self.descriptionPlainText = descriptionPlainText
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
