import SwiftUI

/// 发现 tab root. The page title is deliberately "Discover".
struct DiscoverTabView: View {
    @Environment(AppContainer.self) private var container
    @State private var path: [DiscoverRoute] = []

    var body: some View {
        @Bindable var router = container.router
        NavigationStack(path: $path) {
            DiscoverView()
                .navigationDestination(for: DiscoverRoute.self) { route in
                    switch route {
                    case .jobDetail(let jobID):
                        JobDetailView(jobID: jobID)
                    case .manualImport:
                        ManualImportView { jobID in
                            // Replace the form with the new posting's detail; going back lands on Discover.
                            path = [.jobDetail(jobID: jobID)]
                        }
                    }
                }
        }
        .onChange(of: router.pendingRoute, initial: true) { _, _ in
            _ = container.router.takePendingRoute(for: .discover)
        }
    }
}
