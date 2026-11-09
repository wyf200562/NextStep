import Foundation
import Testing
@testable import NextStep

@Suite("MatchCardPresenter")
@MainActor
struct MatchCardPresenterTests {
    private let dictionary = SkillDictionary(skills: [
        Skill(id: "swift", name: "Swift", aliases: ["swift"], category: "语言"),
        Skill(id: "swiftui", name: "SwiftUI", aliases: ["swiftui"], category: "UI"),
        Skill(id: "uikit", name: "UIKit", aliases: ["uikit"], category: "UI"),
        Skill(id: "git", name: "Git", aliases: ["git"], category: "工具"),
        Skill(id: "combine", name: "Combine", aliases: ["combine"], category: "并发"),
        Skill(id: "swiftdata", name: "SwiftData", aliases: ["swiftdata"], category: "数据"),
    ])

    @Test func readyEligibleShowsScoreBandCountAndLimitedTags() {
        let match = MatchFixtures.result(
            score: 90,
            band: .strong,
            matchedSkills: ["swift", "swiftui", "uikit", "git"],
            missingSkills: ["combine", "swiftdata"],
            reason: "匹配 4/6 项技能；缺少 Combine、SwiftData。"
        )

        let presentation = MatchCardPresenter.eligible(
            match: match,
            availability: .ready,
            dictionary: dictionary
        )

        #expect(presentation.scoreText == "90")
        #expect(presentation.bandText == "强匹配")
        #expect(presentation.matchCountText == "匹配 4/6")
        #expect(presentation.matchedTags.map(\.name) == ["Swift", "SwiftUI", "UIKit"])
        #expect(presentation.matchedTags.map(\.kind) == [.matched, .matched, .matched])
        #expect(presentation.missingTags.map(\.name) == ["Combine", "SwiftData"])
        #expect(presentation.missingTags.map(\.kind) == [.missing, .missing])
        #expect(presentation.extraMatchedCount == 1)
        #expect(presentation.extraMissingCount == 0)
        #expect(presentation.reason == "匹配 4/6 项技能；缺少 Combine、SwiftData。")
        #expect(presentation.fallbackMessage == nil)
        #expect(presentation.isLowConfidence == false)
    }

    @Test func lowConfidenceAddsAStarAndAFlag() {
        let match = MatchFixtures.result(
            score: 70,
            band: .medium,
            matchedSkills: ["swift"],
            confidence: .low
        )

        let presentation = MatchCardPresenter.eligible(
            match: match,
            availability: .ready,
            dictionary: dictionary
        )

        #expect(presentation.scoreText == "70*")
        #expect(presentation.isLowConfidence)
    }

    @Test func extraMissingSkillsAreCountedSeparately() {
        let match = MatchFixtures.result(
            score: 60,
            band: .medium,
            matchedSkills: ["swift"],
            missingSkills: ["swiftui", "uikit", "combine", "swiftdata"]
        )

        let presentation = MatchCardPresenter.eligible(
            match: match,
            availability: .ready,
            dictionary: dictionary
        )

        #expect(presentation.missingTags.count == 2)
        #expect(presentation.extraMissingCount == 2)
        #expect(presentation.extraMatchedCount == 0)
    }

    @Test func unknownSkillIDsFallBackToTheirRawID() {
        let match = MatchFixtures.result(
            score: 50,
            band: .medium,
            matchedSkills: ["unknown-skill"]
        )

        let presentation = MatchCardPresenter.eligible(
            match: match,
            availability: .ready,
            dictionary: dictionary
        )

        #expect(presentation.matchedTags.map(\.name) == ["unknown-skill"])
    }

    @Test func profileIncompleteOmitsTheScoreAndShowsTheGateMessage() {
        let presentation = MatchCardPresenter.eligible(
            match: nil,
            availability: .profileIncomplete,
            dictionary: dictionary
        )

        #expect(presentation.scoreText == nil)
        #expect(presentation.bandText == nil)
        #expect(presentation.matchCountText == nil)
        #expect(presentation.matchedTags.isEmpty)
        #expect(presentation.missingTags.isEmpty)
        #expect(presentation.reason == nil)
        #expect(presentation.fallbackMessage == "完善画像后查看匹配")
    }

    @Test func unavailableOmitsTheScoreAndShowsTheUnavailableMessage() {
        let presentation = MatchCardPresenter.eligible(
            match: nil,
            availability: .unavailable,
            dictionary: dictionary
        )

        #expect(presentation.scoreText == nil)
        #expect(presentation.fallbackMessage == "匹配暂不可用")
    }

    @Test func ineligibleReadyShowsReasonAndSkillCount() {
        let job = MatchFixtures.job(identityKey: "manual:a", intakeMethod: .manual)
        let match = MatchFixtures.result(
            score: nil,
            band: nil,
            matchedSkills: ["swift", "git"],
            missingSkills: ["swiftui", "uikit", "combine", "swiftdata"],
            eligibility: .ineligible(reason: .notInternship)
        )

        let presentation = MatchCardPresenter.ineligible(
            job: job,
            match: match,
            eligibility: .ineligible(reason: .notInternship),
            availability: .ready
        )

        #expect(presentation.reasonText == "非实习")
        #expect(presentation.skillCountText == "技能匹配 2/6")
        #expect(presentation.sourceText == "手动导入")
    }

    @Test func ineligibleProfileIncompleteHidesTheSkillCount() {
        let job = MatchFixtures.job(identityKey: "remotive:a", intakeMethod: .remotive)

        let presentation = MatchCardPresenter.ineligible(
            job: job,
            match: nil,
            eligibility: .ineligible(reason: .locationMismatch),
            availability: .profileIncomplete
        )

        #expect(presentation.reasonText == "地点不符")
        #expect(presentation.skillCountText == nil)
        #expect(presentation.sourceText == "Remotive")
    }

    @Test func ineligibleUnavailableStillShowsStoredReason() {
        let job = MatchFixtures.job(identityKey: "remotive:a", intakeMethod: .remotive)

        let presentation = MatchCardPresenter.ineligible(
            job: job,
            match: nil,
            eligibility: .ineligible(reason: .notInternship),
            availability: .unavailable
        )

        #expect(presentation.reasonText == "非实习")
        #expect(presentation.skillCountText == nil)
    }
}
