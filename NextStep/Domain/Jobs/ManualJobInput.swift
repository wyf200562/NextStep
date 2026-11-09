import Foundation

/// Raw input from the manual "paste a JD" form.
nonisolated struct ManualJobInput: Sendable, Equatable {
    var title: String
    var companyName: String
    var descriptionPlainText: String
    var jobURL: URL?
    var location: String?
    var jobType: String?
    var tags: [String]

    init(
        title: String,
        companyName: String,
        descriptionPlainText: String,
        jobURL: URL? = nil,
        location: String? = nil,
        jobType: String? = nil,
        tags: [String] = []
    ) {
        self.title = title
        self.companyName = companyName
        self.descriptionPlainText = descriptionPlainText
        self.jobURL = jobURL
        self.location = location
        self.jobType = jobType
        self.tags = tags
    }
}
