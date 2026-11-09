import SwiftUI

/// Status-change sheet.
///
/// Targets and confirmation flags come from `ApplicationDetailViewModel`, which reads
/// `ApplicationStateMachine`; this view only renders them and never duplicates the transition table.
struct ApplicationStatusChangeView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: ApplicationDetailViewModel

    @State private var note = ""
    @State private var pendingTarget: ApplicationStatus?
    @State private var isConfirming = false

    var body: some View {
        NavigationStack {
            Form {
                currentStatusSection

                if viewModel.targets.isEmpty {
                    Section {
                        Text(terminalMessage)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("变更到") {
                        ForEach(viewModel.targets) { target in
                            Button {
                                select(target)
                            } label: {
                                HStack {
                                    Text(target.displayName)
                                    Spacer()
                                    if viewModel.requiresConfirmation(to: target) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                            .accessibilityLabel("需要确认")
                                    }
                                }
                            }
                            .disabled(viewModel.isChangingStatus)
                        }
                    }

                    Section("备注（可选）") {
                        TextField("备注", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }

                if let message = viewModel.actionErrorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("变更状态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                confirmationTitle,
                isPresented: $isConfirming,
                titleVisibility: .visible,
                presenting: pendingTarget
            ) { target in
                Button("确认变更", role: .destructive) {
                    perform(target)
                }
                Button("取消", role: .cancel) {}
            } message: { target in
                Text(confirmationMessage(for: target))
            }
            .onDisappear {
                viewModel.clearActionError()
            }
        }
    }

    @ViewBuilder
    private var currentStatusSection: some View {
        if let application = viewModel.application {
            Section("当前状态") {
                HStack {
                    Text("状态")
                    Spacer()
                    ApplicationStatusBadge(status: application.status)
                }
            }
        }
    }

    private var terminalMessage: String {
        if viewModel.application?.status == .offer {
            return "Offer 是成功终态，不能再变更状态。"
        }
        return "当前没有可变更的状态。"
    }

    private var confirmationTitle: String {
        guard let pendingTarget else { return "确认变更状态？" }
        return viewModel.isReopen(to: pendingTarget) ? "重新打开申请？" : "回退状态？"
    }

    private func confirmationMessage(for target: ApplicationStatus) -> String {
        let current = viewModel.application?.status.displayName ?? "当前状态"
        let action = viewModel.isReopen(to: target) ? "重新打开为" : "回退到"
        return "将从「\(current)」\(action)「\(target.displayName)」。"
    }

    private func select(_ target: ApplicationStatus) {
        viewModel.clearActionError()
        if viewModel.requiresConfirmation(to: target) {
            pendingTarget = target
            isConfirming = true
        } else {
            perform(target)
        }
    }

    private func perform(_ target: ApplicationStatus) {
        guard viewModel.changeStatus(to: target, note: note) else { return }
        dismiss()
    }
}
