import Foundation

/// The seven stages an `Application` can be in.
///
/// The raw values are part of the persisted schema and must never change without a migration.
/// Persisted models store `statusRaw: String`; this type is the typed view over it.
nonisolated enum ApplicationStatus: String, CaseIterable, Identifiable, Sendable {
    case wishlist = "wishlist"
    case applied = "applied"
    case oa = "oa"
    case interview = "interview"
    case offer = "offer"
    case rejected = "rejected"
    case withdrawn = "withdrawn"

    var id: String { rawValue }

    /// Chinese label used across the UI.
    var displayName: String {
        switch self {
        case .wishlist: "想投"
        case .applied: "已投"
        case .oa: "OA/笔试"
        case .interview: "面试"
        case .offer: "Offer"
        case .rejected: "已拒"
        case .withdrawn: "已撤"
        }
    }
}
