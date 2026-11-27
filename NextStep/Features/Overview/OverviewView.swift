import SwiftData
import SwiftUI
import UIKit

/// 概览 tab: the action-first dashboard.
///
/// `@Query` fetches applications; the pure `DashboardBuilder` derives today's and the next seven
/// days' nodes, the progress counts, the overdue count, and the five most recently updated
/// applications. The board itself is `DashboardView`, which takes that snapshot as its only input;
/// this page owns the data source, the chrome, and the empty state.
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
                    DashboardView(snapshot: snapshot)
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
}
