import Foundation
import SwiftData
import Testing
@testable import NextStep

@Suite("Schema V1 and in-memory persistence")
struct SchemaV1Tests {
    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func schemaV1DeclaresFiveVersionedModelsAndAnEmptyMigrationPlan() {
        #expect(SchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(SchemaV1.models.count == 5)
        #expect(NextStepMigrationPlan.schemas.count == 1)
        #expect(NextStepMigrationPlan.stages.isEmpty)
    }

    @Test func inMemoryContainerRoundTripsAllModelsAndRelationships() throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext

        let posting = JobPosting(
            identityKey: JobIdentityKey.remotive(externalID: "12345"),
            title: "iOS Intern",
            companyName: "Acme",
            intakeMethod: .remotive,
            descriptionPlainText: "Build the app.",
            createdAt: referenceDate,
            externalJobID: "12345",
            jobURL: URL(string: "https://example.com/jobs/12345"),
            location: "Remote",
            jobType: "internship",
            tags: ["Swift", "SwiftUI"],
            publishedAt: referenceDate
        )
        let application = Application(
            companyName: "Acme",
            roleTitle: "iOS Intern",
            createdAt: referenceDate,
            jobPosting: posting,
            deadline: referenceDate.addingTimeInterval(86_400),
            notes: "内推",
            jobURL: URL(string: "https://example.com/jobs/12345"),
            location: "Remote"
        )
        let round = InterviewRound(
            scheduledAt: referenceDate.addingTimeInterval(3_600),
            format: .video,
            label: "一面"
        )
        let change = StatusChange(toStatus: .wishlist, changedAt: referenceDate)
        let profile = UserProfile(skills: ["Swift", "SwiftUI"], targetRoles: ["iOS 开发实习"])

        context.insert(posting)
        context.insert(application)
        application.interviewRounds.append(round)
        application.statusChanges.append(change)
        context.insert(profile)
        try context.save()

        let applications = try context.fetch(FetchDescriptor<Application>())
        let savedApplication = try #require(applications.first)
        #expect(applications.count == 1)
        #expect(savedApplication.status == .wishlist)
        #expect(savedApplication.statusRaw == "wishlist")
        #expect(savedApplication.jobPosting?.identityKey == "remotive:12345")
        #expect(savedApplication.interviewRounds.count == 1)
        #expect(savedApplication.interviewRounds.first?.label == "一面")
        #expect(savedApplication.interviewRounds.first?.application?.id == savedApplication.id)
        #expect(savedApplication.statusChanges.count == 1)
        #expect(savedApplication.statusChanges.first?.fromStatus == nil)
        #expect(savedApplication.statusChanges.first?.toStatus == .wishlist)

        let postings = try context.fetch(FetchDescriptor<JobPosting>())
        let savedPosting = try #require(postings.first)
        #expect(postings.count == 1)
        #expect(savedPosting.intakeMethod == .remotive)
        #expect(savedPosting.tags == ["Swift", "SwiftUI"])
        #expect(savedPosting.applications.count == 1)
        #expect(savedPosting.applications.first?.id == savedApplication.id)

        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(profiles.count == 1)
        #expect(profiles.first?.skills == ["Swift", "SwiftUI"])
        #expect(profiles.first?.targetRoles == ["iOS 开发实习"])
    }

    @Test func jobPostingIdentityKeyIsUniqueInTheSchema() throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let entity = try #require(schema.entitiesByName["JobPosting"])
        let identityKey = try #require(entity.attributesByName["identityKey"])
        #expect(identityKey.isUnique)
    }
}
