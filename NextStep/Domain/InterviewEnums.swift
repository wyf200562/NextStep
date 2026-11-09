import Foundation

/// The medium of an interview round.
nonisolated enum InterviewFormat: String, CaseIterable, Identifiable, Sendable {
    case phone = "phone"
    case video = "video"
    case onsite = "onsite"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .phone: "电话"
        case .video: "视频"
        case .onsite: "现场"
        case .other: "其他"
        }
    }
}

/// The outcome of an interview round. A failed round never changes the application status automatically.
nonisolated enum InterviewResult: String, CaseIterable, Identifiable, Sendable {
    case pending = "pending"
    case passed = "passed"
    case failed = "failed"
    case cancelled = "cancelled"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending: "待定"
        case .passed: "通过"
        case .failed: "未通过"
        case .cancelled: "取消"
        }
    }
}
