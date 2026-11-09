import os
import SwiftData
import SwiftUI

/// The pushed 关于 page: version, Remotive data-source attribution, and the project link.
struct AboutView: View {
    var body: some View {
        List {
            Section("版本") {
                LabeledContent("版本号", value: AppInfo.version)
                LabeledContent("构建号", value: AppInfo.build)
            }

            Section("数据来源与合规") {
                Text("岗位数据来自 Remotive 公共 API。岗位标题、公司与描述版权归原发布方所有。")
                Text("岗位卡片和详情中的来源链接会回到 Remotive 或原始发布页面；NextStep 不在仓库或演示数据集中复制真实 JD 全文。")
                Link(destination: AppInfo.remotiveURL) {
                    Label("访问 Remotive", systemImage: "safari")
                }
            }

            Section("开源链接") {
                Link(destination: AppInfo.provisionalGitHubURL) {
                    Label("GitHub", systemImage: "link")
                }
                .accessibilityLabel("在 GitHub 上查看 NextStep")
                Text("仓库地址为临时占位，正式公开地址会在发布准备中更新。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            #if DEBUG
            DebugDemoDataSection()
            #endif
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
/// Debug-only destructive action so the golden path can be demonstrated repeatedly.
///
/// Release builds compile this section out, which is why the container environment is only read
/// inside the `#if DEBUG` view.
private struct DebugDemoDataSection: View {
    @Environment(AppContainer.self) private var container
    @State private var isConfirming = false
    @State private var isResetting = false
    @State private var successMessage: String?
    @State private var failureMessage: String?

    var body: some View {
        Section {
            Button(role: .destructive) {
                isConfirming = true
            } label: {
                Label("清空演示数据", systemImage: "trash")
            }
            .disabled(isResetting)

            if isResetting {
                ProgressView("正在清空…")
            }

            if let successMessage {
                Label(successMessage, systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("调试")
        } footer: {
            Text("删除本机全部申请、岗位、面试轮次、状态历史与画像，并重置 Remotive 刷新配额。仅 Debug 构建可见；重新启动 App 后完全回到首次启动状态。")
        }
        .confirmationDialog(
            "清空全部本地数据？",
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button("清空演示数据", role: .destructive, action: clear)
        } message: {
            Text("此操作不可撤销。")
        }
        .alert(
            "清空失败",
            isPresented: Binding(
                get: { failureMessage != nil },
                set: { isPresented in
                    if !isPresented { failureMessage = nil }
                }
            )
        ) {
            Button("好", role: .cancel) { failureMessage = nil }
        } message: {
            Text(failureMessage ?? "")
        }
    }

    private func clear() {
        isResetting = true
        successMessage = nil
        defer { isResetting = false }

        do {
            try container.resetDemoData()
            successMessage = "已清空演示数据，重启 App 后完全回到首次启动状态。"
            AppLogger.app.info("Cleared all demo data from the debug 关于 action")
        } catch {
            AppLogger.app.error(
                "Failed to clear demo data: \(error.localizedDescription, privacy: .public)"
            )
            failureMessage = "清空失败，请重试。"
        }
    }
}
#endif

#Preview {
    let container = try! AppContainer.makeInMemory()
    NavigationStack {
        AboutView()
    }
    .environment(container)
    .modelContainer(container.modelContainer)
}
