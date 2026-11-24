import Foundation

/// One upcoming node on the overview.
///
/// Events are derived values: nothing here is persisted. Only the deadline produces an event
/// (ADR-0005), at most one per application. Past events do not enter the agenda; the overview
/// reports them as a count instead.
struct DashboardEvent: Identifiable {
    let id: String
    let application: Application
    let date: Date

    var applicationID: UUID { application.id }

    /// The node's name, from the shared copy: a round on the instant supplies its label,
    /// otherwise 「截止」.
    var title: String {
        ApplicationNodeCopy.title(forNodeAt: date, of: application)
    }
}

/// The derived, read-only overview: today's and the next seven days' nodes, progress counts, the
/// overdue count, and the most recently updated applications. `now` and `calendar` are injected to
/// keep the windows deterministic in tests.
struct DashboardSnapshot {
    let todayEvents: [DashboardEvent]
    let upcomingEvents: [DashboardEvent]
    let activeCount: Int
    let upcomingCount: Int
    let overdueCount: Int
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
        guard let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) else {
            return DashboardSnapshot(
                todayEvents: [],
                upcomingEvents: [],
                activeCount: 0,
                upcomingCount: 0,
                overdueCount: 0,
                offerCount: 0,
                recentApplications: []
            )
        }

        var events: [DashboardEvent] = []
        for application in applications
        where ApplicationDeadlineWindow.isWithinUpcomingWeek(application, now: now, calendar: calendar) {
            guard let deadline = application.deadline else { continue }
            events.append(DashboardEvent(
                id: "deadline-\(application.id.uuidString)",
                application: application,
                date: deadline
            ))
        }

        events.sort(by: eventOrder)

        return DashboardSnapshot(
            todayEvents: events.filter { $0.date < tomorrowStart },
            upcomingEvents: events.filter { $0.date >= tomorrowStart },
            activeCount: applications.filter { $0.status.isActive }.count,
            // The agenda above already applied this predicate once; counting the events keeps the
            // number and the rows from ever disagreeing.
            upcomingCount: events.count,
            overdueCount: applications.filter {
                ApplicationDeadlineWindow.isOverdue($0, now: now)
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

    /// Time ascending; equal instants order by application id, matching the applications list.
    private static func eventOrder(_ lhs: DashboardEvent, _ rhs: DashboardEvent) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date < rhs.date
        }
        return lhs.applicationID.uuidString < rhs.applicationID.uuidString
    }
}
