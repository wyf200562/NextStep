import SwiftUI

/// Chinese status badge shared by the list row and the detail header.
struct ApplicationStatusBadge: View {
    let status: ApplicationStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(tint)
            .background(tint.opacity(0.15), in: Capsule())
            .accessibilityLabel("状态：\(status.displayName)")
    }

    private var tint: Color {
        switch status {
        case .wishlist: .gray
        case .applied: .blue
        case .oa: .orange
        case .interview: .purple
        case .offer: .green
        case .rejected: .red
        case .withdrawn: .secondary
        }
    }
}
