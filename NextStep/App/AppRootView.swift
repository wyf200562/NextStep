import SwiftData
import SwiftUI

/// Routes the composition root's state. `NextStepApp` owns container creation and retry; this
/// view only renders the ready, failed, or loading state.
struct AppRootView: View {
    let container: AppContainer?
    let didFailToOpenStore: Bool
    let onRetry: () -> Void

    var body: some View {
        Group {
            if let container {
                RootTabView()
                    .environment(container)
                    .modelContainer(container.modelContainer)
            } else if didFailToOpenStore {
                StartupErrorView(onRetry: onRetry)
            } else {
                ProgressView("正在打开本地数据…")
            }
        }
    }
}

/// Blocking failure page. There is no dismiss action; the user can only retry.
struct StartupErrorView: View {
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("本地数据无法打开", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("请重试。如果问题持续存在，请重新启动 App。")
        } actions: {
            Button("重试", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview("本地数据无法打开") {
    StartupErrorView(onRetry: {})
}
