import Foundation
import SwiftData
import Testing
@testable import NextStep

@Suite("AppContainer")
struct AppContainerTests {
    @MainActor
    private final class StubMatchProvider: MatchProviding {
        func evaluate(job: JobPosting) throws -> MatchResult? { nil }
        func evaluate(jobs: [JobPosting]) throws -> [String: MatchResult] { [:] }
        func eligibility(jobs: [JobPosting]) throws -> [String: Eligibility] { [:] }
    }

    @Test func wiresInjectedContainerDateProviderRouterAndRepositories() throws {
        let modelContainer = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let router = AppRouter(selectedTab: .applications)

        let container = AppContainer(
            modelContainer: modelContainer,
            dateProvider: FixedDateProvider(now: fixedNow),
            router: router
        )

        #expect(container.modelContainer === modelContainer)
        #expect(container.modelContext === modelContainer.mainContext)
        #expect(container.dateProvider.now == fixedNow)
        #expect(container.router === router)
        #expect(container.router.selectedTab == .applications)
        #expect(container.jobSourceFactory.makeManual(
            ManualJobInput(title: "iOS Intern", companyName: "Acme", descriptionPlainText: "JD")
        ).intakeMethod == .manual)
        let remoteSource = container.jobSourceFactory.makeRemote(JobQuery())
        #expect(remoteSource is RemotiveJobSource)
        #expect(remoteSource.intakeMethod == .remotive)
        #expect(container.jobRepository is SwiftDataJobRepository)
        let provider = try #require(container.matchProvider)
        #expect(provider is MatchService)
    }

    @Test func defaultJobRepositoryReadsTheInjectedRefreshLedger() throws {
        let modelContainer = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let suiteName = "NextStepTests.AppContainer.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let ledger = RefreshLedger(
            userDefaults: defaults,
            dateProvider: FixedDateProvider(now: now)
        )
        ledger.recordSuccess(for: .remotive)

        let container = AppContainer(
            modelContainer: modelContainer,
            dateProvider: FixedDateProvider(now: now),
            refreshLedger: ledger
        )

        #expect(container.refreshLedger === ledger)
        #expect(container.jobRepository.lastRefreshAt(for: .remotive) == now)
    }

    @Test func defaultContainerWiresMatchServiceFromBundledLexicons() throws {
        let modelContainer = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let container = AppContainer(modelContainer: modelContainer)

        let provider = try #require(container.matchProvider)
        #expect(provider is MatchService)
        #expect(container.matchingLexicon != nil)
    }

    @Test func injectedMatchProviderIsPreserved() throws {
        let modelContainer = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let provider = StubMatchProvider()

        let container = AppContainer(modelContainer: modelContainer, matchProvider: provider)

        #expect(container.matchProvider === provider)
    }

    @Test func matchingDegradesToNilWhenTheLexiconCannotLoad() throws {
        let modelContainer = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let loader = MatchingLexiconLoader(
            skillDictionaryURL: nil,
            roleDirectionURL: nil,
            locationURL: nil
        )

        let container = AppContainer(
            modelContainer: modelContainer,
            matchingLexiconLoader: loader
        )

        #expect(container.matchProvider == nil)
        #expect(container.matchingLexicon == nil)
    }

    @Test func inMemoryContainerProvidesWorkingProfileRepository() throws {
        let container = try AppContainer.makeInMemory()

        let profile = try container.userProfileRepository.fetchOrCreateProfile()

        #expect(profile.timeZoneIdentifier == TimeZone.current.identifier)
    }

    @Test func inMemoryContainerProvidesWorkingApplicationRepository() throws {
        let container = try AppContainer.makeInMemory()

        #expect(try container.applicationRepository.allApplications().isEmpty)
    }

    @Test func inMemoryContainerProvidesJobRepositoryReadingTheCache() throws {
        let container = try AppContainer.makeInMemory()

        #expect(try container.jobRepository.cachedJobs().isEmpty)
        #expect(container.jobRepository.lastRefreshAt(for: .remotive) == nil)
    }
}
