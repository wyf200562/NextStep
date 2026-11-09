import SwiftUI

/// One row of the application list: company, role, status badge, nearest node, and last update.
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
                if let node = row.nearestNode {
                    Label(nodeText(for: node), systemImage: nodeIcon(for: node))
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

    private func nodeText(for node: ApplicationListSnapshot.NearestNode) -> String {
        switch node.kind {
        case .deadline:
            "截止 \(ApplicationDateFormatting.monthDay(node.date))"
        case .interview:
            if let label = node.roundLabel, !label.isEmpty {
                "面试（\(label)）\(ApplicationDateFormatting.monthDay(node.date))"
            } else {
                "面试 \(ApplicationDateFormatting.monthDay(node.date))"
            }
        }
    }

    private func nodeIcon(for node: ApplicationListSnapshot.NearestNode) -> String {
        switch node.kind {
        case .deadline: "calendar.badge.clock"
        case .interview: "person.2"
        }
    }
}
