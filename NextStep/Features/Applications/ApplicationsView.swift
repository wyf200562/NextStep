import SwiftUI

struct ApplicationsView: View {
    @Binding var filter: ApplicationListFilter

    var body: some View {
        PlaceholderPage(
            icon: "tray.full",
            title: "申请",
            message: "当前筛选：\(filter.displayName)。申请列表会在后续切片接入。"
        )
        .navigationTitle("申请")
    }
}
