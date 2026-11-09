import Foundation
import SwiftData
import Testing
@testable import NextStep

@Suite("ProfileViewModel")
struct ProfileViewModelTests {
    @Test("load populates the draft from the single profile and save writes it back")
    func loadAndSaveRoundTrip() throws {
        let fixture = try Fixtures.makeRepository()
        let repository = fixture.repository
        let seeded = try repository.fetchOrCreateProfile()
        seeded.skills = ["Swift", "SwiftUI"]
        seeded.targetRoles = ["iOS 开发实习"]
        seeded.preferredLocations = ["上海"]
        seeded.timeZoneIdentifier = "Asia/Shanghai"
        seeded.availableFrom = Fixtures.date(year: 2026, month: 6, day: 1)
        seeded.availableUntil = Fixtures.date(year: 2026, month: 9, day: 1)
        seeded.graduationYear = 2027
        try repository.save(seeded)

        let viewModel = ProfileViewModel(
            repository: repository,
            lexicon: try Fixtures.lexicon()
        )

        #expect(viewModel.draft.skills == ["Swift", "SwiftUI"])
        #expect(viewModel.draft.targetRoles == ["iOS 开发实习"])
        #expect(viewModel.draft.preferredLocations == ["上海"])
        #expect(viewModel.draft.timeZoneIdentifier == "Asia/Shanghai")
        #expect(viewModel.draft.availableFrom == Fixtures.date(year: 2026, month: 6, day: 1))
        #expect(viewModel.draft.availableUntil == Fixtures.date(year: 2026, month: 9, day: 1))
        #expect(viewModel.draft.graduationYear == 2027)
        #expect(viewModel.hasUnsavedChanges == false)
        #expect(viewModel.loadErrorMessage == nil)

        viewModel.draft.skills = ["Swift", "SwiftUI", "UIKit"]
        viewModel.draft.targetRoles = ["iOS 开发实习", "移动端"]
        viewModel.draft.preferredLocations = ["上海", "Remote"]
        viewModel.draft.graduationYear = 2028
        viewModel.save()

        #expect(viewModel.saveErrorMessage == nil)
        #expect(viewModel.hasUnsavedChanges == false)

        let saved = try repository.fetchOrCreateProfile()
        #expect(saved.skills == ["Swift", "SwiftUI", "UIKit"])
        #expect(saved.targetRoles == ["iOS 开发实习", "移动端"])
        #expect(saved.preferredLocations == ["上海", "Remote"])
        #expect(saved.graduationYear == 2028)
        #expect(saved.timeZoneIdentifier == "Asia/Shanghai")
    }

    @Test("skill selection resolves canonical names case-insensitively and dedupes")
    func canonicalSkillSelectionDedupes() throws {
        let fixture = try Fixtures.makeRepository()
        let viewModel = ProfileViewModel(
            repository: fixture.repository,
            lexicon: try Fixtures.lexicon()
        )

        #expect(viewModel.addSkill(named: "swift"))
        #expect(viewModel.addSkill(named: "  SWIFT  ") == false)
        #expect(viewModel.addSkill(named: "Swift") == false)
        #expect(viewModel.addSkill(named: "SwiftUI"))
        #expect(viewModel.addSkill(named: "swiftui") == false)
        #expect(viewModel.addSkill(named: "UnknownSkill") == false)

        #expect(viewModel.draft.skills == ["Swift", "SwiftUI"])
        #expect(viewModel.selectedSkillCount == 2)
        #expect(viewModel.resolvableSkillCount == 2)
    }

    @Test("toggling a skill adds or removes its canonical name")
    func togglingSkillUpdatesTheSelection() throws {
        let fixture = try Fixtures.makeRepository()
        let lexicon = try Fixtures.lexicon()
        let viewModel = ProfileViewModel(repository: fixture.repository, lexicon: lexicon)
        let swift = try #require(lexicon.skillDictionary.skill(named: "Swift"))

        viewModel.toggleSkill(swift)
        #expect(viewModel.draft.skills == ["Swift"])
        #expect(viewModel.isSkillSelected(swift))

        viewModel.toggleSkill(swift)
        #expect(viewModel.draft.skills.isEmpty)
        #expect(viewModel.isSkillSelected(swift) == false)
    }

    @Test("loading canonicalizes stored skill names and drops unknown entries")
    func loadingCanonicalizesSkillNames() throws {
        let fixture = try Fixtures.makeRepository()
        let profile = try fixture.repository.fetchOrCreateProfile()
        profile.skills = ["swift", "Swift", "SWIFTUI", "未知技能"]
        try fixture.repository.save(profile)

        let viewModel = ProfileViewModel(
            repository: fixture.repository,
            lexicon: try Fixtures.lexicon()
        )

        #expect(viewModel.draft.skills == ["Swift", "SwiftUI"])
        #expect(viewModel.hasUnsavedChanges == false)
    }

    @Test("the skill gate hint counts resolvable skills and updates live")
    func skillGateHintBoundaries() throws {
        let fixture = try Fixtures.makeRepository()
        let viewModel = ProfileViewModel(
            repository: fixture.repository,
            lexicon: try Fixtures.lexicon()
        )

        #expect(viewModel.skillGateHint == "再选 3 个技能后才会计算匹配")

        viewModel.addSkill(named: "Swift")
        #expect(viewModel.skillGateHint == "再选 2 个技能后才会计算匹配")

        viewModel.addSkill(named: "SwiftUI")
        #expect(viewModel.skillGateHint == "再选 1 个技能后才会计算匹配")

        viewModel.addSkill(named: "UIKit")
        #expect(viewModel.skillGateHint == nil)

        viewModel.draft.skills.append("UnknownSkill")
        #expect(viewModel.resolvableSkillCount == 3)
        #expect(viewModel.skillGateHint == nil)
    }

    @Test("the target-role gate hint follows the live draft")
    func targetRoleGateHintFollowsTheDraft() throws {
        let fixture = try Fixtures.makeRepository()
        let viewModel = ProfileViewModel(
            repository: fixture.repository,
            lexicon: try Fixtures.lexicon()
        )

        #expect(viewModel.targetRoleGateHint == "填写目标方向后才会计算匹配")

        viewModel.draft.targetRoles = ["iOS 开发实习"]
        #expect(viewModel.targetRoleGateHint == nil)

        viewModel.draft.targetRoles = ["   "]
        #expect(viewModel.targetRoleGateHint == "填写目标方向后才会计算匹配")
    }

    @Test("saving a fully empty profile is allowed")
    func emptyProfileCanBeSaved() throws {
        let fixture = try Fixtures.makeRepository()
        let viewModel = ProfileViewModel(
            repository: fixture.repository,
            lexicon: try Fixtures.lexicon()
        )

        #expect(viewModel.draft.skills.isEmpty)
        #expect(viewModel.draft.targetRoles.isEmpty)
        #expect(viewModel.draft.preferredLocations.isEmpty)

        viewModel.save()

        #expect(viewModel.saveErrorMessage == nil)
        #expect(viewModel.hasUnsavedChanges == false)

        let saved = try fixture.repository.fetchOrCreateProfile()
        #expect(saved.skills.isEmpty)
        #expect(saved.targetRoles.isEmpty)
        #expect(saved.preferredLocations.isEmpty)
        #expect(saved.availableFrom == nil)
        #expect(saved.availableUntil == nil)
        #expect(saved.graduationYear == nil)
        #expect(saved.timeZoneIdentifier == TimeZone.current.identifier)
    }

    @Test("unsaved changes track edits and clear after save or discard")
    func dirtyStateTransitions() throws {
        let fixture = try Fixtures.makeRepository()
        let viewModel = ProfileViewModel(
            repository: fixture.repository,
            lexicon: try Fixtures.lexicon()
        )

        #expect(viewModel.hasUnsavedChanges == false)

        viewModel.draft.targetRoles = ["iOS 开发实习"]
        #expect(viewModel.hasUnsavedChanges)

        viewModel.discardChanges()
        #expect(viewModel.hasUnsavedChanges == false)
        #expect(viewModel.draft.targetRoles.isEmpty)

        viewModel.draft.targetRoles = ["iOS 开发实习"]
        viewModel.save()
        #expect(viewModel.hasUnsavedChanges == false)
    }

    @Test("a save failure shows the retry copy and keeps the draft dirty")
    func saveFailureShowsRetryCopyAndKeepsDirty() {
        let repository = StubUserProfileRepository()
        repository.saveError = RepositoryError.saveFailed
        let viewModel = ProfileViewModel(repository: repository, lexicon: nil)
        viewModel.draft.targetRoles = ["iOS 开发实习"]

        viewModel.save()

        #expect(viewModel.saveErrorMessage == "保存失败，请重试")
        #expect(viewModel.hasUnsavedChanges)
        #expect(repository.saveCallCount == 1)
        #expect(repository.profile.targetRoles.isEmpty)
    }

    @Test("a load failure shows the retry copy")
    func loadFailureShowsRetryCopy() {
        let repository = StubUserProfileRepository()
        repository.fetchError = RepositoryError.loadFailed

        let viewModel = ProfileViewModel(repository: repository, lexicon: nil)

        #expect(viewModel.loadErrorMessage == "加载失败，请稍后重试")
        #expect(viewModel.draft.skills.isEmpty)
    }

    @Test("without a lexicon skills are locked but other fields still save")
    func lexiconUnavailableDegradation() throws {
        let fixture = try Fixtures.makeRepository()
        let seeded = try fixture.repository.fetchOrCreateProfile()
        seeded.skills = ["Swift"]
        try fixture.repository.save(seeded)

        let viewModel = ProfileViewModel(repository: fixture.repository, lexicon: nil)

        #expect(viewModel.isSkillPickerEnabled == false)
        #expect(viewModel.skillAvailabilityMessage == "技能词典暂不可用")
        #expect(viewModel.skillGateHint == nil)
        #expect(viewModel.addSkill(named: "SwiftUI") == false)
        #expect(viewModel.draft.skills == ["Swift"])

        viewModel.draft.targetRoles = ["iOS 开发实习"]
        viewModel.draft.preferredLocations = ["上海"]
        viewModel.draft.graduationYear = 2027
        viewModel.save()

        #expect(viewModel.saveErrorMessage == nil)
        #expect(viewModel.hasUnsavedChanges == false)

        let saved = try fixture.repository.fetchOrCreateProfile()
        #expect(saved.skills == ["Swift"])
        #expect(saved.targetRoles == ["iOS 开发实习"])
        #expect(saved.preferredLocations == ["上海"])
        #expect(saved.graduationYear == 2027)
    }

    @Test("target roles and preferred locations trim, reject blanks, and dedupe")
    func tagEntryTrimsAndDedupes() throws {
        let fixture = try Fixtures.makeRepository()
        let viewModel = ProfileViewModel(repository: fixture.repository, lexicon: nil)

        viewModel.addTargetRole("  iOS 开发实习 ")
        viewModel.addTargetRole("ios 开发实习")
        viewModel.addTargetRole("   ")
        #expect(viewModel.draft.targetRoles == ["iOS 开发实习"])

        viewModel.addPreferredLocation("上海")
        viewModel.addPreferredLocation("上海")
        viewModel.addPreferredLocation("")
        #expect(viewModel.draft.preferredLocations == ["上海"])

        viewModel.removeTargetRole("iOS 开发实习")
        #expect(viewModel.draft.targetRoles.isEmpty)

        viewModel.removePreferredLocation("上海")
        #expect(viewModel.draft.preferredLocations.isEmpty)
    }

    // MARK: - Fixtures

    @MainActor
    private final class StubUserProfileRepository: UserProfileRepository {
        let profile: UserProfile
        var fetchError: (any Error)?
        var saveError: (any Error)?
        private(set) var saveCallCount = 0

        init(profile: UserProfile = UserProfile()) {
            self.profile = profile
        }

        func fetchOrCreateProfile() throws -> UserProfile {
            if let fetchError { throw fetchError }
            return profile
        }

        func save(_ profile: UserProfile) throws {
            saveCallCount += 1
            if let saveError { throw saveError }
        }
    }

    @MainActor
    private struct Fixture {
        /// Keeps the in-memory container alive for the whole test; a `ModelContext` alone does not.
        let container: ModelContainer
        let repository: SwiftDataUserProfileRepository
    }

    @MainActor
    private enum Fixtures {
        static let calendar: Calendar = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
            return calendar
        }()

        static func makeRepository() throws -> Fixture {
            let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
            return Fixture(
                container: container,
                repository: SwiftDataUserProfileRepository(context: container.mainContext)
            )
        }

        static func date(year: Int, month: Int, day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }

        static func lexicon() throws -> MatchingLexicon {
            try MatchingLexiconLoader.makeLexicon(
                skillDictionaryData: Data(skillJSON.utf8),
                roleDirectionData: Data(directionJSON.utf8),
                locationData: Data(locationJSON.utf8)
            )
        }

        static let skillJSON = """
        [
          {"id":"swift","name":"Swift","aliases":["swift"],"category":"语言"},
          {"id":"swiftui","name":"SwiftUI","aliases":["swiftui"],"category":"UI"},
          {"id":"uikit","name":"UIKit","aliases":["uikit"],"category":"UI"},
          {"id":"combine","name":"Combine","aliases":["combine"],"category":"并发"}
        ]
        """

        static let directionJSON = """
        [
          {"id":"ios","name":"iOS / Mobile","aliases":["ios","mobile"]},
          {"id":"android","name":"Android","aliases":["android","安卓"]}
        ]
        """

        static let locationJSON = """
        [
          {"id":"remote","name":"Remote","aliases":["remote","远程"]}
        ]
        """
    }
}
