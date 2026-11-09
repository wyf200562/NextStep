import SwiftUI

struct ManualImportView: View {
    var body: some View {
        PlaceholderPage(
            icon: "square.and.pencil",
            title: "粘贴 JD",
            message: "手动粘贴岗位描述的表单会在后续切片显示。"
        )
        .navigationTitle("粘贴 JD")
    }
}
