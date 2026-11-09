import SwiftUI

struct OverviewView: View {
    var body: some View {
        PlaceholderPage(
            icon: "rectangle.grid.2x2",
            title: "概览",
            message: "今天和接下来 7 天的截止、面试与进展计数会显示在这里。"
        )
        .navigationTitle("概览")
    }
}
