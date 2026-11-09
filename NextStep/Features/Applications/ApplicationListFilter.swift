import Foundation

/// The five read-only filters for the applications list.
nonisolated enum ApplicationListFilter: String, CaseIterable, Identifiable, Hashable {
    case all = "all"
    case active = "active"
    case dueSoon = "dueSoon"
    case offer = "offer"
    case ended = "ended"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "全部"
        case .active: "进行中"
        case .dueSoon: "临近截止"
        case .offer: "Offer"
        case .ended: "已结束"
        }
    }
}
