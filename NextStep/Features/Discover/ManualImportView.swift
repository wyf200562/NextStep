import SwiftUI

/// Manual "paste a JD" form. Saves through `JobRepository.importManual`; on success the parent
/// replaces this screen with the new posting's detail.
struct ManualImportView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    let onSaved: (UUID) -> Void

    @State private var viewModel: ManualImportViewModel?
    @State private var isConfirmingDiscard = false

    private var hasContent: Bool {
        viewModel?.hasContent ?? false
    }

    var body: some View {
        Group {
            if let viewModel {
                ManualImportForm(viewModel: viewModel, onSaved: onSaved)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("粘贴 JD")
        .navigationBarTitleDisplayMode(.inline)
        // With content, the custom 取消 button replaces the system back button so leaving always
        // asks first; the swipe-back gesture is disabled with it. An empty form leaves immediately.
        .navigationBarBackButtonHidden(hasContent)
        .toolbar {
            if hasContent {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isConfirmingDiscard = true
                    }
                }
            }
        }
        .interactiveDismissDisabled(hasContent)
        .confirmationDialog(
            "放弃未保存的修改？",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("放弃修改", role: .destructive) { dismiss() }
            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("表单内容不会被保存。")
        }
        .task {
            guard viewModel == nil else { return }
            viewModel = ManualImportViewModel(jobRepository: container.jobRepository)
        }
    }
}

private struct ManualImportForm: View {
    @Bindable var viewModel: ManualImportViewModel
    let onSaved: (UUID) -> Void

    var body: some View {
        Form {
            Section {
                field("岗位标题 *", text: $viewModel.title, error: viewModel.error(for: .title))
                field("公司 *", text: $viewModel.companyName, error: viewModel.error(for: .companyName))
                VStack(alignment: .leading, spacing: 4) {
                    TextField("JD 正文 *", text: $viewModel.descriptionPlainText, axis: .vertical)
                        .lineLimit(6...14)
                    inlineError(viewModel.error(for: .descriptionPlainText))
                }
            } header: {
                Text("必填")
            } footer: {
                Text("岗位类型留空时，标题含 intern / 实习会自动保存为实习。")
            }

            Section("可选") {
                TextField("地点", text: $viewModel.location)
                VStack(alignment: .leading, spacing: 4) {
                    TextField("岗位链接（https://…）", text: $viewModel.jobURLText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    inlineError(viewModel.error(for: .jobURL))
                }
                Picker("岗位类型", selection: $viewModel.jobType) {
                    ForEach(JobTypeOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                TextField("标签（用逗号分隔）", text: $viewModel.tagsText)
            }

            if let message = viewModel.saveErrorMessage {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task {
                        if let jobID = await viewModel.save() {
                            onSaved(jobID)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Spacer()
                        if viewModel.isSaving {
                            ProgressView()
                        }
                        Text(viewModel.isSaving ? "保存中…" : "保存岗位")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
    }

    @ViewBuilder
    private func field(_ title: String, text: Binding<String>, error: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(title, text: text)
            inlineError(error)
        }
    }

    @ViewBuilder
    private func inlineError(_ message: String?) -> some View {
        if let message {
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}
