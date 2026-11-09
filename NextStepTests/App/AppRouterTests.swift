import Foundation
import Testing
@testable import NextStep

@Suite("AppRouter")
struct AppRouterTests {
    @Test func startsOnOverviewWithoutAPendingRoute() {
        let router = AppRouter()

        #expect(router.selectedTab == .overview)
        #expect(router.pendingRoute == nil)
    }

    @Test func tabsUseTheAgreedChineseTitles() {
        #expect(AppTab.allCases.map(\.title) == ["概览", "申请", "发现", "我的"])
        #expect(ApplicationListFilter.allCases.map(\.displayName) == [
            "全部", "进行中", "临近截止", "Offer", "已结束",
        ])
    }

    @Test func openingAnApplicationDetailSwitchesTabAndQueuesTheRouteForThatTab() {
        let router = AppRouter()
        let applicationID = UUID()

        router.openApplication(applicationID)

        #expect(router.selectedTab == .applications)
        #expect(router.pendingRoute == .applicationDetail(applicationID: applicationID))
        #expect(router.takePendingRoute(for: .overview) == nil)
        #expect(router.pendingRoute == .applicationDetail(applicationID: applicationID))
        #expect(router.takePendingRoute(for: .applications) == .applicationDetail(applicationID: applicationID))
        #expect(router.pendingRoute == nil)
    }

    @Test func openingTheApplicationsListCarriesTheFilter() {
        let router = AppRouter()

        router.openApplications(filter: .dueSoon)

        #expect(router.selectedTab == .applications)
        #expect(router.takePendingRoute(for: .applications) == .applicationsList(filter: .dueSoon))
    }

    @Test func switchingToDiscoverAndProfileQueuesTheirTabRoutes() {
        let router = AppRouter()

        router.openDiscover()
        #expect(router.selectedTab == .discover)
        #expect(router.takePendingRoute(for: .discover) == .discover)

        router.openProfile()
        #expect(router.selectedTab == .profile)
        #expect(router.takePendingRoute(for: .profile) == .profile)
    }

    @Test func aNewPendingRouteReplacesThePreviousOne() {
        let router = AppRouter()

        router.openDiscover()
        router.openProfile()

        #expect(router.pendingRoute == .profile)
        #expect(router.takePendingRoute(for: .discover) == nil)
        #expect(router.takePendingRoute(for: .profile) == .profile)
    }
}
