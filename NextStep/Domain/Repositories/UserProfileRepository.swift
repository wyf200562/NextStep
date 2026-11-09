import Foundation

/// Guarantees a single local profile via fetch-or-create.
///
/// A new profile defaults `timeZoneIdentifier` to the current time zone; all other fields start empty.
@MainActor
protocol UserProfileRepository: AnyObject {
    func fetchOrCreateProfile() throws -> UserProfile
    func save(_ profile: UserProfile) throws
}
