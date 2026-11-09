import SwiftUI

/// 申请 tab root. Owns its navigation path and the list filter; the router only queues requests.
struct ApplicationsTabView: View {
    @Environment(AppContainer.self) private var container
    @State private var path: [ApplicationsRoute] = []
    @State private var filter: ApplicationListFilter = .all

    var body: some View {
        @Bindable var router = container.router
        NavigationStack(path: $path) {
            ApplicationsView(filter: $filter)
                .navigationDestination(for: ApplicationsRoute.self) { route in
                    switch route {
                    case .detail(let applicationID):
                        ApplicationDetailView(container: container, applicationID: applicationID)
                    }
                }
        }
        .onChange(of: router.pendingRoute, initial: true) { _, _ in
            consumePendingRoute()
        }
    }

    private func consumePendingRoute() {
        guard let route = container.router.takePendingRoute(for: .applications) else { return }
        switch route {
        case .applicationDetail(let applicationID):
            path = [.detail(applicationID: applicationID)]
        case .applicationsList(let requestedFilter):
            filter = requestedFilter
            path.removeAll()
        case .discover, .profile:
            break
        }
    }
}
