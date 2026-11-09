import SwiftData
import SwiftUI

/// Multi-select skill picker: search, categories, canonical names, checkmarks, and a live count.
struct SkillPickerView: View {
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("选择技能")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") {
                            dismiss()
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.isSkillPickerEnabled {
            ContentUnavailableView {
                Label("技能词典暂不可用", systemImage: "exclamationmark.triangle")
            } description: {
                Text("技能选择已禁用；其他字段仍可编辑并保存。")
            }
        } else {
            Group {
                if groups.isEmpty {
                    ContentUnavailableView {
                        Label("没有找到技能", systemImage: "magnifyingglass")
                    } description: {
                        Text(
                            query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "技能词典为空。"
                                : "没有匹配「\(query)」的技能，试试其他名称或别名。"
                        )
                    }
                } else {
                    List {
                        Section {
                            Text("已选 \(viewModel.selectedSkillCount) 个技能")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(groups) { group in
                            Section(group.category) {
                                ForEach(group.skills) { skill in
                                    skillRow(skill)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "搜索技能名称或别名")
        }
    }

    private var groups: [SkillCategoryGroup] {
        guard let allSkills = viewModel.allSkills else { return [] }
        return SkillCatalog.groups(from: allSkills, matching: query)
    }

    private func skillRow(_ skill: Skill) -> some View {
        Button {
            viewModel.toggleSkill(skill)
        } label: {
            HStack {
                Text(skill.name)
                    .foregroundStyle(.primary)
                Spacer()
                if viewModel.isSkillSelected(skill) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(skill.name)
        .accessibilityValue(viewModel.isSkillSelected(skill) ? "已选择" : "未选择")
    }
}

#Preview {
    let container = try! AppContainer.makeInMemory()
    SkillPickerView(
        viewModel: ProfileViewModel(
            repository: container.userProfileRepository,
            lexicon: try? MatchingLexiconLoader().load()
        )
    )
    .modelContainer(container.modelContainer)
}

