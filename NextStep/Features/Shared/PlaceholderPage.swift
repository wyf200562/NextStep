import SwiftUI

/// Shared empty placeholder used by every feature shell in this scaffolding slice.
struct PlaceholderPage: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        }
    }
}
