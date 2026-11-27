import SwiftUI
import UIKit

/// The overview board: the overdue notice, the agenda (today and the next seven days), the progress
/// counts, and the most recently updated applications.
///
/// Its only data input is a derived `DashboardSnapshot` — there is no `@Query` here, so the board
/// renders from a known snapshot without a store full of data, which is what its `#Preview` does.
/// Whether there is any application at all is the page's question, not the board's; `OverviewView`
/// keeps that switch and the empty state.
/// Routing and the clock still come from the environment, so every action stays a router call and
/// no ViewModel appears (ADR-0004).
struct DashboardView: View {
    @Environment(AppContainer.self) private var container

    let snapshot: DashboardSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            overdueNotice(snapshot.overdueCount)
            events(snapshot)
            progressCounts(snapshot)
            recentUpdates(snapshot)
        }
    }

    // MARK: - Overdue notice

    /// One row above the agenda: past nodes leave the agenda, so their count lives here instead.
    /// Hidden when nothing is overdue.
    @ViewBuilder
    private func overdueNotice(_ count: Int) -> some View {
        if count > 0 {
            Button {
                container.router.openApplications(filter: .all)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.subheadline)
                        .foregroundStyle(Color.orange)
                    Text("\(count) 个申请的节点已过，去更新")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(cardBackground)
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开全部申请")
        }
    }

    // MARK: - Events

    @ViewBuilder
    private func events(_ snapshot: DashboardSnapshot) -> some View {
        if snapshot.hasEvents {
            if !snapshot.todayEvents.isEmpty {
                section("今天") {
                    eventCard(snapshot.todayEvents)
                }
            }
            if !snapshot.upcomingEvents.isEmpty {
                section("接下来 7 天") {
                    eventCard(snapshot.upcomingEvents)
                }
            }
        } else {
            section("接下来 7 天") {
                Text("接下来 7 天没有节点。去 Discover 看看新岗位。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(cardBackground)
            }
        }
    }

    private func eventCard(_ events: [DashboardEvent]) -> some View {
        VStack(spacing: 0) {
            ForEach(events.indices, id: \.self) { index in
                let event = events[index]
                Button {
                    container.router.openApplication(event.applicationID)
                } label: {
                    DashboardEventRow(
                        event: event,
                        now: container.dateProvider.now,
                        calendar: container.dateProvider.calendar
                    )
                }
                .buttonStyle(.plain)

                if index < events.count - 1 {
                    Divider().padding(.leading, 14)
                }
            }
        }
        .background(cardBackground)
    }

    // MARK: - Progress counts

    private func progressCounts(_ snapshot: DashboardSnapshot) -> some View {
        section("进展") {
            HStack(spacing: 8) {
                countButton(snapshot.activeCount, label: "进行中", filter: .active, highlightsValue: false)
                countButton(
                    snapshot.upcomingCount,
                    label: "接下来 7 天",
                    filter: .upcoming,
                    highlightsValue: snapshot.upcomingCount > 0
                )
                countButton(snapshot.offerCount, label: "Offer", filter: .offer, highlightsValue: false)
            }
        }
    }

    private func countButton(
        _ value: Int,
        label: String,
        filter: ApplicationListFilter,
        highlightsValue: Bool
    ) -> some View {
        Button {
            container.router.openApplications(filter: filter)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(highlightsValue ? Color.orange : Color.primary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)：\(value)")
        .accessibilityHint("打开\(filter.displayName)筛选")
    }

    // MARK: - Recent updates

    private func recentUpdates(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("最近更新")
                    .font(.headline)
                Spacer()
                Button("查看全部") {
                    container.router.openApplications(filter: .all)
                }
                .font(.subheadline)
            }

            VStack(spacing: 0) {
                ForEach(snapshot.recentApplications.indices, id: \.self) { index in
                    let application = snapshot.recentApplications[index]
                    Button {
                        container.router.openApplication(application.id)
                    } label: {
                        DashboardRecentRow(application: application)
                    }
                    .buttonStyle(.plain)

                    if index < snapshot.recentApplications.count - 1 {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(cardBackground)
        }
    }

    // MARK: - Pieces

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
    }
}

// MARK: - Preview

/// The board's preview fixture, written by hand: five applications, the snapshot that renders them,
/// and an in-memory container for the router and the clock. Hand-built rather than derived, so the
/// preview shows what the board does with given values — and does not move when derivation changes.
private func dashboardPreviewFixture() -> (snapshot: DashboardSnapshot, container: AppContainer) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    func instant(day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    // 今天 14:00 一面 · 后天 09:00 二面 · 昨天已过 · 一个 offer · 一个没有节点的想投
    let today = Application(
        companyName: "字节跳动",
        roleTitle: "iOS 工程师",
        status: .applied,
        createdAt: instant(day: 9, hour: 8),
        deadline: instant(day: 9, hour: 14)
    )
    let later = Application(
        companyName: "小红书",
        roleTitle: "客户端开发",
        status: .interview,
        createdAt: instant(day: 9, hour: 8),
        deadline: instant(day: 11, hour: 9)
    )
    let overdue = Application(
        companyName: "蔚来",
        roleTitle: "iOS 工程师",
        status: .applied,
        createdAt: instant(day: 9, hour: 8),
        deadline: instant(day: 8, hour: 9)
    )
    let offer = Application(
        companyName: "美团",
        roleTitle: "客户端开发",
        status: .offer,
        createdAt: instant(day: 9, hour: 8)
    )
    let wishlist = Application(
        companyName: "拼多多",
        roleTitle: "iOS 工程师",
        status: .wishlist,
        createdAt: instant(day: 9, hour: 8)
    )

    // A round on the node's instant names it, the same way the app does it.
    today.interviewRounds = [InterviewRound(
        scheduledAt: instant(day: 9, hour: 14),
        format: .video,
        label: "一面"
    )]
    later.interviewRounds = [InterviewRound(
        scheduledAt: instant(day: 11, hour: 9),
        format: .onsite,
        label: "二面"
    )]

    let snapshot = DashboardSnapshot(
        todayEvents: [DashboardEvent(
            id: "deadline-\(today.id.uuidString)",
            application: today,
            date: instant(day: 9, hour: 14)
        )],
        upcomingEvents: [DashboardEvent(
            id: "deadline-\(later.id.uuidString)",
            application: later,
            date: instant(day: 11, hour: 9)
        )],
        // 进行中 = 已投两个 + 面试一个 + 想投一个；offer 不计入 active。议程两条；已过一条。
        activeCount: 4,
        upcomingCount: 2,
        overdueCount: 1,
        offerCount: 1,
        recentApplications: [today, later, overdue, offer, wishlist]
    )

    let container = try! AppContainer.makeInMemory(
        dateProvider: FixedDateProvider(now: instant(day: 9, hour: 10), calendar: calendar)
    )
    return (snapshot, container)
}

#Preview("看板 · 有节点") {
    let fixture = dashboardPreviewFixture()

    // Same chrome as `OverviewView` (horizontal 20, top 8, bottom 28, grouped background), so the
    // preview shows the spacing the page actually ships.
    ScrollView {
        DashboardView(snapshot: fixture.snapshot)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .environment(fixture.container)
}
