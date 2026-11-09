import Foundation

/// Typed destinations pushed on the 申请 tab's navigation stack.
nonisolated enum ApplicationsRoute: Hashable {
    case detail(applicationID: UUID)
}
