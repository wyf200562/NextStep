import Foundation
import Testing
@testable import NextStep

@Suite("MatchingEngine skills and normalization")
struct MatchingEngineTests {
    // MARK: - Skill identification

    @Test func swiftAliasDoesNotMatchInsideSwiftUI() throws {
        let engine = MatchingEngine()
        let profile = Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        let job = Fixtures.job(
            title: "SwiftUI Intern",
            description: "Build declarative interfaces for iPhone.",
            tags: [],
            location: "Remote",
            jobType: "internship"
        )

        let result = try #require(engine.evaluate(profile: profile, job: job, lexicon: Fixtures.lexicon()))

        #expect(result.matchedSkills == ["swiftui"])
        #expect(result.missingSkills.isEmpty)
        #expect(!result.evidence.contains { $0.skillID == "swift" })
        #expect(result.evidence.contains { $0.skillID == "swiftui" && $0.field == .title })
    }

    @Test func swiftAloneStillMatchesTheSwiftSkill() throws {
        let engine = MatchingEngine()
        let profile = Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        let job = Fixtures.job(
            title: "Swift Intern",
            description: "Write iOS apps.",
            location: "Remote",
            jobType: "internship"
        )

        let result = try #require(engine.evaluate(profile: profile, job: job, lexicon: Fixtures.lexicon()))

        #expect(result.matchedSkills == ["swift"])
    }

    @Test func multiWordSwiftUIAliasWinsOverItsPrefix() throws {
        let engine = MatchingEngine()
        let profile = Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        let job = Fixtures.job(
            title: "Swift UI Engineer Intern",
            description: "Ship screens.",
            location: "Remote",
            jobType: "internship"
        )

        let result = try #require(engine.evaluate(profile: profile, job: job, lexicon: Fixtures.lexicon()))

        #expect(result.matchedSkills == ["swiftui"])
        #expect(!result.matchedSkills.contains("swift"))
    }

    @Test func synonymsAndChineseAliasesResolveToCanonicalSkills() throws {
        let engine = MatchingEngine()
        let profile = Fixtures.profile(skills: ["Objective-C", "SwiftUI", "UIKit"])
        let job = Fixtures.job(
            title: "iOS 开发实习",
            description: "熟悉 Objective-C / OC，并使用声明式UI 开发界面。",
            location: "Remote",
            jobType: "internship"
        )

        let result = try #require(engine.evaluate(profile: profile, job: job, lexicon: Fixtures.lexicon()))

        #expect(result.matchedSkills == ["swiftui", "objective-c"])
        #expect(result.missingSkills.isEmpty)
    }

    @Test func caseAndFullWidthVariantsProduceIdenticalResults() throws {
        let engine = MatchingEngine()
        let profile = Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        let plain = Fixtures.job(
            title: "swiftui intern",
            description: "Combine and UIKit experience.",
            tags: ["Combine"],
            location: "Remote",
            jobType: "internship"
        )
        let decorated = Fixtures.job(
            title: "ＳＷＩＦＴＵＩ ＩＮＴＥＲＮ",
            description: "Ｃｏｍｂｉｎｅ and UIKit experience.",
            tags: ["ＣＯＭＢＩＮＥ"],
            location: "Remote",
            jobType: "internship"
        )

        let plainResult = try #require(engine.evaluate(profile: profile, job: plain, lexicon: Fixtures.lexicon()))
        let decoratedResult = try #require(engine.evaluate(profile: profile, job: decorated, lexicon: Fixtures.lexicon()))

        #expect(plainResult == decoratedResult)
    }

    @Test func chineseJobDescriptionAggregatesInDictionaryOrder() throws {
        let engine = MatchingEngine()
        let profile = Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        let job = Fixtures.job(
            title: "iOS 开发实习生",
            description: "岗位要求：熟悉 SwiftUI 与 Combine，了解 UIKit；有 Objective-C 经验优先。",
            location: "Remote",
            jobType: "internship"
        )

        let result = try #require(engine.evaluate(profile: profile, job: job, lexicon: Fixtures.lexicon()))

        #expect(result.matchedSkills == ["swiftui", "uikit"])
        #expect(result.missingSkills == ["objective-c", "combine"])
    }

    @Test func htmlIsStrippedBeforeSkillScanningIncludingScriptBodies() throws {
        let engine = MatchingEngine()
        let profile = Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        let job = Fixtures.job(
            title: "iOS Intern",
            description: "<p>熟悉 <b>SwiftUI</b> 和 <i>Combine</i>。</p><script>var sample = \"Swift\";</script>",
            location: "Remote",
            jobType: "internship"
        )

        let result = try #require(engine.evaluate(profile: profile, job: job, lexicon: Fixtures.lexicon()))

        #expect(result.matchedSkills == ["swiftui"])
        #expect(result.missingSkills == ["combine"])
        #expect(!result.evidence.contains { $0.skillID == "swift" })
        #expect(result.evidence.allSatisfy { !$0.matchedAlias.contains("<") })
    }

    @Test func duplicateMentionsDoNotInflateTheSkillComponent() throws {
        let engine = MatchingEngine()
        let profile = Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        let once = Fixtures.job(
            title: "iOS Intern",
            description: "Swift",
            location: "Remote",
            jobType: "internship"
        )
        let repeated = Fixtures.job(
            title: "iOS Intern",
            description: "Swift Swift Swift swift; SWIFT",
            location: "Remote",
            jobType: "internship"
        )

        let onceResult = try #require(engine.evaluate(profile: profile, job: once, lexicon: Fixtures.lexicon()))
        let repeatedResult = try #require(engine.evaluate(profile: profile, job: repeated, lexicon: Fixtures.lexicon()))

        #expect(onceResult.matchedSkills == ["swift"])
        #expect(repeatedResult == onceResult)
    }

    @Test func evidenceRecordsTitleTagsAndDescription() throws {
        let engine = MatchingEngine()
        let profile = Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        let job = Fixtures.job(
            title: "SwiftUI Intern",
            description: "Combine experience is a plus.",
            tags: ["UIKit"],
            location: "Remote",
            jobType: "internship"
        )

        let result = try #require(engine.evaluate(profile: profile, job: job, lexicon: Fixtures.lexicon()))
        let evidence = Set(result.evidence)

        #expect(evidence.contains(SkillEvidence(skillID: "swiftui", field: .title, matchedAlias: "swiftui")))
        #expect(evidence.contains(SkillEvidence(skillID: "uikit", field: .tags, matchedAlias: "uikit")))
        #expect(evidence.contains(SkillEvidence(skillID: "combine", field: .description, matchedAlias: "combine")))
    }

    // MARK: - Aggregation and confidence

    @Test func fullOverlapScoresTheFullSkillComponent() throws {
        let engine = MatchingEngine()
        let profile = Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        let job = Fixtures.job(
            title: "iOS Intern",
            description: "Swift, SwiftUI and UIKit.",
            location: "Remote",
            jobType: "internship"
        )

        let result = try #require(engine.evaluate(profile: profile, job: job, lexicon: Fixtures.lexicon()))

        #expect(result.components.skills == 60)
        #expect(result.confidence == .high)
    }

    @Test func zeroOverlapStillHasHighConfidenceWhenSkillsWereIdentified() throws {
        let engine = MatchingEngine()
        let profile = Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        let job = Fixtures.job(
            title: "iOS Intern",
            description: "Combine and Objective-C experience required.",
            location: "Remote",
            jobType: "internship"
        )

        let result = try #require(engine.evaluate(profile: profile, job: job, lexicon: Fixtures.lexicon()))

        #expect(result.matchedSkills.isEmpty)
        #expect(result.missingSkills == ["objective-c", "combine"])
        #expect(result.components.skills == 0)
        #expect(result.confidence == .high)
    }

    @Test func emptyDescriptionWithTitleSkillsHalvesTheSkillComponentAndLowersConfidence() throws {
        let engine = MatchingEngine()
        let profile = Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        let job = Fixtures.job(
            title: "Swift Intern",
            description: "   ",
            tags: ["SwiftUI"],
            location: "Remote",
            jobType: "internship"
        )

        let result = try #require(engine.evaluate(profile: profile, job: job, lexicon: Fixtures.lexicon()))

        #expect(result.components.skills == 30)
        #expect(result.confidence == .low)
    }

    @Test func emptyDescriptionWithoutAnySkillHitsScoresZeroSkillsAtLowConfidence() throws {
        let engine = MatchingEngine()
        let profile = Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        let job = Fixtures.job(
            title: "Product Intern",
            description: "",
            location: "Remote",
            jobType: "internship"
        )

        let result = try #require(engine.evaluate(profile: profile, job: job, lexicon: Fixtures.lexicon()))

        #expect(result.matchedSkills.isEmpty)
        #expect(result.missingSkills.isEmpty)
        #expect(result.components.skills == 0)
        #expect(result.confidence == .low)
    }

    @Test func nonEmptyDescriptionWithoutSkillHitsScoresZeroSkillsAtLowConfidence() throws {
        let engine = MatchingEngine()
        let profile = Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        let job = Fixtures.job(
            title: "Office Assistant Intern",
            description: "Support the team with scheduling.",
            location: "Remote",
            jobType: "internship"
        )

        let result = try #require(engine.evaluate(profile: profile, job: job, lexicon: Fixtures.lexicon()))

        #expect(result.components.skills == 0)
        #expect(result.confidence == .low)
        #expect(!result.reason.isEmpty)
    }

    // MARK: - Determinism and invariants

    @Test func evaluationIsDeterministic() throws {
        let engine = MatchingEngine()
        let profile = Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        let job = Fixtures.job(
            title: "iOS Intern",
            description: "SwiftUI, Combine, UIKit and Swift.",
            tags: ["Swift", "UIKit"],
            location: "Remote",
            jobType: "internship"
        )

        let first = try #require(engine.evaluate(profile: profile, job: job, lexicon: Fixtures.lexicon()))
        let second = try #require(engine.evaluate(profile: profile, job: job, lexicon: Fixtures.lexicon()))

        #expect(first == second)
        #expect(first.matchedSkills == ["swift", "swiftui", "uikit"])
        #expect(first.missingSkills == ["combine"])
    }

    @Test func eligibleScoreIsBoundedAndEqualsTheComponentSum() throws {
        let engine = MatchingEngine()
        let profile = Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"])
        let job = Fixtures.job(
            title: "iOS Intern",
            description: "SwiftUI, UIKit, Combine, Swift.",
            location: "Remote",
            jobType: "internship"
        )

        let result = try #require(engine.evaluate(profile: profile, job: job, lexicon: Fixtures.lexicon()))
        let score = try #require(result.score)

        #expect((0...100).contains(score))
        #expect(score == result.components.total)
        #expect(result.band != nil)
        #expect(!result.reason.isEmpty)
    }

    // MARK: - Direction scoring

    @Test func targetDirectionInTitleScoresTwenty() throws {
        let result = try evaluate(
            title: "iOS Intern",
            description: "Build screens.",
            targetRoles: ["iOS 开发实习"]
        )

        #expect(result.components.direction == 20)
    }

    @Test func targetDirectionOnlyInDescriptionScoresFifteen() throws {
        let result = try evaluate(
            title: "Software Engineer Intern",
            description: "You will work on iOS applications.",
            targetRoles: ["iOS 开发实习"]
        )

        #expect(result.components.direction == 15)
    }

    @Test func anotherDirectionInTitleScoresZero() throws {
        let result = try evaluate(
            title: "Android Intern",
            description: "Build great products.",
            targetRoles: ["iOS 开发实习"]
        )

        #expect(result.components.direction == 0)
    }

    @Test func unresolvedDirectionScoresTen() throws {
        let result = try evaluate(
            title: "Software Engineer Intern",
            description: "Build great products.",
            targetRoles: ["iOS 开发实习"]
        )

        #expect(result.components.direction == 10)
    }

    @Test func targetDirectionWinsOverAnotherDirectionInTheSameTitle() throws {
        let result = try evaluate(
            title: "iOS / Android Intern",
            description: "Build mobile products.",
            targetRoles: ["iOS 开发实习"]
        )

        #expect(result.components.direction == 20)
    }

    @Test func unmappedTargetRoleFallsBackToItsLatinTokens() throws {
        let result = try evaluate(
            title: "Swift Intern",
            description: "Build great products.",
            targetRoles: ["Swift 开发实习"]
        )

        #expect(result.components.direction == 20)
    }

    @Test func unmappedTargetRoleCanMatchDescriptionOnly() throws {
        let result = try evaluate(
            title: "Software Engineer Intern",
            description: "Write Swift every day.",
            targetRoles: ["Swift 开发实习"]
        )

        #expect(result.components.direction == 15)
    }

    // MARK: - Location scoring

    @Test func remoteAndWorldwidePostingsScoreTheFullLocationComponent() throws {
        let remote = try evaluate(location: "Remote")
        let worldwide = try evaluate(location: "Worldwide")

        #expect(remote.components.location == 10)
        #expect(worldwide.components.location == 10)
    }

    @Test func matchingRegionScoresTen() throws {
        let direct = try evaluate(locations: ["China"], timeZoneIdentifier: nil, location: "China")
        let throughTimeZoneAncestor = try evaluate(
            locations: [],
            timeZoneIdentifier: "Asia/Shanghai",
            location: "China"
        )
        let throughEuropeParent = try evaluate(
            locations: ["Europe"],
            timeZoneIdentifier: nil,
            location: "UK"
        )

        #expect(direct.components.location == 10)
        #expect(throughTimeZoneAncestor.components.location == 10)
        #expect(throughEuropeParent.components.location == 10)
    }

    @Test func unknownLocationScoresFive() throws {
        let unrecognized = try evaluate(locations: [], timeZoneIdentifier: nil, location: "Somewhere")
        let missing = try evaluate(locations: [], timeZoneIdentifier: nil, location: nil)
        let noUserLocation = try evaluate(locations: [], timeZoneIdentifier: nil, location: "US")

        #expect(unrecognized.components.location == 5)
        #expect(missing.components.location == 5)
        #expect(noUserLocation.components.location == 5)
        #expect(noUserLocation.eligibility == .eligible)
    }

    @Test func explicitlyIncompatibleLocationMakesThePostingIneligible() throws {
        let result = try evaluate(locations: ["Europe"], timeZoneIdentifier: nil, location: "US")

        #expect(result.components.location == 0)
        #expect(result.eligibility == .ineligible(reason: .locationMismatch))
        #expect(result.score == nil)
        #expect(result.band == nil)
    }

    @Test func remotePostingRestrictedToAnotherRegionIsStillIneligible() throws {
        let result = try evaluate(locations: ["Europe"], timeZoneIdentifier: nil, location: "Remote (US)")

        #expect(result.components.location == 0)
        #expect(result.eligibility == .ineligible(reason: .locationMismatch))
    }

    @Test func remotePostingWithoutRegionRestrictionNeverPenalizesLocation() throws {
        let result = try evaluate(locations: ["Europe"], timeZoneIdentifier: nil, location: "Remote")

        #expect(result.components.location == 10)
        #expect(result.eligibility == .eligible)
    }

    // MARK: - Job type scoring

    @Test func explicitInternshipScoresTen() throws {
        let result = try evaluate(jobType: "internship")

        #expect(result.components.jobType == 10)
    }

    @Test func missingJobTypeInfersInternshipFromTheTitle() throws {
        let english = try evaluate(title: "iOS Intern", jobType: nil)
        let chinese = try evaluate(title: "iOS 开发实习生", jobType: nil)

        #expect(english.components.jobType == 10)
        #expect(chinese.components.jobType == 10)
    }

    @Test func unknownJobTypeScoresFiveWithoutBecomingIneligible() throws {
        let missing = try evaluate(title: "iOS Engineer", jobType: nil)
        let unrecognized = try evaluate(title: "iOS Engineer", jobType: "other")

        #expect(missing.components.jobType == 5)
        #expect(missing.eligibility == .eligible)
        #expect(unrecognized.components.jobType == 5)
        #expect(unrecognized.eligibility == .eligible)
    }

    @Test(
        arguments: [
            "full_time", "full-time", "full time", "contract", "contractor",
            "freelance", "part_time", "part-time", "part time",
        ]
    )
    func explicitNonInternshipJobTypesAreIneligible(_ jobType: String) throws {
        let result = try evaluate(jobType: jobType)

        #expect(result.components.jobType == 0)
        #expect(result.eligibility == .ineligible(reason: .notInternship))
        #expect(result.score == nil)
        #expect(result.band == nil)
    }

    @Test func explicitNonInternshipTypeOverridesInternInTheTitle() throws {
        let result = try evaluate(title: "iOS Intern", jobType: "full_time")

        #expect(result.components.jobType == 0)
        #expect(result.eligibility == .ineligible(reason: .notInternship))
    }

    @Test func internationalInTheTitleDoesNotInferInternship() throws {
        let result = try evaluate(title: "International iOS Engineer", jobType: nil)

        #expect(result.components.jobType == 5)
        #expect(result.eligibility == .eligible)
    }

    // MARK: - Bands, ineligible totals, and reasons

    @Test func ineligiblePostingsKeepComponentsButDropScoreAndBand() throws {
        let result = try evaluate(
            title: "iOS Intern",
            description: "Swift",
            locations: ["Europe"],
            timeZoneIdentifier: nil,
            location: "US",
            jobType: "full_time"
        )

        #expect(result.score == nil)
        #expect(result.band == nil)
        #expect(result.components.skills == 60)
        #expect(result.components.direction == 20)
        #expect(result.components.location == 0)
        #expect(result.components.jobType == 0)
        #expect(result.reason.contains("非实习"))
        #expect(result.reason.contains("地点不符"))
    }

    @Test func bandThresholdsFollowStrongMediumAndLow() throws {
        let strong = try evaluate(
            title: "iOS Intern",
            description: "Swift, SwiftUI and UIKit.",
            jobType: "internship"
        )
        let medium = try evaluate(
            title: "iOS Intern",
            description: "SwiftUI and Combine.",
            jobType: "internship"
        )
        let low = try evaluate(
            title: "iOS Intern",
            description: "Combine.",
            jobType: "internship"
        )

        #expect(strong.score == 100)
        #expect(strong.band == .strong)
        #expect(medium.score == 70)
        #expect(medium.band == .medium)
        #expect(low.score == 40)
        #expect(low.band == .low)
    }

    @Test func eligibleReasonFollowsTheTemplate() throws {
        let result = try evaluate(
            title: "iOS Intern",
            description: "SwiftUI and Combine.",
            location: "Remote",
            jobType: "internship"
        )

        #expect(result.reason.contains("匹配 1/2 项技能"))
        #expect(result.reason.contains("缺少 Combine"))
        #expect(result.reason.contains("远程全球"))
        #expect(result.reason.contains("实习岗位"))
        #expect(result.reason.hasSuffix("。"))
    }

    @Test func lowConfidenceIsMentionedInTheReason() throws {
        let result = try evaluate(
            title: "Swift Intern",
            description: "",
            jobType: "internship"
        )

        #expect(result.confidence == .low)
        #expect(result.reason.contains("低置信度"))
    }

    // MARK: - Profile gate

    @Test func profileGateRequiresThreeResolvableSkillsAndOneNonEmptyTargetRole() throws {
        let engine = MatchingEngine()
        let lexicon = try Fixtures.lexicon()
        let job = Fixtures.job(title: "iOS Intern", description: "SwiftUI", location: "Remote", jobType: "internship")

        #expect(engine.evaluate(profile: Fixtures.profile(skills: ["Swift", "SwiftUI"]), job: job, lexicon: lexicon) == nil)
        #expect(
            engine.evaluate(
                profile: Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"], targetRoles: []),
                job: job,
                lexicon: lexicon
            ) == nil
        )
        #expect(
            engine.evaluate(
                profile: Fixtures.profile(skills: ["Swift", "SwiftUI", "UnknownSkill"]),
                job: job,
                lexicon: lexicon
            ) == nil
        )
        #expect(
            engine.evaluate(
                profile: Fixtures.profile(skills: ["Swift", "swift", "SWIFT"]),
                job: job,
                lexicon: lexicon
            ) == nil
        )
        #expect(
            engine.evaluate(
                profile: Fixtures.profile(skills: ["Swift", "SwiftUI", "UIKit"], targetRoles: ["  iOS 开发实习  "]),
                job: job,
                lexicon: lexicon
            ) != nil
        )
    }

    @Test func fullBundledDictionaryProducesBoundedDeterministicResults() throws {
        let lexicon = try MatchingLexiconLoader(bundle: .main).load()
        let engine = MatchingEngine()
        let profile = UserProfile(
            skills: ["Swift", "SwiftUI", "UIKit", "Combine", "Git", "Objective-C"],
            targetRoles: ["iOS 开发实习"],
            preferredLocations: ["China"],
            timeZoneIdentifier: "Asia/Shanghai"
        )
        let job = JobPosting(
            identityKey: "manual:full-dictionary",
            title: "iOS 开发实习生",
            companyName: "Acme",
            intakeMethod: .manual,
            descriptionPlainText: "<p>要求熟悉 SwiftUI、UIKit 与 Combine，了解 Core Data；有 Objective-C 经验优先。</p>",
            createdAt: Date(timeIntervalSince1970: 0),
            location: "Remote",
            jobType: "internship",
            tags: ["Swift", "iOS"]
        )

        let first = try #require(engine.evaluate(profile: profile, job: job, lexicon: lexicon))
        let second = try #require(engine.evaluate(profile: profile, job: job, lexicon: lexicon))
        let score = try #require(first.score)

        #expect(first == second)
        #expect((0...100).contains(score))
        #expect(score == first.components.total)
        #expect(first.components.direction == 20)
        #expect(first.components.location == 10)
        #expect(first.components.jobType == 10)
        #expect(Set(first.matchedSkills).isSuperset(of: ["swift", "swiftui", "uikit", "combine"]))
        #expect(first.missingSkills.contains("core-data"))

        let dictionaryIDs = lexicon.skillDictionary.skills.map(\.id)
        let matchedIndexes = first.matchedSkills.compactMap { dictionaryIDs.firstIndex(of: $0) }
        #expect(matchedIndexes == matchedIndexes.sorted())
        #expect(
            first.matchedSkills.count + first.missingSkills.count
                == Set(first.matchedSkills + first.missingSkills).count
        )
    }

    // MARK: - Fixtures

    private func evaluate(
        title: String = "iOS Intern",
        description: String = "Swift",
        tags: [String] = [],
        locations: [String] = [],
        timeZoneIdentifier: String? = "Asia/Shanghai",
        targetRoles: [String] = ["iOS 开发实习"],
        location: String? = "Remote",
        jobType: String? = "internship"
    ) throws -> MatchResult {
        let engine = MatchingEngine()
        let profile = Fixtures.profile(
            skills: ["Swift", "SwiftUI", "UIKit"],
            targetRoles: targetRoles,
            locations: locations,
            timeZoneIdentifier: timeZoneIdentifier
        )
        let job = Fixtures.job(
            title: title,
            description: description,
            tags: tags,
            location: location,
            jobType: jobType
        )
        return try #require(engine.evaluate(profile: profile, job: job, lexicon: Fixtures.lexicon()))
    }

    private enum Fixtures {
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
            locations: [String] = [],
            timeZoneIdentifier: String? = "Asia/Shanghai"
        ) -> UserProfile {
            UserProfile(
                skills: skills,
                targetRoles: targetRoles,
                preferredLocations: locations,
                timeZoneIdentifier: timeZoneIdentifier
            )
        }

        static func job(
            title: String,
            description: String,
            tags: [String] = [],
            location: String? = "Remote",
            jobType: String? = "internship",
            identityKey: String = "manual:test"
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
                tags: tags
            )
        }

        static let skillJSON = """
        [
          {"id":"swift","name":"Swift","aliases":["swift","swift语言"],"category":"语言"},
          {"id":"swiftui","name":"SwiftUI","aliases":["swiftui","swift ui","声明式ui"],"category":"UI"},
          {"id":"uikit","name":"UIKit","aliases":["uikit","ui kit"],"category":"UI"},
          {"id":"objective-c","name":"Objective-C","aliases":["objective-c","objective c","objc","oc"],"category":"语言"},
          {"id":"combine","name":"Combine","aliases":["combine","响应式编程"],"category":"并发"}
        ]
        """

        static let directionJSON = """
        [
          {"id":"ios","name":"iOS / Mobile","aliases":["ios","mobile","移动端","客户端"]},
          {"id":"android","name":"Android","aliases":["android","安卓"]},
          {"id":"backend","name":"Backend","aliases":["backend","后端"]},
          {"id":"data","name":"Data","aliases":["data","机器学习"]},
          {"id":"product","name":"Product","aliases":["product","产品"]},
          {"id":"design","name":"Design","aliases":["design","设计"]}
        ]
        """

        static let locationJSON = """
        [
          {"id":"remote","name":"Remote","aliases":["remote","worldwide","anywhere","远程"]},
          {"id":"asia","name":"Asia","aliases":["asia","亚洲"]},
          {"id":"china","name":"China","aliases":["china","中国"],"parent":"asia"},
          {"id":"europe","name":"Europe","aliases":["europe","欧洲"]},
          {"id":"north-america","name":"North America","aliases":["north america","america","北美"]},
          {"id":"us","name":"US","aliases":["us","usa","united states","美国"],"parent":"north-america"},
          {"id":"canada","name":"Canada","aliases":["canada","加拿大"],"parent":"north-america"},
          {"id":"uk","name":"UK","aliases":["uk","united kingdom","英国"],"parent":"europe"}
        ]
        """
    }
}
