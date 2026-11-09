import Foundation

/// Typed persistence failures surfaced by the Data layer.
nonisolated enum RepositoryError: Error, Equatable, Sendable {
    /// The operation is not implemented in this scaffolding slice yet.
    case unavailable
    case loadFailed
    case saveFailed
}
