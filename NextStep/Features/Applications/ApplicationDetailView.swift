import Foundation
import SwiftUI

struct ApplicationDetailView: View {
    let applicationID: UUID

    var body: some View {
        PlaceholderPage(
            icon: "doc.text.magnifyingglass",
            title: "申请详情",
            message: "状态、截止日期、面试轮次和状态历史会在后续切片显示。"
        )
        .navigationTitle("申请详情")
    }
}
