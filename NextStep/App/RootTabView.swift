import SwiftData
import SwiftUI

/// Four root tabs sharing one `AppRouter`. No ViewModel lives at the root.
struct RootTabView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        @Bindable var router = container.router
        TabView(selection: $router.selectedTab) {
            OverviewTabView()
                .tabItem {
                    Label(AppTab.overview.title, systemImage: AppTab.overview.systemImage)
                }
                .tag(AppTab.overview)

            ApplicationsTabView()
                .tabItem {
                    Label(AppTab.applications.title, systemImage: AppTab.applications.systemImage)
                }
                .tag(AppTab.applications)

            DiscoverTabView()
                .tabItem {
                    Label(AppTab.discover.title, systemImage: AppTab.discover.systemImage)
                }
                .tag(AppTab.discover)

            ProfileTabView()
                .tabItem {
                    Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage)
                }
                .tag(AppTab.profile)
        }
    }
}

#Preview {
    let container = try! AppContainer.makeInMemory()
    RootTabView()
        .environment(container)
        .modelContainer(container.modelContainer)
}
