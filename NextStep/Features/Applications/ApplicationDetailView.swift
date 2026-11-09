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
        case roundEditor
        case statusHistory

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @State private var viewModel: ApplicationDetailViewModel
    @State private var presentedSheet: PresentedSheet?
    @State private var roundBeingEdited: InterviewRound?
    @State private var isShowingMarkAsInterviewPrompt = false
    @State private var isConfirmingDelete = false
    @State private var roundPendingDeletion: InterviewRound?

    init(container: AppContainer, applicationID: UUID) {
        _viewModel = State(initialValue: ApplicationDetailViewModel(
            repository: container.applicationRepository,
            dateProvider: container.dateProvider,
            applicationID: applicationID,
            matchProvider: container.matchProvider
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
        .sheet(item: $presentedSheet, onDismiss: {
            // Present the prompt only after the editor sheet is gone; presenting it from inside
            // the sheet can be swallowed by the still-visible dismissal.
            if viewModel.isPromptingMarkAsInterview {
                isShowingMarkAsInterviewPrompt = true
            }
        }) { sheet in
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
            case .roundEditor:
                InterviewRoundEditorView(
                    container: container,
                    detailViewModel: viewModel,
                    round: roundBeingEdited
                ) {
                    presentedSheet = nil
                    roundBeingEdited = nil
                }
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
                nextNodeCard
            }

            Section("面试轮次") {
                if viewModel.rounds.isEmpty {
                    Text("还没有面试轮次")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.rounds, id: \.id) { round in
                        Button {
                            roundBeingEdited = round
                            presentedSheet = .roundEditor
                        } label: {
                            roundRow(round)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button("删除", role: .destructive) {
                                roundPendingDeletion = round
                            }
                        }
                    }
                }

                Button {
                    roundBeingEdited = nil
                    presentedSheet = .roundEditor
                } label: {
                    Label("添加面试轮次", systemImage: "plus")
                }
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

            // Associated posting summary (ticket 21) and its recomputed compact match summary
            // (ticket 22). When the posting is missing, the snapshot sections above remain the
            // only source and no match summary renders.
            if let summary = ApplicationJobPostingSummary(jobPosting: application.jobPosting) {
                Section("关联岗位") {
                    LabeledContent("职位", value: summary.title)
                    LabeledContent("公司", value: summary.companyName)
                    LabeledContent("来源", value: summary.sourceName)
                    if let jobURL = summary.jobURL {
                        Link(destination: jobURL) {
                            Label("打开原岗位", systemImage: "link")
                        }
                    }
                    matchSummaryRow
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
        .alert(
            "是否标记为面试中？",
            isPresented: markAsInterviewBinding
        ) {
            Button("标记为面试中") {
                isShowingMarkAsInterviewPrompt = false
                viewModel.confirmMarkAsInterview()
            }
            Button("暂不", role: .cancel) {
                isShowingMarkAsInterviewPrompt = false
                viewModel.cancelMarkAsInterviewPrompt()
            }
        } message: {
            Text("已添加未来的面试轮次。")
        }
        .confirmationDialog(
            "删除这轮面试？",
            isPresented: isConfirmingRoundDeletion,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let round = roundPendingDeletion {
                    viewModel.deleteRound(round)
                }
                roundPendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                roundPendingDeletion = nil
            }
        } message: {
            Text("这轮面试会从申请中删除，此操作不可撤销。")
        }
    }

    /// Compact, recomputed match explanation for the associated posting; hidden when the profile
    /// gate is unmet or matching is unavailable, with a prompt instead.
    @ViewBuilder
    private var matchSummaryRow: some View {
        switch viewModel.matchAvailability {
        case .ready:
            if let match = viewModel.matchResult {
                CompactMatchSummary(match: match)
            }
        case .profileIncomplete:
            Button {
                container.router.openProfile()
            } label: {
                Label("完善画像后查看匹配", systemImage: "person.crop.circle")
            }
        case .unavailable:
            Label("匹配暂不可用", systemImage: "sparkles.slash")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var nextNodeCard: some View {
        if let node = viewModel.nextNode {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: node.kind == .deadline ? "calendar.badge.clock" : "person.2")
                    .foregroundStyle(node.kind == .deadline ? Color.orange : Color.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(nextNodeTitle(node))
                        .font(.subheadline.weight(.semibold))
                    Text(ApplicationDateFormatting.monthDayTime(node.date))
                }
            }
            .padding(.vertical, 2)
        } else {
            Text("暂无即将到来的截止或面试")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 2)
        }
    }

    private func nextNodeTitle(_ node: ApplicationNextNode) -> String {
        switch node.kind {
        case .deadline:
            "截止"
        case .interview:
            if let label = node.roundLabel, !label.isEmpty {
                "面试 · \(label)"
            } else {
                "面试"
            }
        }
    }

    private func roundRow(_ round: InterviewRound) -> some View {
        let isPast = round.scheduledAt < viewModel.currentDate
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(roundTitle(round))
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text(round.result.displayName)
                    .font(.caption)
                    .foregroundStyle(roundResultColor(round.result))
            }
            Text("\(round.format.displayName) · \(ApplicationDateFormatting.monthDayTime(round.scheduledAt))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let contact = round.contact, !contact.isEmpty {
                Text("联系人：\(contact)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(isPast ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("编辑这轮面试")
    }

    private func roundTitle(_ round: InterviewRound) -> String {
        if let label = round.label, !label.isEmpty {
            return label
        }
        return "面试"
    }

    private func roundResultColor(_ result: InterviewResult) -> Color {
        switch result {
        case .pending: .secondary
        case .passed: .green
        case .failed: .red
        case .cancelled: .secondary
        }
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

    /// The mark-as-interview alert is shown only after the round editor sheet has fully dismissed.
    /// The alert buttons resolve the ViewModel intent explicitly; the binding only drives visibility.
    private var markAsInterviewBinding: Binding<Bool> {
        Binding(
            get: { isShowingMarkAsInterviewPrompt },
            set: { isShowingMarkAsInterviewPrompt = $0 }
        )
    }

    /// Drives the round-delete confirmation from the row's pending round.
    private var isConfirmingRoundDeletion: Binding<Bool> {
        Binding(
            get: { roundPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    roundPendingDeletion = nil
                }
            }
        )
    }

    /// Alerts are suppressed while a sheet is up; sheets show their own inline error.
    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.actionErrorMessage != nil && presentedSheet == nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearActionError()
                }
            }
        )
    }
}
