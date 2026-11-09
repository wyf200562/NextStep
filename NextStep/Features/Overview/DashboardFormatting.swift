import Foundation

/// Presentation formatting for overview dates. Pure and calendar-injected so rows stay consistent
/// with the builder's day windows.
enum DashboardFormatting {
    private static let locale = Locale(identifier: "zh_CN")

    /// Example: 「11月9日 · 周一」 shown above the 概览 title.
    static func dateOverline(_ date: Date) -> String {
        let monthDay = date.formatted(.dateTime.month().day().locale(locale))
        let weekday = date.formatted(.dateTime.weekday(.abbreviated).locale(locale))
        return "\(monthDay) · \(weekday)"
    }

    /// 「今天」/「明天」/「后天」 for near days, otherwise 「11/16」 relative to the injected calendar.
    static func dayLabel(for date: Date, now: Date, calendar: Calendar) -> String {
        let today = calendar.startOfDay(for: now)
        let day = calendar.startOfDay(for: date)
        let difference = calendar.dateComponents([.day], from: today, to: day).day ?? 0
        switch difference {
        case 0: return "今天"
        case 1: return "明天"
        case 2: return "后天"
        default:
            let components = calendar.dateComponents([.month, .day], from: day)
            return "\(components.month ?? 0)/\(components.day ?? 0)"
        }
    }

    /// 24-hour clock time, e.g. 「09:00」.
    static func time(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .locale(locale)
        )
    }
}
