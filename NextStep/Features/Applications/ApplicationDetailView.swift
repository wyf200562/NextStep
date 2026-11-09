import os
import SwiftUI

/// Read-only detail shell for ticket 13. Ticket 14 replaces the content with editing, status
/// transitions, interview rounds, and the status-history entry point.
struct ApplicationDetailView: View {
    @Environment(AppContainer.self) private var container
    let applicationID: UUID
    @State private var state: LoadState<Application> = .idle

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                ProgressView("正在加载…")
            case .loaded(let application):
                content(for: application)
            case .failed:
                ContentUnavailableView {
                    Label("加载失败", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("加载失败，请稍后重试")
                } actions: {
                    Button("重试", action: load)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("申请详情")
        .task {
            if case .idle = state {
                load()
            }
        }
    }

    private func content(for application: Application) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(application.companyName)
                            .font(.title2.bold())
                        Spacer(minLength: 8)
                        ApplicationStatusBadge(status: application.status)
                    }
                    Text(application.roleTitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("最近更新：\(ApplicationDateFormatting.monthDayTime(application.lastModifiedAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("截止日期") {
                if let deadline = application.deadline {
                    Text(ApplicationDateFormatting.monthDayTime(deadline))
                } else {
                    Text("未设置")
                        .foregroundStyle(.secondary)
                }
            }

            Section("备注") {
                if let notes = application.notes, !notes.isEmpty {
                    Text(notes)
                } else {
                    Text("暂无备注")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func load() {
        state = .loading
        do {
            if let application = try container.applicationRepository.application(id: applicationID) {
                state = .loaded(application)
            } else {
                state = .failed(RepositoryError.loadFailed)
            }
        } catch {
            AppLogger.ui.error(
                "Failed to load application detail: \(error.localizedDescription, privacy: .public)"
            )
            state = .failed(error)
        }
    }
}
