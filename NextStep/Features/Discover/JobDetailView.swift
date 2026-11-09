import Foundation
import SwiftUI

struct JobDetailView: View {
    let jobID: UUID

    var body: some View {
        PlaceholderPage(
            icon: "doc.richtext",
            title: "岗位详情",
            message: "岗位信息、匹配解释和导入入口会在后续切片显示。"
        )
        .navigationTitle("岗位详情")
    }
}
