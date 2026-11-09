import SwiftData
import SwiftUI

/// The 我的 tab form.
///
/// The ViewModel is created and owned by `ProfileTabView` so the tab can confirm before leaving
/// with unsaved edits. All writes go through `ProfileViewModel` → `UserProfileRepository`.
struct ProfileView: View {
    @Bindable var viewModel: ProfileViewModel

    @State private var newTargetRole = ""
    @State private var newPreferredLocation = ""
    @State private var isShowingSkillPicker = false

    var body: some View {
        Group {
            if let loadErrorMessage = viewModel.loadErrorMessage {
                loadFailureState(message: loadErrorMessage)
            } else {
                form
            }
        }
        .navigationTitle("我的")
        .sheet(isPresented: $isShowingSkillPicker) {
            SkillPickerView(viewModel: viewModel)
        }
    }

    // MARK: - Form

    private var form: some View {
        Form {
            targetRolesSection
            skillsSection
            preferredLocationsSection
            availabilitySection
            aboutSection
            saveSection
        }
    }

    private var targetRolesSection: some View {
        Section {
            tagPills(for: viewModel.draft.targetRoles) { role in
                viewModel.removeTargetRole(role)
            }

            HStack {
                TextField("例如：iOS 开发实习", text: $newTargetRole)
                    .submitLabel(.done)
                    .onSubmit(addTargetRole)
                Button("添加", action: addTargetRole)
                    .disabled(TagList.normalized(newTargetRole) == nil)
            }
        } header: {
            Text("目标方向")
        } footer: {
            if let hint = viewModel.targetRoleGateHint {
                Text(hint)
            }
        }
    }

    private var skillsSection: some View {
        Section {
            if let unavailableMessage = viewModel.skillAvailabilityMessage {
                Label(unavailableMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                Text("技能选择已禁用；其他字段仍可编辑并保存。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Text("已选 \(viewModel.selectedSkillCount) 个技能")
                    Spacer()
                    Button("选择技能") {
                        isShowingSkillPicker = true
                    }
                }
            }

            tagPills(for: viewModel.draft.skills) { skill in
                viewModel.removeSkill(named: skill)
            }
        } header: {
            Text("技能")
        } footer: {
            if let hint = viewModel.skillGateHint {
                Text(hint)
            }
        }
    }

    private var preferredLocationsSection: some View {
        Section {
            tagPills(for: viewModel.draft.preferredLocations) { location in
                viewModel.removePreferredLocation(location)
            }

            HStack {
                TextField("例如：上海、Remote", text: $newPreferredLocation)
                    .submitLabel(.done)
                    .onSubmit(addPreferredLocation)
                Button("添加", action: addPreferredLocation)
                    .disabled(TagList.normalized(newPreferredLocation) == nil)
            }
        } header: {
            Text("偏好地点")
        }
    }

    private var availabilitySection: some View {
        Section {
            Picker("时区", selection: $viewModel.draft.timeZoneIdentifier) {
                ForEach(viewModel.timeZoneChoices) { option in
                    Text(option.displayName).tag(option.id)
                }
            }

            Toggle(
                "设置可实习开始时间",
                isOn: Binding(
                    get: { viewModel.draft.availableFrom != nil },
                    set: { viewModel.setAvailableFromEnabled($0) }
                )
            )
            if let availableFrom = viewModel.draft.availableFrom {
                DatePicker(
                    "开始时间",
                    selection: Binding(
                        get: { viewModel.draft.availableFrom ?? availableFrom },
                        set: { viewModel.draft.availableFrom = $0 }
                    ),
                    displayedComponents: .date
                )
            }

            Toggle(
                "设置可实习结束时间",
                isOn: Binding(
                    get: { viewModel.draft.availableUntil != nil },
                    set: { viewModel.setAvailableUntilEnabled($0) }
                )
            )
            if let availableUntil = viewModel.draft.availableUntil {
                DatePicker(
                    "结束时间",
                    selection: Binding(
                        get: { viewModel.draft.availableUntil ?? availableUntil },
                        set: { viewModel.draft.availableUntil = $0 }
                    ),
                    displayedComponents: .date
                )
            }

            LabeledContent("毕业年份") {
                TextField("可选", text: $viewModel.graduationYearText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
            }
        } header: {
            Text("实习安排")
        } footer: {
            Text("时区、可实习时间与毕业年份在 v1 只展示，不参与匹配计分。")
        }
    }

    private var aboutSection: some View {
        Section {
            NavigationLink(value: ProfileRoute.about) {
                Label("关于 NextStep", systemImage: "info.circle")
            }
        }
    }

    private var saveSection: some View {
        Section {
            Button(action: viewModel.save) {
                HStack {
                    Spacer()
                    if viewModel.isSaving {
                        ProgressView()
                            .padding(.trailing, 6)
                    }
                    Text(viewModel.isSaving ? "保存中…" : "保存")
                    Spacer()
                }
            }
            .disabled(viewModel.isSaving)

            if let saveErrorMessage = viewModel.saveErrorMessage {
                Label(saveErrorMessage, systemImage: "exclamationmark.circle")
                    .foregroundStyle(.red)
            }

            HStack(spacing: 6) {
                Image(systemName: viewModel.hasUnsavedChanges ? "circle.fill" : "checkmark.circle")
                Text(viewModel.hasUnsavedChanges ? "有未保存的修改" : "已保存")
            }
            .font(.footnote)
            .foregroundStyle(viewModel.hasUnsavedChanges ? Color.orange : Color.secondary)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func tagPills(
        for tags: [String],
        onRemove: @escaping (String) -> Void
    ) -> some View {
        if !tags.isEmpty {
            TagFlowLayout {
                ForEach(tags, id: \.self) { tag in
                    TagPillView(title: tag) {
                        onRemove(tag)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func addTargetRole() {
        viewModel.addTargetRole(newTargetRole)
        newTargetRole = ""
    }

    private func addPreferredLocation() {
        viewModel.addPreferredLocation(newPreferredLocation)
        newPreferredLocation = ""
    }

    private func loadFailureState(message: String) -> some View {
        ContentUnavailableView {
            Label("画像加载失败", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("重试") {
                viewModel.load()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    let container = try! AppContainer.makeInMemory()
    NavigationStack {
        ProfileView(
            viewModel: ProfileViewModel(
                repository: container.userProfileRepository,
                lexicon: try? MatchingLexiconLoader().load()
            )
        )
    }
    .modelContainer(container.modelContainer)
}
