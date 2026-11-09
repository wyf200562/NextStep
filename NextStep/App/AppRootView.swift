import os
import SwiftData
import SwiftUI

/// Owns composition-root creation. Container failure shows a blocking Chinese error page with retry.
struct AppRootView: View {
    @State private var container: AppContainer?
    @State private var didFailToOpenStore = false

    var body: some View {
        Group {
            if let container {
                RootTabView()
                    .environment(container)
                    .modelContainer(container.modelContainer)
            } else if didFailToOpenStore {
                StartupErrorView(onRetry: loadContainer)
            } else {
                ProgressView("正在打开本地数据…")
                    .task {
                        guard container == nil, !didFailToOpenStore else { return }
                        loadContainer()
                    }
            }
        }
    }

    @MainActor
    private func loadContainer() {
        didFailToOpenStore = false
        do {
            container = try AppContainer.makeDefault()
        } catch {
            AppLogger.app.error(
                "Failed to open the local store: \(error.localizedDescription, privacy: .public)"
            )
            didFailToOpenStore = true
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
