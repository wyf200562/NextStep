import Foundation

/// Editable snapshot of the single `UserProfile`.
///
/// The ViewModel mutates this value and only writes it back to the model on an explicit save.
/// `skills` holds canonical `Skill.name` values; dates and the graduation year are display-only
/// in v1 and never feed the match score.
nonisolated struct ProfileDraft: Equatable, Sendable {
    var skills: [String] = []
    var targetRoles: [String] = []
    var preferredLocations: [String] = []
    var timeZoneIdentifier: String = TimeZone.current.identifier
    var availableFrom: Date?
    var availableUntil: Date?
    var graduationYear: Int?

    init(
        skills: [String] = [],
        targetRoles: [String] = [],
        preferredLocations: [String] = [],
        timeZoneIdentifier: String = TimeZone.current.identifier,
        availableFrom: Date? = nil,
        availableUntil: Date? = nil,
        graduationYear: Int? = nil
    ) {
        self.skills = skills
        self.targetRoles = targetRoles
        self.preferredLocations = preferredLocations
        self.timeZoneIdentifier = timeZoneIdentifier
        self.availableFrom = availableFrom
        self.availableUntil = availableUntil
        self.graduationYear = graduationYear
    }
}
