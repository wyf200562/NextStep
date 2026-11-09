import Foundation
import SwiftData
import Testing
@testable import NextStep

@Suite("Relationship delete rules")
struct RelationshipRulesTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func deletingApplicationCascadesRoundsAndStatusChangesButKeepsJobPosting() throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext

        let posting = JobPosting(
            identityKey: JobIdentityKey.remotive(externalID: "42"),
            title: "iOS Intern",
            companyName: "Acme",
            intakeMethod: .remotive,
            descriptionPlainText: "Build the app.",
            createdAt: referenceDate
        )
        let application = Application(
            companyName: "Acme",
            roleTitle: "iOS Intern",
            createdAt: referenceDate,
            jobPosting: posting
        )
        let round = InterviewRound(scheduledAt: referenceDate, format: .onsite)
        let change = StatusChange(toStatus: .wishlist, changedAt: referenceDate)

        context.insert(posting)
        context.insert(application)
        application.interviewRounds.append(round)
        application.statusChanges.append(change)
        try context.save()

        context.delete(application)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<InterviewRound>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<StatusChange>()).isEmpty)
        let postings = try context.fetch(FetchDescriptor<JobPosting>())
        #expect(postings.count == 1)
        #expect(postings.first?.applications.isEmpty == true)
    }

    @Test func deletingJobPostingNullifiesApplicationLinkAndKeepsSnapshot() throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext

        let posting = JobPosting(
            identityKey: JobIdentityKey.manual(),
            title: "iOS Intern",
            companyName: "星河科技",
            intakeMethod: .manual,
            descriptionPlainText: "虚构 JD",
            createdAt: referenceDate
        )
        let application = Application(
            companyName: "星河科技",
            roleTitle: "iOS Intern",
            createdAt: referenceDate,
            jobPosting: posting,
            jobURL: URL(string: "https://example.com/job"),
            location: "上海"
        )
        context.insert(posting)
        context.insert(application)
        try context.save()

        context.delete(posting)
        try context.save()

        let applications = try context.fetch(FetchDescriptor<Application>())
        let savedApplication = try #require(applications.first)
        #expect(applications.count == 1)
        #expect(savedApplication.jobPosting == nil)
        #expect(savedApplication.companyName == "星河科技")
        #expect(savedApplication.location == "上海")
        #expect(savedApplication.jobURL == URL(string: "https://example.com/job"))
    }
}
