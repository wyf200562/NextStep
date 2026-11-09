import SwiftUI

/// 概览 tab root. The dashboard itself arrives in a later slice.
struct OverviewTabView: View {
    @Environment(AppContainer.self) private var container
    @State private var path: [OverviewRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            OverviewView()
                .navigationDestination(for: OverviewRoute.self) { route in
                    switch route {
                    case .applicationDetail(let applicationID):
                        ApplicationDetailView(container: container, applicationID: applicationID)
                    }
                }
        }
    }
}
