import Foundation
import SwiftData

/// One interview round belonging to an `Application`.
///
/// OA/assessment stages are not interview rounds; their timing lives in `StatusChange`.
/// Deleting the application cascades to its rounds.
@Model
final class InterviewRound {
    var id: UUID
    var scheduledAt: Date
    var formatRaw: String
    var resultRaw: String
    var label: String?
    var contact: String?
    var notes: String?
    var application: Application?

    /// Typed view over `formatRaw`.
    var format: InterviewFormat {
        get { InterviewFormat(rawValue: formatRaw) ?? .other }
        set { formatRaw = newValue.rawValue }
    }

    /// Typed view over `resultRaw`.
    var result: InterviewResult {
        get { InterviewResult(rawValue: resultRaw) ?? .pending }
        set { resultRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        scheduledAt: Date,
        format: InterviewFormat,
        result: InterviewResult = .pending,
        label: String? = nil,
        contact: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.formatRaw = format.rawValue
        self.resultRaw = result.rawValue
        self.label = label
        self.contact = contact
        self.notes = notes
    }
}
