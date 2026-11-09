import SwiftUI

/// One agenda row: day/time, company + action, and the deadline/interview glyph. Past events stay
/// visible with a 「已过」 marker and dimmed content.
struct DashboardEventRow: View {
    let event: DashboardEvent
    let now: Date
    let calendar: Calendar

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(DashboardFormatting.dayLabel(for: event.date, now: now, calendar: calendar))
                    .font(.caption.weight(.semibold))
                Text(DashboardFormatting.time(event.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 52, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(event.application.companyName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if event.isPast {
                        Text("已过")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                            .foregroundStyle(.secondary)
                    }
                }
                Text("\(event.title) · \(event.application.roleTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Image(systemName: event.kind == .deadline ? "calendar.badge.clock" : "person.2")
                .font(.callout)
                .foregroundStyle(event.kind == .deadline ? Color.orange : Color.blue)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .opacity(event.isPast ? 0.65 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("打开申请详情")
    }
}

/// One 最近更新 row: company, role, status badge, and last-modified time.
struct DashboardRecentRow: View {
    let application: Application

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(application.companyName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(application.roleTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                ApplicationStatusBadge(status: application.status)
                Text("更新 \(ApplicationDateFormatting.monthDayTime(application.lastModifiedAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("打开申请详情")
    }
}
