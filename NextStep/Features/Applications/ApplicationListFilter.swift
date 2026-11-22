import Foundation

/// The five read-only filters for the applications list.
nonisolated enum ApplicationListFilter: String, CaseIterable, Identifiable, Hashable {
    case all = "all"
    case active = "active"
    case upcoming = "upcoming"
    case offer = "offer"
    case ended = "ended"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "全部"
        case .active: "进行中"
        case .upcoming: "接下来 7 天"
        case .offer: "Offer"
        case .ended: "已结束"
        }
    }
}

/// Status-group rules shared by the applications list and the overview counts.
extension ApplicationStatus {
    /// Wishlist, applied, OA, and interview are still in play for the 进行中 filter.
    var isActive: Bool {
        switch self {
        case .wishlist, .applied, .oa, .interview: true
        case .offer, .rejected, .withdrawn: false
        }
    }

    /// Rejected and withdrawn are the finished states for the 已结束 filter.
    var isEnded: Bool {
        switch self {
        case .rejected, .withdrawn: true
        case .wishlist, .applied, .oa, .interview, .offer: false
        }
    }
}
