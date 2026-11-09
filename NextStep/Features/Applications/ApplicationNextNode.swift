import Foundation

/// The next upcoming node of an application: the earlier of an upcoming `deadline` and a pending
/// `InterviewRound`. The detail card and the application list read this one rule so they cannot
/// drift; on an identical instant the deadline wins, and equal-instant rounds tie-break by id.
struct ApplicationNextNode: Equatable {
    enum Kind: Equatable {
        case deadline
        case interview
    }

    let kind: Kind
    let date: Date
    let roundLabel: String?
    let roundID: UUID?

    /// `now` is inclusive: a node exactly at `now` still counts as upcoming.
    static func nearest(for application: Application, at now: Date) -> ApplicationNextNode? {
        var candidates: [ApplicationNextNode] = []

        if let deadline = application.deadline, deadline >= now {
            candidates.append(ApplicationNextNode(
                kind: .deadline,
                date: deadline,
                roundLabel: nil,
                roundID: nil
            ))
        }
        for round in application.interviewRounds
        where round.result == .pending && round.scheduledAt >= now {
            candidates.append(ApplicationNextNode(
                kind: .interview,
                date: round.scheduledAt,
                roundLabel: round.label,
                roundID: round.id
            ))
        }

        return candidates.min { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date < rhs.date
            }
            if lhs.kind != rhs.kind {
                // A deadline wins a dead heat; the remaining tie-break matches the interview rule.
                return lhs.kind == .deadline
            }
            return (lhs.roundID?.uuidString ?? "") < (rhs.roundID?.uuidString ?? "")
        }
    }
}
