import Foundation

/// One actionable deadline or pending interview on the overview.
///
/// Events are derived values: nothing here is persisted. `isPast` only matters for today's events,
/// which stay visible (marked 已过) instead of disappearing.
struct DashboardEvent: Identifiable {
    enum Kind: Equatable {
        case deadline
        case interview
    }

    let id: String
    let application: Application
    let kind: Kind
    let date: Date
    let roundLabel: String?
    let roundID: UUID?
    let isPast: Bool

    var applicationID: UUID { application.id }

    /// The action title. Interview events carry the round label when one is set.
    var title: String {
        switch kind {
        case .deadline:
            return "截止"
        case .interview:
            guard let roundLabel, !roundLabel.isEmpty else { return "面试" }
            return "面试 · \(roundLabel)"
        }
    }
}

/// The derived, read-only overview: today's and the next seven days' events, progress counts, and
/// the most recently updated applications. `now` and `calendar` are injected to keep the windows
/// deterministic in tests.
struct DashboardSnapshot {
    let todayEvents: [DashboardEvent]
    let upcomingEvents: [DashboardEvent]
    let activeCount: Int
    let dueSoonCount: Int
    let offerCount: Int
    let recentApplications: [Application]

    var hasEvents: Bool { !todayEvents.isEmpty || !upcomingEvents.isEmpty }
}

/// Pure dashboard derivation over all applications. No ViewModel, ModelContext, or I/O.
enum DashboardBuilder {
    static func snapshot(
        applications: [Application],
        now: Date,
        calendar: Calendar
    ) -> DashboardSnapshot {
        let todayStart = calendar.startOfDay(for: now)
        guard let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart),
              let windowEnd = calendar.date(byAdding: .day, value: 8, to: todayStart)
        else {
            return DashboardSnapshot(
                todayEvents: [],
                upcomingEvents: [],
                activeCount: 0,
                dueSoonCount: 0,
                offerCount: 0,
                recentApplications: []
            )
        }

        var events: [DashboardEvent] = []
        for application in applications where !application.status.isEnded {
            if let deadline = application.deadline,
               deadline >= todayStart,
               deadline < windowEnd {
                events.append(DashboardEvent(
                    id: "deadline-\(application.id.uuidString)",
                    application: application,
                    kind: .deadline,
                    date: deadline,
                    roundLabel: nil,
                    roundID: nil,
                    isPast: deadline < now
                ))
            }

            for round in application.interviewRounds
            where round.result == .pending
                && round.scheduledAt >= todayStart
                && round.scheduledAt < windowEnd {
                events.append(DashboardEvent(
                    id: "interview-\(round.id.uuidString)",
                    application: application,
                    kind: .interview,
                    date: round.scheduledAt,
                    roundLabel: round.label,
                    roundID: round.id,
                    isPast: round.scheduledAt < now
                ))
            }
        }

        events.sort(by: eventOrder)

        return DashboardSnapshot(
            todayEvents: events.filter { $0.date < tomorrowStart },
            upcomingEvents: events.filter { $0.date >= tomorrowStart },
            activeCount: applications.filter { $0.status.isActive }.count,
            dueSoonCount: applications.filter {
                ApplicationListBuilder.isDueSoon($0, now: now, calendar: calendar)
            }.count,
            offerCount: applications.filter { $0.status == .offer }.count,
            recentApplications: Array(applications.sorted(by: recentOrder).prefix(5))
        )
    }

    /// Latest modification first; equal instants order by application id ascending.
    private static func recentOrder(_ lhs: Application, _ rhs: Application) -> Bool {
        if lhs.lastModifiedAt != rhs.lastModifiedAt {
            return lhs.lastModifiedAt > rhs.lastModifiedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    /// Time ascending; equal instants order by application id, then deadline before interview,
    /// then round id, matching the applications list's tie-break rules.
    private static func eventOrder(_ lhs: DashboardEvent, _ rhs: DashboardEvent) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date < rhs.date
        }
        if lhs.applicationID != rhs.applicationID {
            return lhs.applicationID.uuidString < rhs.applicationID.uuidString
        }
        if lhs.kind != rhs.kind {
            return lhs.kind == .deadline
        }
        return (lhs.roundID?.uuidString ?? "") < (rhs.roundID?.uuidString ?? "")
    }
}
