import Foundation

/// The node the UI shows for an application. `nil` when there is nothing to show.
struct ApplicationNode: Equatable {
    let date: Date
    /// A round's label, 「面试」 for a blank label, or 「截止」 when no round sits on the instant.
    let title: String
    let isOverdue: Bool
}

enum ApplicationNodeCopy {
    /// The 「已过」 marker.
    static let overdueText = "已过"

    /// nil when `deadline` is nil or `status.isEnded`; `isOverdue` comes from
    /// `ApplicationDeadlineWindow.isOverdue`. The list row and the detail card both gate on this.
    static func node(for application: Application, now: Date) -> ApplicationNode? {
        guard let deadline = application.deadline, !application.status.isEnded else { return nil }
        return ApplicationNode(
            date: deadline,
            title: title(forNodeAt: deadline, of: application),
            isOverdue: ApplicationDeadlineWindow.isOverdue(application, now: now)
        )
    }

    /// The name of the node at `instant`: a round scheduled exactly there supplies it (its `label`,
    /// or 「面试」 when the label is blank; `result` is never filtered), otherwise 「截止」.
    /// Never reads `status` — status goes stale and would turn staleness into a wrong sentence.
    static func title(forNodeAt instant: Date, of application: Application) -> String {
        let round = application.interviewRounds
            .filter { $0.scheduledAt == instant }
            .min { $0.id.uuidString < $1.id.uuidString }

        guard let round else { return "截止" }
        guard let label = round.label, !label.isEmpty else { return "面试" }
        return label
    }
}
