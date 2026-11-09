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
        matchProvider: (any MatchProviding)? = nil,
        matchingLexiconLoader: MatchingLexiconLoader = MatchingLexiconLoader()
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
        let resolvedProfileRepository = userProfileRepository
            ?? SwiftDataUserProfileRepository(context: modelContainer.mainContext)
        self.userProfileRepository = resolvedProfileRepository
        self.jobRepository = jobRepository ?? UnavailableJobRepository()
        self.jobSourceFactory = jobSourceFactory

        if let matchProvider {
            self.matchProvider = matchProvider
        } else {
            do {
                let lexicon = try matchingLexiconLoader.load()
                self.matchProvider = MatchService(
                    profileRepository: resolvedProfileRepository,
                    lexicon: lexicon
                )
            } catch {
                AppLogger.matching.error(
                    "Matching lexicon unavailable; matching disabled: \(String(describing: error), privacy: .public)"
                )
                self.matchProvider = nil
            }
        }
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
