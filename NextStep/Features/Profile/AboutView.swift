import SwiftUI

struct AboutView: View {
    var body: some View {
        PlaceholderPage(
            icon: "info.circle",
            title: "关于",
            message: "版本号、数据来源声明与开源链接会显示在这里。"
        )
        .navigationTitle("关于")
    }
}
