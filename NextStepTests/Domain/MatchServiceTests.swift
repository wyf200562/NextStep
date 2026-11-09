import Foundation
import Testing
@testable import NextStep

@Suite("MatchService")
struct MatchServiceTests {
    @Test func returnsNilWhenFewerThanThreeSkillsResolve() throws {
        let service = try Fixtures.service(
            profile: Fixtures.profile(skills: ["Swift", "SwiftUI"])
        )

        #expect(try service.evaluate(job: Fixtures.job(title: "iOS Intern")) == nil)
    }

    @Test func returnsNilWhenEverySkillIsUnknown() throws {
        let service = try Fixtures.service(
            profile: Fixtures.profile(skills: ["Swift", "SwiftUI", "UnknownSkill"])
        )

        #expect(try service.evaluate(job: Fixtures.job(title: "iOS Intern")) == nil)
    }

    @Test func returnsNilWhenNoTargetRoleIsPresent() throws {
        let service = try Fixtures.service(
            profile: Fixtures.profile(
                skills: ["Swift", "SwiftUI", "UIKit"],
                targetRoles: ["   "]
            )
        )

        #expect(try service.evaluate(job: Fixtures.job(title: "iOS Intern")) == nil)
    }

    @Test func returnsAResultWhenTheProfileGateIsMet() throws {
        let service = try Fixtures.service(
            profile: Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        )

        let result = try #require(
            try service.evaluate(job: Fixtures.job(title: "iOS Intern", description: "SwiftUI"))
        )

        #expect(result.matchedSkills == ["swiftui"])
        #expect(result.confidence == .high)
    }

    @Test func evaluateJobsKeysResultsByIdentityKey() throws {
        let service = try Fixtures.service(
            profile: Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        )
        let jobs = [
            Fixtures.job(identityKey: "manual:a", title: "Swift Intern", description: "Swift"),
            Fixtures.job(identityKey: "remotive:9", title: "Android Intern", description: "Combine"),
        ]

        let results = try service.evaluate(jobs: jobs)

        #expect(Set(results.keys) == ["manual:a", "remotive:9"])
        #expect(results["manual:a"]?.matchedSkills == ["swift"])
        #expect(results["remotive:9"]?.matchedSkills.isEmpty == true)
    }

    @Test func evaluateJobsReadsTheProfileOncePerCall() throws {
        let repository = Fixtures.repository(
            profile: Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        )
        let service = try Fixtures.service(repository: repository)

        _ = try service.evaluate(jobs: [
            Fixtures.job(identityKey: "manual:a", title: "iOS Intern", description: "Swift"),
            Fixtures.job(identityKey: "manual:b", title: "iOS Intern", description: "SwiftUI"),
        ])

        #expect(repository.fetchCount == 1)
    }

    @Test func evaluateJobsReturnsAnEmptyDictionaryWhenTheGateIsUnmet() throws {
        let service = try Fixtures.service(
            profile: Fixtures.profile(skills: ["Swift", "SwiftUI"])
        )

        let results = try service.evaluate(jobs: [
            Fixtures.job(identityKey: "manual:a", title: "iOS Intern"),
        ])

        #expect(results.isEmpty)
    }

    @Test func eligibilityIgnoresTheProfileGateAndGroupsByJobTypeAndLocation() throws {
        let repository = Fixtures.repository(
            profile: Fixtures.profile(
                skills: ["Swift"],
                preferredLocations: ["Shanghai"],
                timeZoneIdentifier: "Asia/Shanghai"
            )
        )
        let service = try Fixtures.service(repository: repository)
        let jobs = [
            Fixtures.job(
                identityKey: "manual:full-time",
                title: "iOS Engineer",
                jobType: "full_time",
                location: "Remote"
            ),
            Fixtures.job(
                identityKey: "manual:europe",
                title: "iOS Intern",
                jobType: "internship",
                location: "Europe"
            ),
            Fixtures.job(
                identityKey: "manual:remote",
                title: "iOS Intern",
                jobType: "internship",
                location: "Remote"
            ),
        ]

        let eligibility = try service.eligibility(jobs: jobs)

        #expect(eligibility["manual:full-time"] == .ineligible(reason: .notInternship))
        #expect(eligibility["manual:europe"] == .ineligible(reason: .locationMismatch))
        #expect(eligibility["manual:remote"] == .eligible)
        #expect(repository.fetchCount == 1)
    }

    // MARK: - Fixtures

    @MainActor
    private final class StubUserProfileRepository: UserProfileRepository {
        let profile: UserProfile
        private(set) var fetchCount = 0

        init(profile: UserProfile) {
            self.profile = profile
        }

        func fetchOrCreateProfile() throws -> UserProfile {
            fetchCount += 1
            return profile
        }

        func save(_ profile: UserProfile) throws {}
    }

    @MainActor
    private enum Fixtures {
        static func repository(profile: UserProfile) -> StubUserProfileRepository {
            StubUserProfileRepository(profile: profile)
        }

        static func service(profile: UserProfile) throws -> MatchService {
            try service(repository: repository(profile: profile))
        }

        static func service(repository: StubUserProfileRepository) throws -> MatchService {
            MatchService(profileRepository: repository, lexicon: try lexicon())
        }

        static func lexicon() throws -> MatchingLexicon {
            try MatchingLexiconLoader.makeLexicon(
                skillDictionaryData: Data(skillJSON.utf8),
                roleDirectionData: Data(directionJSON.utf8),
                locationData: Data(locationJSON.utf8)
            )
        }

        static func profile(
            skills: [String],
            targetRoles: [String] = ["iOS 开发实习"],
            preferredLocations: [String] = [],
            timeZoneIdentifier: String? = nil
        ) -> UserProfile {
            UserProfile(
                skills: skills,
                targetRoles: targetRoles,
                preferredLocations: preferredLocations,
                timeZoneIdentifier: timeZoneIdentifier
            )
        }

        static func job(
            identityKey: String = "manual:test",
            title: String,
            description: String = "Build great products.",
            jobType: String? = "internship",
            location: String? = "Remote"
        ) -> JobPosting {
            JobPosting(
                identityKey: identityKey,
                title: title,
                companyName: "Acme",
                intakeMethod: .manual,
                descriptionPlainText: description,
                createdAt: Date(timeIntervalSince1970: 0),
                location: location,
                jobType: jobType,
                tags: []
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
          {"id":"remote","name":"Remote","aliases":["remote","远程"]},
          {"id":"asia","name":"Asia","aliases":["asia","亚洲"]},
          {"id":"china","name":"China","aliases":["china","中国","shanghai","上海"],"parent":"asia"},
          {"id":"europe","name":"Europe","aliases":["europe","欧洲"]}
        ]
        """
    }
}
