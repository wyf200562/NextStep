import Foundation
import Observation

/// App-level coordinator for cross-tab navigation.
///
/// This is not a ViewModel: it holds only the selected tab and at most one pending cross-tab route.
/// Each tab consumes routes addressed to it; the tab's `NavigationStack` and filter state stay in
/// the view that owns them.
@Observable
@MainActor
final class AppRouter {
    nonisolated enum Route: Equatable {
        case applicationDetail(applicationID: UUID)
        case applicationsList(filter: ApplicationListFilter)
        case discover
        case profile
    }

    var selectedTab: AppTab
    private(set) var pendingRoute: Route?

    init(selectedTab: AppTab = .overview, pendingRoute: Route? = nil) {
        self.selectedTab = selectedTab
        self.pendingRoute = pendingRoute
    }

    /// Switches to 申请 and asks it to push an application detail.
    func openApplication(_ applicationID: UUID) {
        selectedTab = .applications
        pendingRoute = .applicationDetail(applicationID: applicationID)
    }

    /// Switches to 申请 and asks the list root to apply a filter.
    func openApplications(filter: ApplicationListFilter) {
        selectedTab = .applications
        pendingRoute = .applicationsList(filter: filter)
    }

    /// Switches to 发现.
    func openDiscover() {
        selectedTab = .discover
        pendingRoute = .discover
    }

    /// Switches to 我的.
    func openProfile() {
        selectedTab = .profile
        pendingRoute = .profile
    }

    /// Returns and clears the pending route when it belongs to `tab`; otherwise leaves it untouched.
    func takePendingRoute(for tab: AppTab) -> Route? {
        guard let pendingRoute, pendingRoute.targetTab == tab else { return nil }
        self.pendingRoute = nil
        return pendingRoute
    }
}

extension AppRouter.Route {
    var targetTab: AppTab {
        switch self {
        case .applicationDetail, .applicationsList: .applications
        case .discover: .discover
        case .profile: .profile
        }
    }
}
