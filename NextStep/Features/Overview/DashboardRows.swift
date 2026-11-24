import SwiftUI

/// One agenda row: day/time, company + node, and the node glyph. Events only ever come from the
/// deadline, so there is one glyph and no 「已过」 marker — past nodes left the agenda.
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
                Text(event.application.companyName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(event.title) · \(event.application.roleTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Image(systemName: "calendar.badge.clock")
                .font(.callout)
                .foregroundStyle(Color.orange)

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
