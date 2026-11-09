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
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
