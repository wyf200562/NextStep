import Foundation

/// The four root tabs. The Discover tab's page title is "Discover"; its tab label stays 发现.
nonisolated enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case overview = "overview"
    case applications = "applications"
    case discover = "discover"
    case profile = "profile"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "概览"
        case .applications: "申请"
        case .discover: "发现"
        case .profile: "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .applications: "tray.full"
        case .discover: "safari"
        case .profile: "person.crop.circle"
        }
    }
}
