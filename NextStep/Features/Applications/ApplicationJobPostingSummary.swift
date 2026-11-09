import Foundation

/// Display inputs for the application detail's associated-posting summary.
///
/// The summary renders only when the application is linked to a `JobPosting`; snapshot fields keep
/// rendering on their own when the posting is missing.
struct ApplicationJobPostingSummary: Equatable {
    let title: String
    let companyName: String
    let sourceName: String
    let jobURL: URL?

    init?(jobPosting: JobPosting?) {
        guard let jobPosting else { return nil }
        self.title = jobPosting.title
        self.companyName = jobPosting.companyName
        self.sourceName = jobPosting.intakeMethod.displayName
        self.jobURL = jobPosting.jobURL
    }
}
