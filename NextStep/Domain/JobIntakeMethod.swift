import Foundation

/// How a `JobPosting` entered this device.
///
/// Raw values are persisted in `JobPosting.intakeMethodRaw` and must stay stable.
nonisolated enum JobIntakeMethod: String, CaseIterable, Identifiable, Sendable {
    case remotive = "remotive"
    case manual = "manual"
    case url = "url"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .remotive: "Remotive"
        case .manual: "手动导入"
        case .url: "链接导入"
        }
    }
}
