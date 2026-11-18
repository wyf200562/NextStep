import SwiftData
import SwiftUI

/// Four root tabs sharing one `AppRouter`. No ViewModel lives at the root.
struct RootTabView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        @Bindable var router = container.router
        TabView(selection: $router.selectedTab) {
            Tab(
                AppTab.overview.title,
                systemImage: AppTab.overview.systemImage,
                value: AppTab.overview
            ) {
                OverviewTabView()
            }

            Tab(
                AppTab.applications.title,
                systemImage: AppTab.applications.systemImage,
                value: AppTab.applications
            ) {
                ApplicationsTabView()
            }

            Tab(
                AppTab.discover.title,
                systemImage: AppTab.discover.systemImage,
                value: AppTab.discover
            ) {
                DiscoverTabView()
            }

            Tab(
                AppTab.profile.title,
                systemImage: AppTab.profile.systemImage,
                value: AppTab.profile
            ) {
                ProfileTabView()
            }
        }
    }
}

#Preview {
    let container = try! AppContainer.makeInMemory()
    RootTabView()
        .environment(container)
        .modelContainer(container.modelContainer)
}
