import Foundation
import Testing
@testable import NextStep

@Suite("ManualJobSource")
struct ManualJobSourceTests {
    private let fixedID = UUID(uuidString: "9F1B2C3D-4E5F-6789-ABCD-EF0123456789")!

    @Test func manualSourceProducesOneNormalizedDraft() async throws {
        let jobURL = URL(string: "https://example.com/jobs/ios-intern")!
        let input = ManualJobInput(
            title: "  iOS 开发实习生  ",
            companyName: "  星舟科技 ",
            descriptionPlainText: "\n 参与 iOS App 开发。\n",
            jobURL: jobURL,
            location: "  远程 · 中国 ",
            jobType: " Internship ",
            tags: [" Swift ", "", "  ", "SwiftUI", "Swift"]
        )
        let source = ManualJobSource(input: input, id: fixedID)

        let drafts = try await source.loadJobs()

        #expect(source.intakeMethod == .manual)
        #expect(drafts.count == 1)
        let draft = try #require(drafts.first)
        #expect(draft.identityKey == "manual:9f1b2c3d-4e5f-6789-abcd-ef0123456789")
        #expect(draft.intakeMethod == .manual)
        #expect(draft.title == "iOS 开发实习生")
        #expect(draft.companyName == "星舟科技")
        #expect(draft.descriptionPlainText == "参与 iOS App 开发。")
        #expect(draft.jobURL == jobURL)
        #expect(draft.location == "远程 · 中国")
        #expect(draft.jobType == "internship")
        #expect(draft.tags == ["Swift", "SwiftUI"])
        #expect(draft.externalJobID == nil)
        #expect(draft.publishedAt == nil)
    }

    @Test(arguments: [
        ManualJobInput(title: "   ", companyName: "星舟科技", descriptionPlainText: "参与 iOS 开发"),
        ManualJobInput(title: "iOS 开发实习生", companyName: "\n", descriptionPlainText: "参与 iOS 开发"),
        ManualJobInput(title: "iOS 开发实习生", companyName: "星舟科技", descriptionPlainText: "  "),
        ManualJobInput(
            title: "iOS 开发实习生",
            companyName: "星舟科技",
            descriptionPlainText: "参与 iOS 开发",
            jobURL: URL(string: "not-a-url")
        ),
        ManualJobInput(
            title: "iOS 开发实习生",
            companyName: "星舟科技",
            descriptionPlainText: "参与 iOS 开发",
            jobURL: URL(string: "ftp://example.com/job")
        ),
        ManualJobInput(
            title: "iOS 开发实习生",
            companyName: "星舟科技",
            descriptionPlainText: "参与 iOS 开发",
            jobURL: URL(string: "https://")
        ),
    ])
    func manualSourceRejectsBlankRequiredFieldsAndInvalidURLs(input: ManualJobInput) async {
        let source = ManualJobSource(input: input)

        await #expect(throws: JobSourceError.invalidInput) {
            try await source.loadJobs()
        }
    }

    @Test(arguments: [
        ("iOS Intern", nil, "internship"),
        ("市场实习生", "", "internship"),
        ("INTERN, Platform", "  ", "internship"),
        ("iOS Intern", "full_time", "full_time"),
        ("Backend Engineer", nil, nil),
        ("Backend Engineer", "  ", nil),
    ])
    func manualSourceInfersInternshipOnlyWhenJobTypeIsUnset(
        title: String,
        jobType: String?,
        expectedJobType: String?
    ) async throws {
        let input = ManualJobInput(
            title: title,
            companyName: "Acme",
            descriptionPlainText: "虚构 JD",
            jobType: jobType
        )

        let drafts = try await ManualJobSource(input: input).loadJobs()

        #expect(drafts.first?.jobType == expectedJobType)
    }
}
