import SwiftUI

/// SwiftUI entry point for the app's only UIKit screen.
///
/// The sheet hosts a `UINavigationController` whose root is `StatusHistoryViewController`; the
/// repository is injected directly, so the UIKit page needs no ViewModel.
struct StatusHistorySheet: UIViewControllerRepresentable {
    let repository: any ApplicationRepository
    let applicationID: UUID

    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(
            rootViewController: StatusHistoryViewController(
                repository: repository,
                applicationID: applicationID
            )
        )
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
