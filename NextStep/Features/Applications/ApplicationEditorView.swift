import SwiftUI

/// Create-application form. Owns an `ApplicationEditorViewModel`; writes go through the repository.
struct ApplicationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ApplicationEditorViewModel
    @State private var isConfirmingDiscard = false
    private let onSaved: (UUID) -> Void

    init(container: AppContainer, onSaved: @escaping (UUID) -> Void) {
        _viewModel = State(initialValue: ApplicationEditorViewModel(
            repository: container.applicationRepository,
            dateProvider: container.dateProvider
        ))
        self.onSaved = onSaved
    }

    var body: some View {
        @Bindable var model = viewModel
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("公司 *", text: $model.companyName)
                    inlineError(viewModel.companyError)

                    TextField("职位 *", text: $model.roleTitle)
                    inlineError(viewModel.roleError)
                }

                Section("状态") {
                    Picker("初始状态", selection: $model.initialStatus) {
                        ForEach(ApplicationStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }

                    if viewModel.showsStatusDate {
                        DatePicker(
                            "状态日期",
                            selection: $model.statusDate,
                            in: ...viewModel.currentDate,
                            displayedComponents: .date
                        )
                    }
                }

                Section("截止日期") {
                    Toggle("设置截止日期", isOn: $model.hasDeadline)
                    if viewModel.hasDeadline {
                        DatePicker("日期", selection: $model.deadlineDay, displayedComponents: .date)
                        Toggle("设置具体时刻（默认 09:00）", isOn: $model.includesDeadlineTime)
                        if viewModel.includesDeadlineTime {
                            DatePicker(
                                "时刻",
                                selection: $model.deadlineTime,
                                displayedComponents: .hourAndMinute
                            )
                        }
                    }
                }

                Section("链接与地点") {
                    TextField("岗位链接", text: $model.jobURLText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    inlineError(viewModel.jobURLError)

                    TextField("地点", text: $model.locationText)
                }

                Section("备注") {
                    TextField("备注", text: $model.notesText, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let saveErrorMessage = viewModel.saveErrorMessage {
                    Section {
                        Text(saveErrorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("新建申请")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(viewModel.isSaving)
                }
            }
            .interactiveDismissDisabled(viewModel.hasUnsavedChanges)
            .confirmationDialog(
                "放弃未保存的修改？",
                isPresented: $isConfirmingDiscard,
                titleVisibility: .visible
            ) {
                Button("放弃修改", role: .destructive) { dismiss() }
                Button("继续编辑", role: .cancel) {}
            }
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

    private func cancel() {
        if viewModel.hasUnsavedChanges {
            isConfirmingDiscard = true
        } else {
            dismiss()
        }
    }

    private func save() {
        viewModel.save()
        if let applicationID = viewModel.savedApplicationID {
            onSaved(applicationID)
        }
    }
}
