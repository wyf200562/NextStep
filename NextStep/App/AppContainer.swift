import Foundation
import Observation
import os
import SwiftData

/// The composition root: owns the single `ModelContext`, repositories, time source, and router.
///
/// Created once by `NextStepApp` and injected through the SwiftUI environment. Views read what they
/// need and hold their own `@State` ViewModels; the container itself is not a ViewModel.
@Observable
@MainActor
final class AppContainer {
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    let dateProvider: any DateProvider
    let router: AppRouter
    let applicationRepository: any ApplicationRepository
    let userProfileRepository: any UserProfileRepository
    let jobRepository: any JobRepository

    /// Reserved slots for services owned by later slices (ingestion and matching).
    var jobSourceFactory: JobSourceFactory?
    var matchProvider: (any MatchProviding)?

    init(
        modelContainer: ModelContainer,
        dateProvider: any DateProvider = SystemDateProvider(),
        router: AppRouter = AppRouter(),
        applicationRepository: (any ApplicationRepository)? = nil,
        userProfileRepository: (any UserProfileRepository)? = nil,
        jobRepository: (any JobRepository)? = nil,
        jobSourceFactory: JobSourceFactory? = nil,
        matchProvider: (any MatchProviding)? = nil
    ) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
        self.dateProvider = dateProvider
        self.router = router
        self.applicationRepository = applicationRepository
            ?? SwiftDataApplicationRepository(
                context: modelContainer.mainContext,
                dateProvider: dateProvider
            )
        self.userProfileRepository = userProfileRepository
            ?? SwiftDataUserProfileRepository(context: modelContainer.mainContext)
        self.jobRepository = jobRepository ?? UnavailableJobRepository()
        self.jobSourceFactory = jobSourceFactory
        self.matchProvider = matchProvider
    }

    /// Creates the production container backed by the on-disk store.
    static func makeDefault() throws -> AppContainer {
        let modelContainer = try ModelContainerFactory.makeContainer()
        AppLogger.app.info("Opened the on-disk SwiftData store")
        return AppContainer(modelContainer: modelContainer)
    }

    /// Creates a fully in-memory container for tests and Previews.
    static func makeInMemory(
        dateProvider: any DateProvider = SystemDateProvider(),
        router: AppRouter = AppRouter()
    ) throws -> AppContainer {
        let modelContainer = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        return AppContainer(modelContainer: modelContainer, dateProvider: dateProvider, router: router)
    }
}
