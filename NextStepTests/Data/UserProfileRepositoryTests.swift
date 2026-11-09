import Foundation
import SwiftData
import Testing
@testable import NextStep

@Suite("UserProfileRepository")
struct UserProfileRepositoryTests {
    @Test func fetchOrCreateReturnsASingleProfileWithCurrentTimeZone() throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let repository = SwiftDataUserProfileRepository(context: container.mainContext)

        let first = try repository.fetchOrCreateProfile()
        let second = try repository.fetchOrCreateProfile()

        #expect(first.id == second.id)
        #expect(first.timeZoneIdentifier == TimeZone.current.identifier)

        let profiles = try container.mainContext.fetch(FetchDescriptor<UserProfile>())
        #expect(profiles.count == 1)
    }

    @Test func savePersistsEditedSkillsAndTargetRoles() throws {
        let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let repository = SwiftDataUserProfileRepository(context: context)

        let profile = try repository.fetchOrCreateProfile()
        profile.skills = ["Swift", "SwiftUI"]
        profile.targetRoles = ["iOS 开发实习"]
        profile.graduationYear = 2027
        try repository.save(profile)

        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        let saved = try #require(profiles.first)
        #expect(saved.skills == ["Swift", "SwiftUI"])
        #expect(saved.targetRoles == ["iOS 开发实习"])
        #expect(saved.graduationYear == 2027)
    }
}
