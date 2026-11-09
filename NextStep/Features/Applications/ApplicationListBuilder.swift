import Foundation

/// The derived, read-only state of the application list.
///
/// Applications are fetched with `@Query`; this snapshot applies the filter, ordering, and summary
/// rules so the view stays free of business logic. `now` and `calendar` are injected to keep the
/// seven-day window and upcoming-node ordering deterministic in tests.
struct ApplicationListSnapshot {
    struct Row: Identifiable {
        let application: Application
        let nearestNode: NearestNode?

        var id: UUID { application.id }
    }

    typealias NearestNode = ApplicationNextNode

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
                    nearestNode: ApplicationNextNode.nearest(for: $0, at: now)
                )
            }

        let ordered: [ApplicationListSnapshot.Row]
        switch filter {
        case .all, .active, .dueSoon:
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
        case .dueSoon:
            isDueSoon(application, now: now, calendar: calendar)
        case .offer:
            application.status == .offer
        case .ended:
            application.status.isEnded
        }
    }

    /// The shared 7-day due-soon rule: a non-terminal application with a deadline or a pending
    /// interview inside today 00:00–today+7 23:59. The overview's 7-day count reuses it so the two
    /// screens cannot disagree.
    static func isDueSoon(
        _ application: Application,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        guard !application.status.isEnded else { return false }

        let today = calendar.startOfDay(for: now)
        guard let windowEnd = calendar.date(byAdding: .day, value: 8, to: today) else {
            return false
        }
        func isInsideWindow(_ date: Date) -> Bool {
            date >= today && date < windowEnd
        }

        if let deadline = application.deadline, isInsideWindow(deadline) {
            return true
        }
        return application.interviewRounds.contains {
            $0.result == .pending && isInsideWindow($0.scheduledAt)
        }
    }

    // MARK: - Ordering

    private static func upcomingFirst(
        _ lhs: ApplicationListSnapshot.Row,
        _ rhs: ApplicationListSnapshot.Row
    ) -> Bool {
        switch (lhs.nearestNode, rhs.nearestNode) {
        case let (left?, right?):
            if left.date != right.date {
                return left.date < right.date
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
