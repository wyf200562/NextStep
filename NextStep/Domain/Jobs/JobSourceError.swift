import Foundation

/// Typed failures produced by job sources. User-facing Chinese copy is added by ViewModels.
nonisolated enum JobSourceError: Error, Equatable, Sendable {
    case invalidInput
    case offline
    case timedOut
    case rateLimited
    case server(Int)
    case decoding
}

/// The single mapping from typed job-source failures to the Chinese copy in spec §11.
///
/// ViewModels share this so `.offline`, `.timedOut`, `.rateLimited`, `.server`,
/// `.decoding`, and `.invalidInput` always read the same; raw error text is never shown.
nonisolated enum JobSourceErrorCopy {
    /// `fallback` is returned for any error that is not a `JobSourceError`.
    static func message(for error: any Error, fallback: String) -> String {
        guard let sourceError = error as? JobSourceError else {
            return fallback
        }
        return switch sourceError {
        case .invalidInput: "请检查必填项"
        case .offline: "网络不可用，请检查连接"
        case .timedOut: "请求超时，请稍后重试"
        case .rateLimited: "请求过于频繁，请稍后再试"
        case .server(let code): "服务器暂时不可用（HTTP \(code)）"
        case .decoding: "数据格式暂时无法识别"
        }
    }
}
