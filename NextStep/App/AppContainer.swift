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
    let jobSourceFactory: JobSourceFactory

    /// The matching service, or nil when the bundled lexicon fails to load.
    var matchProvider: (any MatchProviding)?

    /// The loaded matching lexicon shared by `MatchService` and the 我的 skill picker.
    /// `nil` means matching and skill selection degrade to unavailable.
    let matchingLexicon: MatchingLexicon?

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
        let resolvedFactory = jobSourceFactory ?? JobSourceFactory(
            makeRemote: { _ in PlaceholderRemoteJobSource() },
            makeManual: { ManualJobSource(input: $0) }
        )
        self.jobSourceFactory = resolvedFactory
        self.jobRepository = jobRepository ?? SwiftDataJobRepository(
            context: modelContainer.mainContext,
            dateProvider: dateProvider,
            jobSourceFactory: resolvedFactory
        )

        let lexicon: MatchingLexicon?
        do {
            lexicon = try matchingLexiconLoader.load()
        } catch {
            lexicon = nil
            AppLogger.matching.error(
                "Matching lexicon unavailable; matching and skill selection disabled: \(String(describing: error), privacy: .public)"
            )
        }
        self.matchingLexicon = lexicon

        if let matchProvider {
            self.matchProvider = matchProvider
        } else if let lexicon {
            self.matchProvider = MatchService(
                profileRepository: resolvedProfileRepository,
                lexicon: lexicon
            )
        } else {
            self.matchProvider = nil
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
