import Foundation
import Testing
@testable import NextStep

@Suite("JDHighlighter")
struct JDHighlighterTests {
    @Test func longestAliasWinsAndRangesNeverOverlap() {
        let segments = JDHighlighter.segments(
            text: "Build with SwiftUI and Swift every day.",
            matchedAliases: ["swift"],
            missingAliases: ["swiftui"]
        )

        #expect(segments == [
            JDHighlightSegment(text: "Build with ", kind: nil),
            JDHighlightSegment(text: "SwiftUI", kind: .missing),
            JDHighlightSegment(text: " and ", kind: nil),
            JDHighlightSegment(text: "Swift", kind: .matched),
            JDHighlightSegment(text: " every day.", kind: nil),
        ])
    }

    @Test func partialWordMatchesAreNotHighlighted() {
        let segments = JDHighlighter.segments(
            text: "Swiftly working with Swift.",
            matchedAliases: ["swift"],
            missingAliases: []
        )

        #expect(segments == [
            JDHighlightSegment(text: "Swiftly working with ", kind: nil),
            JDHighlightSegment(text: "Swift", kind: .matched),
            JDHighlightSegment(text: ".", kind: nil),
        ])
    }

    @Test func chineseAliasesUseLongestSubstringMatching() {
        let segments = JDHighlighter.segments(
            text: "要求熟悉数据结构与算法基础。",
            matchedAliases: ["数据结构"],
            missingAliases: ["算法"]
        )

        #expect(segments == [
            JDHighlightSegment(text: "要求熟悉", kind: nil),
            JDHighlightSegment(text: "数据结构", kind: .matched),
            JDHighlightSegment(text: "与", kind: nil),
            JDHighlightSegment(text: "算法", kind: .missing),
            JDHighlightSegment(text: "基础。", kind: nil),
        ])
    }

    @Test func matchingIsCaseInsensitiveAndKeepsOriginalCasing() {
        let segments = JDHighlighter.segments(
            text: "SWIFT and swift",
            matchedAliases: ["Swift"],
            missingAliases: []
        )

        #expect(segments == [
            JDHighlightSegment(text: "SWIFT", kind: .matched),
            JDHighlightSegment(text: " and ", kind: nil),
            JDHighlightSegment(text: "swift", kind: .matched),
        ])
    }

    @Test func identicalAliasInBothKindsHighlightsOnceAsMatched() {
        let segments = JDHighlighter.segments(
            text: "iOS",
            matchedAliases: ["iOS"],
            missingAliases: ["IOS"]
        )

        #expect(segments == [JDHighlightSegment(text: "iOS", kind: .matched)])
    }

    @Test func emptyTextProducesNoSegments() {
        #expect(JDHighlighter.segments(text: "", matchedAliases: ["Swift"], missingAliases: []).isEmpty)
    }

    @Test func absentAliasesLeaveTheWholeTextPlain() {
        let segments = JDHighlighter.segments(
            text: "Build great products.",
            matchedAliases: ["Swift"],
            missingAliases: ["Combine"]
        )

        #expect(segments == [JDHighlightSegment(text: "Build great products.", kind: nil)])
    }

    @Test func aliasesForSkillIDsIncludeTheCanonicalNameAndAliases() {
        let dictionary = SkillDictionary(skills: [
            Skill(id: "swift", name: "Swift", aliases: ["swift"], category: "语言"),
            Skill(id: "swiftui", name: "SwiftUI", aliases: ["swiftui"], category: "UI"),
        ])

        #expect(
            JDHighlighter.aliases(for: ["swiftui", "missing"], dictionary: dictionary)
                == ["SwiftUI", "missing"]
        )
    }
}
