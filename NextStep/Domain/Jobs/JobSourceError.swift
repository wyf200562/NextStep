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
