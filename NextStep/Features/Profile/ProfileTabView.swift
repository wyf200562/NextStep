import SwiftUI

/// 我的 tab root.
struct ProfileTabView: View {
    @Environment(AppContainer.self) private var container
    @State private var path: [ProfileRoute] = []

    var body: some View {
        @Bindable var router = container.router
        NavigationStack(path: $path) {
            ProfileView()
                .navigationDestination(for: ProfileRoute.self) { route in
                    switch route {
                    case .about:
                        AboutView()
                    }
                }
        }
        .onChange(of: router.pendingRoute, initial: true) { _, _ in
            _ = container.router.takePendingRoute(for: .profile)
        }
    }
}
