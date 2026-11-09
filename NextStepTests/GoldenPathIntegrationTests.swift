import Foundation
import SwiftData
import Testing
@testable import NextStep

/// End-to-end golden-path verification at the data seam: complete the profile, paste a fictional
/// iOS internship JD, compute a match, import it as an application, drive the status machine, set a
/// deadline, add an interview round, derive the dashboard, then reopen the same store to prove the
/// data survives a relaunch. No UI, network, or system clock.
@Suite("Golden path integration")
@MainActor
struct GoldenPathIntegrationTests {
    private struct FailingRemoteSource: JobSource {
        let intakeMethod: JobIntakeMethod = .remotive

        func loadJobs() async throws -> [JobPostingDraft] {
            throw JobSourceError.offline
        }
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func makeContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(
            "NextStepGoldenPath",
            schema: schema,
            url: url
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: NextStepMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private func makeLedger(userDefaults: UserDefaults) -> RefreshLedger {
        RefreshLedger(
            userDefaults: userDefaults,
            dateProvider: FixedDateProvider(now: now, calendar: calendar)
        )
    }

    private func makeJobRepository(
        context: ModelContext,
        calendar: Calendar,
        ledger: RefreshLedger
    ) -> SwiftDataJobRepository {
        SwiftDataJobRepository(
            context: context,
            dateProvider: FixedDateProvider(now: now, calendar: calendar),
            jobSourceFactory: JobSourceFactory(
                makeRemote: { _ in FailingRemoteSource() },
                makeManual: { ManualJobSource(input: $0) }
            ),
            refreshLedger: ledger
        )
    }

    @Test func pasteMatchImportTrackAndRelaunchKeepsEverything() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "NextStepGoldenPath-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appending(path: "NextStep.store")
        let suiteName = "NextStepTests.GoldenPath.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let ledger = makeLedger(userDefaults: defaults)
        let lexicon = try MatchingLexiconLoader().load()
        let dateProvider = FixedDateProvider(now: now, calendar: calendar)
        var jobID: UUID?
        var applicationID: UUID?

        // First launch: paste a fictional JD, complete the profile, match, import, and track.
        do {
            let container = try makeContainer(at: storeURL)
            let context = container.mainContext
            let profileRepository = SwiftDataUserProfileRepository(context: context)
            let jobRepository = makeJobRepository(context: context, calendar: calendar, ledger: ledger)
            let applicationRepository = SwiftDataApplicationRepository(
                context: context,
                dateProvider: dateProvider
            )
            let matchService = MatchService(
                profileRepository: profileRepository,
                lexicon: lexicon
            )

            #expect(try profileRepository.fetchOrCreateProfile().skills.isEmpty)

            let job = try await jobRepository.importManual(ManualJobInput(
                title: "iOS 开发实习生",
                companyName: "星河科技（虚构）",
                descriptionPlainText: "参与 SwiftUI 应用开发，要求熟悉 Swift、SwiftUI、UIKit 与 Git。",
                jobURL: URL(string: "https://example.com/jobs/ios-intern"),
                location: "上海",
                jobType: "internship",
                tags: ["Swift", "SwiftUI"]
            ))
            jobID = job.id

            // The profile gate blocks matching until the profile is complete.
            #expect(try matchService.evaluate(job: job) == nil)

            let profile = try profileRepository.fetchOrCreateProfile()
            profile.skills = ["Swift", "SwiftUI", "UIKit", "Git"]
            profile.targetRoles = ["iOS 开发实习"]
            profile.preferredLocations = ["上海"]
            profile.timeZoneIdentifier = "Asia/Shanghai"
            try profileRepository.save(profile)

            let match = try #require(try matchService.evaluate(job: job))
            let score = try #require(match.score)
            #expect(match.eligibility == .eligible)
            #expect((0...100).contains(score))
            #expect(match.components.total == score)
            #expect(!match.matchedSkills.isEmpty)

            let application = try applicationRepository.createApplication(
                companyName: job.companyName,
                roleTitle: job.title,
                initialStatus: .wishlist,
                statusDate: now,
                deadline: nil,
                jobURL: job.jobURL,
                location: job.location,
                notes: "虚构演示申请",
                jobPosting: job
            )
            applicationID = application.id

            try applicationRepository.changeStatus(
                of: application,
                to: .applied,
                note: nil,
                at: now.addingTimeInterval(60)
            )
            try applicationRepository.changeStatus(
                of: application,
                to: .interview,
                note: "约面",
                at: now.addingTimeInterval(120)
            )
            let deadline = calendar.date(byAdding: .day, value: 2, to: now) ?? now
            let interviewDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            try applicationRepository.updateApplication(
                application,
                companyName: job.companyName,
                roleTitle: job.title,
                jobURL: job.jobURL,
                location: job.location,
                notes: "虚构演示申请",
                deadline: deadline
            )
            try applicationRepository.addInterviewRound(
                to: application,
                scheduledAt: interviewDate,
                format: .video,
                label: "一面",
                contact: nil,
                notes: nil,
                result: .pending
            )

            let snapshot = DashboardBuilder.snapshot(
                applications: try applicationRepository.allApplications(),
                now: now,
                calendar: calendar
            )
            #expect(snapshot.activeCount == 1)
            #expect(snapshot.dueSoonCount == 1)
            #expect(snapshot.upcomingEvents.contains { $0.kind == .interview && $0.roundLabel == "一面" })
            #expect(snapshot.upcomingEvents.contains { $0.kind == .deadline })
            #expect(snapshot.recentApplications.first?.id == application.id)
            #expect(ledger.nextAttemptBlock(for: .remotive) == nil)
        }

        // Relaunch: reopen the same store file with fresh repositories.
        do {
            let container = try makeContainer(at: storeURL)
            let context = container.mainContext
            let profileRepository = SwiftDataUserProfileRepository(context: context)
            let jobRepository = makeJobRepository(context: context, calendar: calendar, ledger: ledger)
            let applicationRepository = SwiftDataApplicationRepository(
                context: context,
                dateProvider: dateProvider
            )

            let profile = try profileRepository.fetchOrCreateProfile()
            #expect(profile.skills == ["Swift", "SwiftUI", "UIKit", "Git"])
            #expect(profile.targetRoles == ["iOS 开发实习"])

            let jobs = try jobRepository.cachedJobs()
            #expect(jobs.count == 1)
            #expect(jobs.first?.id == jobID)
            #expect(jobs.first?.identityKey.hasPrefix("manual:") == true)

            let applications = try applicationRepository.allApplications()
            #expect(applications.count == 1)
            let application = try #require(applications.first)
            #expect(application.id == applicationID)
            #expect(application.status == .interview)
            #expect(application.jobPosting?.id == jobID)
            #expect(application.interviewRounds.count == 1)
            #expect(application.interviewRounds.first?.label == "一面")

            let changes = try applicationRepository.statusChanges(for: application)
            #expect(changes.count == 3)
            #expect(Set(changes.map(\.toStatus)) == [.wishlist, .applied, .interview])

            let snapshot = DashboardBuilder.snapshot(
                applications: applications,
                now: now,
                calendar: calendar
            )
            #expect(snapshot.hasEvents)
        }
    }
}
