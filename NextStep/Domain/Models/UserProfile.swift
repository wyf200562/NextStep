import Foundation
import SwiftData

/// The single local user profile used for matching.
///
/// `skills` stores canonical skill names from the bundled skill dictionary, without proficiency.
/// The repository guarantees a single profile via fetch-or-create.
@Model
final class UserProfile {
    var id: UUID
    var skills: [String] = []
    var targetRoles: [String] = []
    var preferredLocations: [String] = []
    var timeZoneIdentifier: String?
    var availableFrom: Date?
    var availableUntil: Date?
    var graduationYear: Int?

    init(
        id: UUID = UUID(),
        skills: [String] = [],
        targetRoles: [String] = [],
        preferredLocations: [String] = [],
        timeZoneIdentifier: String? = TimeZone.current.identifier,
        availableFrom: Date? = nil,
        availableUntil: Date? = nil,
        graduationYear: Int? = nil
    ) {
        self.id = id
        self.skills = skills
        self.targetRoles = targetRoles
        self.preferredLocations = preferredLocations
        self.timeZoneIdentifier = timeZoneIdentifier
        self.availableFrom = availableFrom
        self.availableUntil = availableUntil
        self.graduationYear = graduationYear
    }
}
