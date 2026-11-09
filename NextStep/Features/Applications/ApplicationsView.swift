import SwiftData
import SwiftUI

/// The read-only applications list. `@Query` fetches, a `@State` filter selects, and the pure
/// `ApplicationListBuilder` derives ordering. No ViewModel lives here.
struct ApplicationsView: View {
    @Environment(AppContainer.self) private var container
    @Query private var applications: [Application]
    @Binding var filter: ApplicationListFilter
    @State private var isPresentingEditor = false

    var body: some View {
        let snapshot = ApplicationListBuilder.snapshot(
            for: filter,
            applications: applications,
            now: container.dateProvider.now,
            calendar: container.dateProvider.calendar
        )

        VStack(spacing: 0) {
            Picker("筛选", selection: $filter) {
                ForEach(ApplicationListFilter.allCases) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if snapshot.totalCount > 0 {
                Text("\(snapshot.totalCount) 份申请 · \(snapshot.activeCount) 份进行中")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            if snapshot.rows.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(snapshot.rows) { row in
                        NavigationLink(value: ApplicationsRoute.detail(applicationID: row.id)) {
                            ApplicationRowView(row: row)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("申请")
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label(emptyTitle, systemImage: emptyIcon)
        } description: {
            Text(emptyMessage)
        } actions: {
            Button("添加第一份申请") {
                isPresentingEditor = true
            }
            .buttonStyle(.borderedProminent)

            Button("去 Discover 看看") {
                container.router.openDiscover()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyTitle: String {
        guard !applications.isEmpty else { return "还没有申请" }
        return switch filter {
        case .all: "还没有申请"
        case .active: "没有进行中的申请"
        case .dueSoon: "7 天内没有临近截止"
        case .offer: "还没有 Offer"
        case .ended: "没有已结束的申请"
        }
    }

    private var emptyMessage: String {
        guard !applications.isEmpty else {
            return "记录第一份申请，或去 Discover 看看岗位。"
        }
        return switch filter {
        case .all: "记录第一份申请，或去 Discover 看看岗位。"
        case .active: "想投、已投、OA 和面试中的申请会出现在这里。"
        case .dueSoon: "有截止日期或待定面试时，这里会提醒你。"
        case .offer: "收到 Offer 后，申请会出现在这里。"
        case .ended: "已拒或已撤的申请会出现在这里。"
        }
    }

    private var emptyIcon: String {
        switch filter {
        case .all: "tray"
        case .active: "clock"
        case .dueSoon: "calendar.badge.clock"
        case .offer: "checkmark.seal"
        case .ended: "archivebox"
        }
    }
}
