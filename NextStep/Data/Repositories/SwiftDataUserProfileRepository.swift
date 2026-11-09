import Foundation
import os
import SwiftData

/// SwiftData implementation of the single-profile seam.
@MainActor
final class SwiftDataUserProfileRepository: UserProfileRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchOrCreateProfile() throws -> UserProfile {
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1

        let existing: UserProfile?
        do {
            existing = try context.fetch(descriptor).first
        } catch {
            AppLogger.data.error("Failed to load UserProfile: \(error.localizedDescription, privacy: .public)")
            throw RepositoryError.loadFailed
        }
        if let existing {
            return existing
        }

        let profile = UserProfile()
        context.insert(profile)
        do {
            try context.save()
        } catch {
            AppLogger.data.error("Failed to create UserProfile: \(error.localizedDescription, privacy: .public)")
            throw RepositoryError.saveFailed
        }
        AppLogger.data.info("Created the single UserProfile")
        return profile
    }

    func save(_ profile: UserProfile) throws {
        do {
            try context.save()
        } catch {
            AppLogger.data.error("Failed to save UserProfile: \(error.localizedDescription, privacy: .public)")
            throw RepositoryError.saveFailed
        }
    }
}
