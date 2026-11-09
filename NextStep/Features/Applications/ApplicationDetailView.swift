import os
import SwiftUI

/// Application detail: header, next-node card, snapshot fields, notes, edit, delete, and the status
/// flow. All state flows through `ApplicationDetailViewModel`; the status sheet consumes the same
/// state-machine-backed targets and confirmation flags.
struct ApplicationDetailView: View {
    /// One sheet binding for both presentations avoids SwiftUI's multiple-`.sheet` limitation.
    private enum PresentedSheet: String, Identifiable {
        case editor
        case statusChange
        case statusHistory

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @State private var viewModel: ApplicationDetailViewModel
    @State private var presentedSheet: PresentedSheet?
    @State private var isConfirmingDelete = false

    init(container: AppContainer, applicationID: UUID) {
        _viewModel = State(initialValue: ApplicationDetailViewModel(
            repository: container.applicationRepository,
            dateProvider: container.dateProvider,
            applicationID: applicationID
        ))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("正在加载…")
            case .loaded(let application):
                content(for: application)
            case .failed:
                failureState
            }
        }
        .navigationTitle("申请详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.application != nil {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("编辑") {
                        presentedSheet = .editor
                    }
                    Button("删除", role: .destructive) {
                        isConfirmingDelete = true
                    }
                }
            }
        }
        .task {
            if case .idle = viewModel.state {
                viewModel.load()
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .editor:
                if let application = viewModel.application {
                    ApplicationEditorView(container: container, application: application) { _ in
                        presentedSheet = nil
                        viewModel.refresh()
                    }
                }
            case .statusChange:
                ApplicationStatusChangeView(viewModel: viewModel)
            case .statusHistory:
                if let application = viewModel.application {
                    StatusHistorySheet(
                        repository: container.applicationRepository,
                        applicationID: application.id
                    )
                }
            }
        }
        .confirmationDialog(
            "删除这份申请？",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if viewModel.delete() {
                    dismiss()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("面试轮次和状态历史会一起删除，关联岗位会保留。")
        }
        .alert("操作失败", isPresented: actionErrorBinding) {
            Button("好", role: .cancel) {
                viewModel.clearActionError()
            }
        } message: {
            Text(viewModel.actionErrorMessage ?? "")
        }
    }

    private func content(for application: Application) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
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

                    Button {
                        presentedSheet = .statusChange
                    } label: {
                        Label("变更状态", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("选择状态机允许的下一个状态")
                }
                .padding(.vertical, 4)
            }

            Section("下一个节点") {
                nextNodeCard(for: application)
            }

            Section("岗位快照") {
                LabeledContent("公司", value: application.companyName)
                LabeledContent("职位", value: application.roleTitle)
                if let jobURL = application.jobURL {
                    Link(destination: jobURL) {
                        Label("打开岗位链接", systemImage: "link")
                    }
                } else {
                    LabeledContent("岗位链接", value: "未填写")
                }
                LabeledContent("地点", value: application.location ?? "未填写")
            }

            Section("备注") {
                if let notes = application.notes, !notes.isEmpty {
                    Text(notes)
                } else {
                    Text("暂无备注")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    presentedSheet = .statusHistory
                } label: {
                    Label("状态历史", systemImage: "clock.arrow.circlepath")
                }
            }
        }
    }

    @ViewBuilder
    private func nextNodeCard(for application: Application) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let deadline = application.deadline {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("截止")
                            .font(.subheadline.weight(.semibold))
                        Text(ApplicationDateFormatting.monthDayTime(deadline))
                    }
                }
            } else {
                Label("暂未设置截止日期", systemImage: "calendar")
                    .foregroundStyle(.secondary)
            }

            // Ticket 16 adds the nearest pending InterviewRound row to this card.
        }
        .padding(.vertical, 2)
    }

    private var failureState: some View {
        ContentUnavailableView {
            Label("加载失败", systemImage: "exclamationmark.triangle")
        } description: {
            Text("加载失败，请稍后重试")
        } actions: {
            Button("重试") {
                viewModel.load()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    /// Alerts are suppressed while the status sheet is up; the sheet shows its own inline error.
    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.actionErrorMessage != nil && presentedSheet != .statusChange },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearActionError()
                }
            }
        )
    }
}
