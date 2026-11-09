import Foundation

/// Typed destinations pushed on the 发现 tab's navigation stack.
nonisolated enum DiscoverRoute: Hashable {
    case jobDetail(jobID: UUID)
    case manualImport
}
