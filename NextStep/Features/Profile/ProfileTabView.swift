import SwiftUI

/// 我的 tab root. Owns the `ProfileViewModel` so leaving the tab with unsaved edits can ask for
/// confirmation before the draft is discarded.
struct ProfileTabView: View {
    @Environment(AppContainer.self) private var container
    @State private var path: [ProfileRoute] = []
    @State private var viewModel: ProfileViewModel?
    @State private var isConfirmingDiscard = false
    @State private var tabAfterDiscard: AppTab?

    var body: some View {
        @Bindable var router = container.router
        NavigationStack(path: $path) {
            Group {
                if let viewModel {
                    ProfileView(viewModel: viewModel)
                } else {
                    ProgressView("正在加载画像…")
                }
            }
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .about:
                    AboutView()
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ProfileViewModel(
                    repository: container.userProfileRepository,
                    lexicon: container.matchingLexicon
                )
            }
        }
        .onChange(of: router.selectedTab) { oldValue, newValue in
            // The profile is a tab root, so "leaving the editor" means switching tabs.
            guard oldValue == .profile,
                  newValue != .profile,
                  let viewModel,
                  viewModel.hasUnsavedChanges else { return }

            tabAfterDiscard = newValue
            router.selectedTab = .profile
            isConfirmingDiscard = true
        }
        .confirmationDialog(
            "放弃未保存的修改？",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("放弃修改", role: .destructive) {
                viewModel?.discardChanges()
                if let tabAfterDiscard {
                    router.selectedTab = tabAfterDiscard
                }
                tabAfterDiscard = nil
            }
            Button("继续编辑", role: .cancel) {
                tabAfterDiscard = nil
            }
        }
        .onChange(of: isConfirmingDiscard) { _, isPresented in
            if !isPresented {
                tabAfterDiscard = nil
            }
        }
        .onChange(of: router.pendingRoute, initial: true) { _, _ in
            _ = container.router.takePendingRoute(for: .profile)
        }
    }
}
