import SwiftUI

/// One row of the application list: company, role, status badge, its node, and last update.
struct ApplicationRowView: View {
    let row: ApplicationListSnapshot.Row

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.application.companyName)
                    .font(.headline)
                Spacer(minLength: 8)
                ApplicationStatusBadge(status: row.application.status)
            }

            Text(row.application.roleTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if let node = row.node {
                    Label(nodeText(for: node), systemImage: "calendar.badge.clock")
                }
                Spacer(minLength: 8)
                Text("更新 \(ApplicationDateFormatting.monthDayTime(row.application.lastModifiedAt))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func nodeText(for node: ApplicationNode) -> String {
        let text = "\(node.title) \(ApplicationDateFormatting.monthDay(node.date))"
        guard node.isOverdue else { return text }
        return "\(text) · \(ApplicationNodeCopy.overdueText)"
    }
}
