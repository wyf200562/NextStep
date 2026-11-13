import Foundation

/// Typed failures produced by job sources.
///
/// The single user-facing Chinese copy from spec §11 lives on the failure itself,
/// so every ViewModel reads the same text and raw error text is never shown.
nonisolated enum JobSourceError: Error, Equatable, Sendable {
    case invalidInput
    case offline
    case timedOut
    case rateLimited
    case server(Int)
    case decoding

    /// The user-facing Chinese copy for this failure. Raw error text is never shown.
    var message: String {
        switch self {
        case .invalidInput: "请检查必填项"
        case .offline: "网络不可用，请检查连接"
        case .timedOut: "请求超时，请稍后重试"
        case .rateLimited: "请求过于频繁，请稍后再试"
        case .server(let code): "服务器暂时不可用（HTTP \(code)）"
        case .decoding: "数据格式暂时无法识别"
        }
    }

    /// The single mapping from any error to the Chinese copy in spec §11.
    ///
    /// ViewModels share this so `.offline`, `.timedOut`, `.rateLimited`, `.server`,
    /// `.decoding`, and `.invalidInput` always read the same; raw error text is never shown.
    /// `fallback` is returned for any error that is not a `JobSourceError`.
    static func message(for error: any Error, fallback: String) -> String {
        (error as? JobSourceError)?.message ?? fallback
    }
}
