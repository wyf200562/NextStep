import Foundation

/// How match data is available for the current screen.
///
/// `.profileIncomplete` means the profile gate (three resolvable skills + one target role) is unmet;
/// `.unavailable` means the bundled lexicon failed to load or a matching read failed.
nonisolated enum MatchAvailability: Equatable, Sendable {
    case ready
    case profileIncomplete
    case unavailable

    /// The fallback message shown where a score would normally be. Empty when match data is ready.
    var fallbackMessage: String {
        switch self {
        case .ready: ""
        case .profileIncomplete: "完善画像后查看匹配"
        case .unavailable: "匹配暂不可用"
        }
    }
}
