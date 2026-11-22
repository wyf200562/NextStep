import Foundation

/// The derived, read-only state of the application list.
///
/// Applications are fetched with `@Query`; this snapshot applies the filter, ordering, and summary
/// rules so the view stays free of business logic. `now` and `calendar` are injected to keep the
/// upcoming window and node ordering deterministic in tests.
struct ApplicationListSnapshot {
    struct Row: Identifiable {
        let application: Application
        /// The single node for this row, derived from the deadline (ADR-0005). nil when there is
        /// nothing to show — no deadline, or an ended status.
        let node: ApplicationNode?

        var id: UUID { application.id }
    }

    let rows: [Row]
    let totalCount: Int
    let activeCount: Int
}

enum ApplicationListBuilder {
    static func snapshot(
        for filter: ApplicationListFilter,
        applications: [Application],
        now: Date,
        calendar: Calendar
    ) -> ApplicationListSnapshot {
        let rows = applications
            .filter { matches($0, filter: filter, now: now, calendar: calendar) }
            .map {
                ApplicationListSnapshot.Row(
                    application: $0,
                    node: ApplicationNodeCopy.node(for: $0, now: now)
                )
            }

        let ordered: [ApplicationListSnapshot.Row]
        switch filter {
        case .all, .active, .upcoming:
            ordered = rows.sorted(by: upcomingFirst)
        case .offer, .ended:
            ordered = rows.sorted(by: lastModifiedFirst)
        }

        return ApplicationListSnapshot(
            rows: ordered,
            totalCount: applications.count,
            activeCount: applications.filter { $0.status.isActive }.count
        )
    }

    // MARK: - Filtering

    private static func matches(
        _ application: Application,
        filter: ApplicationListFilter,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        switch filter {
        case .all:
            true
        case .active:
            application.status.isActive
        case .upcoming:
            ApplicationDeadlineWindow.isWithinUpcomingWeek(application, now: now, calendar: calendar)
        case .offer:
            application.status == .offer
        case .ended:
            application.status.isEnded
        }
    }

    // MARK: - Ordering

    /// Rows with a node come first: upcoming nodes by date ascending, then overdue nodes by date
    /// descending (most recently missed first). Node-less rows follow, latest modification first.
    private static func upcomingFirst(
        _ lhs: ApplicationListSnapshot.Row,
        _ rhs: ApplicationListSnapshot.Row
    ) -> Bool {
        switch (lhs.node, rhs.node) {
        case let (left?, right?):
            if left.isOverdue != right.isOverdue {
                return !left.isOverdue
            }
            if left.date != right.date {
                return left.isOverdue ? left.date > right.date : left.date < right.date
            }
            return lhs.application.id.uuidString < rhs.application.id.uuidString
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lastModifiedFirst(lhs, rhs)
        }
    }

    private static func lastModifiedFirst(
        _ lhs: ApplicationListSnapshot.Row,
        _ rhs: ApplicationListSnapshot.Row
    ) -> Bool {
        if lhs.application.lastModifiedAt != rhs.application.lastModifiedAt {
            return lhs.application.lastModifiedAt > rhs.application.lastModifiedAt
        }
        return lhs.application.id.uuidString < rhs.application.id.uuidString
    }
}
