import Foundation
import Testing
@testable import NextStep

@Suite("ApplicationJobPostingSummary")
struct ApplicationJobPostingSummaryTests {
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func makePosting(
        intakeMethod: JobIntakeMethod,
        jobURL: URL?
    ) -> JobPosting {
        JobPosting(
            identityKey: "\(intakeMethod.rawValue):00000000-0000-0000-0000-000000000021",
            title: "iOS 开发实习生",
            companyName: "星舟科技",
            intakeMethod: intakeMethod,
            descriptionPlainText: "参与 iOS 开发",
            createdAt: createdAt,
            jobURL: jobURL
        )
    }

    @Test func summaryCarriesTitleCompanySourceAndLink() throws {
        let url = try #require(URL(string: "https://remotive.com/jobs/21"))
        let summary = try #require(
            ApplicationJobPostingSummary(
                jobPosting: makePosting(intakeMethod: .remotive, jobURL: url)
            )
        )

        #expect(summary.title == "iOS 开发实习生")
        #expect(summary.companyName == "星舟科技")
        #expect(summary.sourceName == "Remotive")
        #expect(summary.jobURL == url)
    }

    @Test func manualSummaryUsesChineseSourceAndAllowsNoLink() throws {
        let summary = try #require(
            ApplicationJobPostingSummary(
                jobPosting: makePosting(intakeMethod: .manual, jobURL: nil)
            )
        )

        #expect(summary.sourceName == "手动导入")
        #expect(summary.jobURL == nil)
    }

    @Test func missingPostingProducesNoSummary() {
        #expect(ApplicationJobPostingSummary(jobPosting: nil) == nil)
    }
}
