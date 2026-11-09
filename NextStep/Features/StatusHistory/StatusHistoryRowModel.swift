import Foundation

/// View-ready content for one status-history row.
///
/// Formatting lives here rather than in the UIKit cell, so the cell only assigns text. The calendar
/// and locale are injected to keep date rendering deterministic in tests.
nonisolated struct StatusHistoryRowModel: Identifiable, Hashable {
    let id: UUID
    let fromStatus: ApplicationStatus?
    let toStatus: ApplicationStatus
    let changedAt: Date
    let note: String?

    private let calendar: Calendar
    private let locale: Locale

    init(
        id: UUID,
        fromStatus: ApplicationStatus?,
        toStatus: ApplicationStatus,
        changedAt: Date,
        note: String?,
        calendar: Calendar,
        locale: Locale = Locale(identifier: "zh_CN")
    ) {
        self.id = id
        self.fromStatus = fromStatus
        self.toStatus = toStatus
        self.changedAt = changedAt
        self.note = note
        self.calendar = calendar
        self.locale = locale
    }

    /// 「创建 → 已投」 for the initial record, otherwise 「想投 → 已投」.
    var transitionText: String {
        let from = fromStatus?.displayName ?? "创建"
        return "\(from) → \(toStatus.displayName)"
    }

    /// Trimmed note; blank notes are treated as absent.
    var noteText: String? {
        guard let note else { return nil }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Local date and time, e.g. 「2026年11月9日 14:05」.
    var timeText: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: changedAt)
    }
}
