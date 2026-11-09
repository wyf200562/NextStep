import Foundation
import SwiftData
import Testing
@testable import NextStep

@Suite("AppContainer")
struct AppContainerTests {
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
        #expect(container.jobRepository is SwiftDataJobRepository)
        #expect(container.matchProvider == nil)
    }

    @Test func inMemoryContainerProvidesWorkingProfileRepository() throws {
        let container = try AppContainer.makeInMemory()

        let profile = try container.userProfileRepository.fetchOrCreateProfile()

        #expect(profile.timeZoneIdentifier == TimeZone.current.identifier)
    }

    @Test func applicationRepositoryStaysUnavailableWhileJobRepositoryReadsTheCache() throws {
        let container = try AppContainer.makeInMemory()

        #expect(throws: RepositoryError.unavailable) {
            _ = try container.applicationRepository.allApplications()
        }
        #expect(try container.jobRepository.cachedJobs().isEmpty)
        #expect(container.jobRepository.lastRefreshAt(for: .remotive) == nil)
    }
}
