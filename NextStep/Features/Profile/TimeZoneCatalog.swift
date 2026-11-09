import Foundation

/// One choice in the profile's time-zone picker.
nonisolated struct TimeZoneOption: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
}

/// The common time zones offered by the 我的 tab.
///
/// The profile's current identifier is always included (at the front when it is not part of the
/// common list) so the picker never shows an empty selection.
nonisolated enum TimeZoneCatalog {
    static let commonIdentifiers: [String] = [
        "Asia/Shanghai",
        "Asia/Hong_Kong",
        "Asia/Taipei",
        "Asia/Tokyo",
        "Asia/Seoul",
        "Asia/Singapore",
        "Asia/Kolkata",
        "Asia/Dubai",
        "Europe/London",
        "Europe/Paris",
        "Europe/Berlin",
        "Europe/Amsterdam",
        "Europe/Moscow",
        "America/New_York",
        "America/Chicago",
        "America/Denver",
        "America/Los_Angeles",
        "America/Toronto",
        "America/Vancouver",
        "America/Sao_Paulo",
        "Australia/Sydney",
        "Pacific/Auckland",
        "UTC",
    ]

    static func options(including identifier: String?) -> [TimeZoneOption] {
        var identifiers = commonIdentifiers
        if let identifier, !identifier.isEmpty, !identifiers.contains(identifier) {
            identifiers.insert(identifier, at: 0)
        }
        return identifiers.map { id in
            TimeZoneOption(id: id, displayName: displayName(for: id))
        }
    }

    static func displayName(for identifier: String) -> String {
        guard let zone = TimeZone(identifier: identifier) else { return identifier }
        let localized = zone.localizedName(for: .generic, locale: Locale(identifier: "zh_CN"))
        guard let localized, localized != identifier else { return identifier }
        return "\(localized)（\(identifier)）"
    }
}
