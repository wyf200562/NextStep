import SwiftUI

/// Add/edit form for one interview round. Draft state lives in `InterviewRoundEditorViewModel`;
/// the save intent goes through `ApplicationDetailViewModel` so the detail screen owns the
/// mark-as-interview prompt. Status is never edited here.
struct InterviewRoundEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var editor: InterviewRoundEditorViewModel
    @State private var isConfirmingDiscard = false

    private let detailViewModel: ApplicationDetailViewModel
    private let round: InterviewRound?
    private let onSaved: () -> Void

    init(
        container: AppContainer,
        detailViewModel: ApplicationDetailViewModel,
        round: InterviewRound?,
        onSaved: @escaping () -> Void
    ) {
        self.detailViewModel = detailViewModel
        self.round = round
        self.onSaved = onSaved
        if let round {
            _editor = State(initialValue: InterviewRoundEditorViewModel(
                dateProvider: container.dateProvider,
                round: round
            ))
        } else {
            _editor = State(initialValue: InterviewRoundEditorViewModel(
                dateProvider: container.dateProvider
            ))
        }
    }

    var body: some View {
        @Bindable var model = editor
        NavigationStack {
            Form {
                Section("时间") {
                    DatePicker("日期", selection: $model.scheduledDay, displayedComponents: .date)
                    DatePicker("时刻", selection: $model.scheduledTime, displayedComponents: .hourAndMinute)
                }

                Section("详情") {
                    Picker("形式", selection: $model.format) {
                        ForEach(InterviewFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }

                    TextField("名称（如「一面」「HR 面」）", text: $model.label)
                    TextField("联系人", text: $model.contact)
                    TextField("备注", text: $model.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("结果") {
                    Picker("结果", selection: $model.result) {
                        ForEach(InterviewResult.allCases) { result in
                            Text(result.displayName).tag(result)
                        }
                    }
                }

                if let message = detailViewModel.actionErrorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(editor.isEditing ? "编辑面试轮次" : "添加面试轮次")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(detailViewModel.isSavingRound)
                }
            }
            .interactiveDismissDisabled(editor.hasUnsavedChanges)
            .confirmationDialog(
                "放弃未保存的修改？",
                isPresented: $isConfirmingDiscard,
                titleVisibility: .visible
            ) {
                Button("放弃修改", role: .destructive) { dismiss() }
                Button("继续编辑", role: .cancel) {}
            }
            .onDisappear {
                detailViewModel.clearActionError()
            }
        }
    }

    private func cancel() {
        if editor.hasUnsavedChanges {
            isConfirmingDiscard = true
        } else {
            dismiss()
        }
    }

    private func save() {
        let saved: Bool
        if let round {
            saved = detailViewModel.updateRound(
                round,
                scheduledAt: editor.scheduledAt,
                format: editor.format,
                label: editor.label,
                contact: editor.contact,
                notes: editor.notes,
                result: editor.result
            )
        } else {
            saved = detailViewModel.addRound(
                scheduledAt: editor.scheduledAt,
                format: editor.format,
                label: editor.label,
                contact: editor.contact,
                notes: editor.notes,
                result: editor.result
            )
        }

        if saved {
            onSaved()
        }
    }
}
