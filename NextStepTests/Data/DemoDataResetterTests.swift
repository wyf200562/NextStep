import Foundation
import SwiftData
import Testing
@testable import NextStep

@Suite("DemoDataResetter")
@MainActor
struct DemoDataResetterTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "NextStepTests.DemoDataResetter.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func makeLedger(
        userDefaults: UserDefaults
    ) -> RefreshLedger {
        RefreshLedger(
            userDefaults: userDefaults,
            dateProvider: FixedDateProvider(now: referenceDate)
        )
    }

    @Test func resetDeletesAllFiveModelTypesAndClearsTheRefreshLedger() throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let ledger = makeLedger(userDefaults: defaults)
        ledger.recordAttempt(for: .remotive)
        ledger.recordSuccess(for: .remotive)

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
        let round = InterviewRound(scheduledAt: referenceDate, format: .video)
        let change = StatusChange(toStatus: .wishlist, changedAt: referenceDate)
        let profile = UserProfile(
            skills: ["Swift"],
            targetRoles: ["iOS 开发实习"],
            timeZoneIdentifier: "Asia/Shanghai"
        )

        context.insert(posting)
        context.insert(application)
        application.interviewRounds.append(round)
        application.statusChanges.append(change)
        context.insert(profile)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Application>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<JobPosting>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<InterviewRound>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<StatusChange>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<UserProfile>()).count == 1)

        let resetter = DemoDataResetter(context: context, refreshLedger: ledger)
        try resetter.reset()

        #expect(try context.fetch(FetchDescriptor<Application>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<JobPosting>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<InterviewRound>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<StatusChange>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<UserProfile>()).isEmpty)
        #expect(ledger.lastSuccess(for: .remotive) == nil)
        #expect(ledger.nextAttemptBlock(for: .remotive) == nil)
    }

    @Test func resettingAnEmptyStoreIsANoOp() throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let resetter = DemoDataResetter(
            context: context,
            refreshLedger: makeLedger(userDefaults: defaults)
        )

        try resetter.reset()
        try resetter.reset()

        #expect(try context.fetch(FetchDescriptor<Application>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<JobPosting>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<InterviewRound>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<StatusChange>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<UserProfile>()).isEmpty)
    }

    @Test func resettingTwiceKeepsTheStoreEmpty() throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let ledger = makeLedger(userDefaults: defaults)
        let profile = UserProfile(skills: ["Swift"], targetRoles: ["iOS 开发实习"])
        context.insert(profile)
        try context.save()
        let resetter = DemoDataResetter(context: context, refreshLedger: ledger)

        try resetter.reset()
        try resetter.reset()

        #expect(try context.fetch(FetchDescriptor<UserProfile>()).isEmpty)
        #expect(ledger.lastSuccess(for: .remotive) == nil)
    }
}
