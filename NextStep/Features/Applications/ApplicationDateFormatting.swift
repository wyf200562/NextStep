import Foundation

/// Shared Chinese date formatting for application rows and the detail shell.
enum ApplicationDateFormatting {
    private static let locale = Locale(identifier: "zh_CN")

    static func monthDay(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().locale(locale))
    }

    static func monthDayTime(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().hour().minute().locale(locale))
    }
}
