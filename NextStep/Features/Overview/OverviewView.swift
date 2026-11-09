import SwiftData
import SwiftUI
import UIKit

/// 概览 tab: the action-first dashboard.
///
/// `@Query` fetches applications; the pure `DashboardBuilder` derives today's and the next seven
/// days' events, the three progress counts, and the five most recently updated applications.
/// No ViewModel lives here — every action is a router call or the shared editor sheet.
struct OverviewView: View {
    @Environment(AppContainer.self) private var container
    @Query private var applications: [Application]
    @State private var isPresentingEditor = false

    var body: some View {
        let snapshot = DashboardBuilder.snapshot(
            applications: applications,
            now: container.dateProvider.now,
            calendar: container.dateProvider.calendar
        )

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if applications.isEmpty {
                    emptyState
                } else {
                    events(snapshot)
                    progressCounts(snapshot)
                    recentUpdates(snapshot)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("概览")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingEditor = true
                } label: {
                    Label("添加申请", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            ApplicationEditorView(container: container) { applicationID in
                isPresentingEditor = false
                container.router.openApplication(applicationID)
            }
        }
    }

    // MARK: - Header and empty state

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(DashboardFormatting.dateOverline(container.dateProvider.now))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("概览")
                .font(.system(size: 36, weight: .bold))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "target")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 76, height: 76)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )

            Text("从第一份申请开始")
                .font(.title2.bold())

            Text("把想投的岗位记下来，截止日期和面试安排都放在一起。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("添加第一份申请") {
                isPresentingEditor = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("去 Discover 看看") {
                container.router.openDiscover()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
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
                Text("7 天内没有截止或面试。去 Discover 看看新岗位。")
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
                    snapshot.dueSoonCount,
                    label: "7 天内截止",
                    filter: .dueSoon,
                    highlightsValue: snapshot.dueSoonCount > 0
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
