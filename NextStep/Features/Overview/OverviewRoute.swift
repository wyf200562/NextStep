import Foundation

/// Typed destinations pushed on the 概览 tab's navigation stack.
nonisolated enum OverviewRoute: Hashable {
    case applicationDetail(applicationID: UUID)
}
