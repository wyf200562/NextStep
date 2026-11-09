import Foundation
import Testing
@testable import NextStep

@Suite("RemotiveDTO")
struct RemotiveDTOTests {
    private func decode(_ json: String) throws -> RemotiveJobsResponse {
        try JSONDecoder().decode(RemotiveJobsResponse.self, from: Data(json.utf8))
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func utcDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        utcCalendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            )
        )!
    }

    @Test func mapsEveryDocumentedFieldToADraft() throws {
        let json = """
        {
          "0-legal-notice": "Sample legal notice",
          "00-warning": "Sample stale warning",
          "job-count": 1,
          "total-job-count": 1,
          "jobs": [
            {
              "id": 2091134,
              "url": "https://remotive.com/remote-jobs/software-dev/ios-intern-2091134",
              "title": "iOS Intern",
              "company_name": "Sample Labs",
              "company_logo_url": "https://remotive.com/logos/sample-labs.png",
              "category": "Software Development",
              "tags": ["Swift", "SwiftUI"],
              "job_type": "INTERNSHIP",
              "publication_date": "2026-11-06T08:51:01",
              "candidate_required_location": "Worldwide",
              "salary": "$30,000 - $40,000",
              "description": "<p>Build with <strong>Swift</strong> &amp; SwiftUI.</p>",
              "unknown_field": { "nested": true }
            }
          ]
        }
        """
        let response = try decode(json)
        let draft = try #require(response.drafts.first)

        #expect(response.jobCount == 1)
        #expect(response.totalJobCount == 1)
        #expect(response.drafts.count == 1)
        #expect(draft.identityKey == "remotive:2091134")
        #expect(draft.intakeMethod == .remotive)
        #expect(draft.externalJobID == "2091134")
        #expect(draft.title == "iOS Intern")
        #expect(draft.companyName == "Sample Labs")
        #expect(draft.descriptionPlainText == "Build with Swift & SwiftUI.")
        #expect(draft.jobURL == URL(string: "https://remotive.com/remote-jobs/software-dev/ios-intern-2091134"))
        #expect(draft.location == "Worldwide")
        #expect(draft.jobType == "internship")
        #expect(draft.tags == ["Swift", "SwiftUI"])
        #expect(draft.publishedAt == utcDate(year: 2026, month: 11, day: 6, hour: 8, minute: 51, second: 1))
        #expect(draft.salary == "$30,000 - $40,000")
        #expect(draft.companyLogoURL == URL(string: "https://remotive.com/logos/sample-labs.png"))
    }

    @Test func skipsItemsMissingIDTitleOrCompanyAndKeepsTheRest() throws {
        let json = """
        {
          "job-count": 6,
          "jobs": [
            { "title": "No ID", "company_name": "Acme" },
            { "id": 11, "company_name": "Acme" },
            { "id": 12, "title": "No Company" },
            { "id": 13, "title": "   ", "company_name": "Acme" },
            { "id": 14, "title": "Blank Company", "company_name": "  " },
            { "id": 15, "title": "Valid Intern", "company_name": "Acme", "job_type": "internship" }
          ]
        }
        """
        let response = try decode(json)

        #expect(response.drafts.count == 1)
        #expect(response.drafts.map(\.identityKey) == ["remotive:15"])
        #expect(response.drafts.first?.title == "Valid Intern")
    }

    @Test func missingDescriptionBecomesAnEmptyPlainText() throws {
        let json = """
        { "jobs": [ { "id": 1, "title": "iOS Intern", "company_name": "Acme" } ] }
        """
        let draft = try #require(try decode(json).drafts.first)

        #expect(draft.descriptionPlainText == "")
    }

    @Test func badDateBecomesNilWithoutFailingTheBatch() throws {
        let json = """
        {
          "jobs": [
            {
              "id": 1,
              "title": "Bad Date",
              "company_name": "Acme",
              "publication_date": "not-a-date"
            },
            {
              "id": 2,
              "title": "Good Date",
              "company_name": "Acme",
              "publication_date": "2026-11-06T08:51:01Z"
            }
          ]
        }
        """
        let response = try decode(json)

        #expect(response.drafts.count == 2)
        #expect(response.drafts[0].publishedAt == nil)
        #expect(response.drafts[1].publishedAt == utcDate(year: 2026, month: 11, day: 6, hour: 8, minute: 51, second: 1))
    }

    @Test(arguments: [
        "2026-11-06T08:51:01",
        "2026-11-06T08:51:01Z",
        "2026-11-06T08:51:01.000Z",
        "2026-11-06T08:51:01+00:00",
    ])
    func parsesISO8601Variants(dateString: String) throws {
        let json = """
        { "jobs": [ { "id": 1, "title": "iOS Intern", "company_name": "Acme", "publication_date": "\(dateString)" } ] }
        """
        let draft = try #require(try decode(json).drafts.first)

        #expect(draft.publishedAt == utcDate(year: 2026, month: 11, day: 6, hour: 8, minute: 51, second: 1))
    }

    @Test func decodesZeroJobsAsAValidEmptySample() throws {
        let json = """
        {
          "0-legal-notice": "Sample legal notice",
          "00-warning": "Sample stale warning",
          "job-count": 0,
          "total-job-count": 0,
          "jobs": []
        }
        """
        let response = try decode(json)

        #expect(response.jobCount == 0)
        #expect(response.totalJobCount == 0)
        #expect(response.drafts.isEmpty)
    }

    @Test func decodesATwelveJobDailySample() throws {
        let jobs = (0..<12).map { index in
            """
            {
              "id": \(2091130 + index),
              "title": "Sample Role \(index)",
              "company_name": "Sample Company \(index)",
              "job_type": "full_time",
              "publication_date": "2026-11-06T08:51:01",
              "description": "<p>Sample description \(index)</p>"
            }
            """
        }.joined(separator: ",")
        let json = """
        { "job-count": 12, "total-job-count": 12, "jobs": [\(jobs)] }
        """

        let response = try decode(json)

        #expect(response.drafts.count == 12)
        #expect(response.drafts.allSatisfy { $0.intakeMethod == .remotive })
        #expect(response.drafts.first?.identityKey == "remotive:2091130")
        #expect(response.drafts.last?.identityKey == "remotive:2091141")
    }

    @Test func nonWebURLsBecomeNilInsteadOfInvalidDrafts() throws {
        let json = """
        {
          "jobs": [
            {
              "id": 1,
              "title": "iOS Intern",
              "company_name": "Acme",
              "url": "not a url",
              "company_logo_url": "ftp://example.com/logo.png"
            }
          ]
        }
        """
        let draft = try #require(try decode(json).drafts.first)

        #expect(draft.jobURL == nil)
        #expect(draft.companyLogoURL == nil)
    }

    @Test func missingJobsKeyIsADecodingFailure() {
        let json = """
        { "job-count": 0, "total-job-count": 0 }
        """
        #expect(throws: (any Error).self) {
            try decode(json)
        }
    }
}
