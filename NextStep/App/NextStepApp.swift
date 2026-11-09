import os
import SwiftUI

/// The composition root for the app. Container creation (and retry after a store failure) lives
/// here; `AppRootView` only routes the resulting state.
@main
struct NextStepApp: App {
    @State private var container: AppContainer?
    @State private var didFailToOpenStore = false

    var body: some Scene {
        WindowGroup {
            AppRootView(
                container: container,
                didFailToOpenStore: didFailToOpenStore,
                onRetry: loadContainer
            )
            .task {
                guard container == nil, !didFailToOpenStore else { return }
                loadContainer()
            }
        }
    }

    @MainActor
    private func loadContainer() {
        didFailToOpenStore = false
        do {
            container = try AppContainer.makeDefault()
        } catch {
            AppLogger.app.error(
                "Failed to open the local store: \(error.localizedDescription, privacy: .public)"
            )
            didFailToOpenStore = true
        }
    }
}
