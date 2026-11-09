import SwiftUI

struct ProfileView: View {
    var body: some View {
        PlaceholderPage(
            icon: "person.crop.circle",
            title: "我的",
            message: "技能、目标方向、地点与可实习时间会在后续切片编辑。"
        )
        .navigationTitle("我的")
    }
}
