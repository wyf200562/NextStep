import Foundation
import Testing
@testable import NextStep

@Suite("Domain model defaults")
struct DomainModelTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func applicationDefaultsToWishlistAndKeepsRawStatusInSync() {
        let application = Application(
            companyName: "星河科技",
            roleTitle: "iOS 开发实习生",
            createdAt: referenceDate
        )

        #expect(application.status == .wishlist)
        #expect(application.statusRaw == "wishlist")
        #expect(application.lastModifiedAt == referenceDate)
        #expect(application.interviewRounds.isEmpty)
        #expect(application.statusChanges.isEmpty)
        #expect(application.deadline == nil)
        #expect(application.notes == nil)
        #expect(application.jobPosting == nil)

        application.status = .interview
        #expect(application.statusRaw == "interview")
        #expect(application.status == .interview)
    }

    @Test func jobPostingKeepsTypedIntakeMethodOverRawStorage() {
        let posting = JobPosting(
            identityKey: JobIdentityKey.remotive(externalID: "12345"),
            title: "iOS Intern",
            companyName: "Acme",
            intakeMethod: .remotive,
            descriptionPlainText: "Build things.",
            createdAt: referenceDate
        )

        #expect(posting.intakeMethod == .remotive)
        #expect(posting.intakeMethodRaw == "remotive")
        #expect(posting.tags.isEmpty)
        #expect(posting.applications.isEmpty)
        #expect(posting.externalJobID == nil)
        #expect(posting.publishedAt == nil)
    }

    @Test func interviewRoundDefaultsToPendingResult() {
        let round = InterviewRound(scheduledAt: referenceDate, format: .video)

        #expect(round.result == .pending)
        #expect(round.resultRaw == "pending")
        #expect(round.format == .video)
        #expect(round.formatRaw == "video")
        #expect(round.label == nil)
        #expect(round.contact == nil)
        #expect(round.notes == nil)
        #expect(round.application == nil)
    }

    @Test func statusChangeStartsWithoutAFromStatus() {
        let change = StatusChange(toStatus: .applied, changedAt: referenceDate)

        #expect(change.fromStatus == nil)
        #expect(change.fromStatusRaw == nil)
        #expect(change.toStatus == .applied)
        #expect(change.toStatusRaw == "applied")
        #expect(change.note == nil)
        #expect(change.application == nil)
    }

    @Test func userProfileDefaultsToEmptyCollectionsAndCurrentTimeZone() {
        let profile = UserProfile()

        #expect(profile.skills.isEmpty)
        #expect(profile.targetRoles.isEmpty)
        #expect(profile.preferredLocations.isEmpty)
        #expect(profile.timeZoneIdentifier == TimeZone.current.identifier)
        #expect(profile.availableFrom == nil)
        #expect(profile.availableUntil == nil)
        #expect(profile.graduationYear == nil)
    }
}
