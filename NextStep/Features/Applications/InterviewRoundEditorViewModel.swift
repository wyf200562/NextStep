import Foundation
import Observation

/// Owns the interview-round form draft in both create and edit modes.
///
/// This ViewModel holds no repository: saving is an intent on `ApplicationDetailViewModel`, which
/// remains the owner of the mark-as-interview prompt. Here we only derive the scheduled instant and
/// the unsaved-changes signal used to confirm discarding edits.
@Observable
@MainActor
final class InterviewRoundEditorViewModel {
    private struct Draft: Equatable {
        let day: Date
        let time: Date
        let format: InterviewFormat
        let label: String
        let contact: String
        let notes: String
        let result: InterviewResult
    }

    private enum Mode {
        case create
        case edit(InterviewRound)
    }

    private let calendar: Calendar
    private let mode: Mode
    private let initialDraft: Draft

    var scheduledDay: Date
    var scheduledTime: Date
    var format: InterviewFormat
    var label = ""
    var contact = ""
    var notes = ""
    var result: InterviewResult = .pending

    /// Create mode: today at 09:00, video, pending.
    init(dateProvider: any DateProvider) {
        let calendar = dateProvider.calendar
        let today = calendar.startOfDay(for: dateProvider.now)
        let defaultTime = calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: today
        ) ?? today

        self.calendar = calendar
        self.mode = .create
        self.scheduledDay = today
        self.scheduledTime = defaultTime
        self.format = .video
        self.initialDraft = Draft(
            day: today,
            time: defaultTime,
            format: .video,
            label: "",
            contact: "",
            notes: "",
            result: .pending
        )
    }

    /// Edit mode: prefills every field from the round.
    init(dateProvider: any DateProvider, round: InterviewRound) {
        let calendar = dateProvider.calendar
        let day = calendar.startOfDay(for: round.scheduledAt)
        let label = round.label ?? ""
        let contact = round.contact ?? ""
        let notes = round.notes ?? ""

        self.calendar = calendar
        self.mode = .edit(round)
        self.scheduledDay = day
        self.scheduledTime = round.scheduledAt
        self.format = round.format
        self.label = label
        self.contact = contact
        self.notes = notes
        self.result = round.result
        self.initialDraft = Draft(
            day: day,
            time: round.scheduledAt,
            format: round.format,
            label: label,
            contact: contact,
            notes: notes,
            result: round.result
        )
    }

    var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    /// The chosen day plus the chosen hour/minute, in the injected calendar.
    var scheduledAt: Date {
        var components = calendar.dateComponents([.year, .month, .day], from: scheduledDay)
        let time = calendar.dateComponents([.hour, .minute], from: scheduledTime)
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0
        return calendar.date(from: components) ?? scheduledDay
    }

    /// True when dismissing the form would lose user input.
    var hasUnsavedChanges: Bool {
        currentDraft != initialDraft
    }

    private var currentDraft: Draft {
        Draft(
            day: calendar.startOfDay(for: scheduledDay),
            time: scheduledTime,
            format: format,
            label: trimmed(label),
            contact: trimmed(contact),
            notes: trimmed(notes),
            result: result
        )
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
