import Foundation
import Testing
@testable import NextStep

@Suite("TagList")
struct TagListTests {
    @Test("normalization trims surrounding whitespace and rejects blanks")
    func normalizationTrimsAndRejectsBlank() {
        #expect(TagList.normalized("  iOS 开发实习 \n") == "iOS 开发实习")
        #expect(TagList.normalized("   ") == nil)
        #expect(TagList.normalized("") == nil)
    }

    @Test("appending trims, rejects empty input, and dedupes case-insensitively")
    func appendingTrimsAndDedupes() {
        let tags = ["iOS 开发实习"]

        #expect(TagList.appending("  移动端 ", to: tags) == ["iOS 开发实习", "移动端"])
        #expect(TagList.appending("   ", to: tags) == tags)
        #expect(TagList.appending("", to: tags) == tags)
        #expect(TagList.appending("REMOTE", to: ["remote"]) == ["remote"])
    }

    @Test("removing drops the exact stored value")
    func removingDropsTheStoredValue() {
        #expect(TagList.removing("上海", from: ["上海", "Remote"]) == ["Remote"])
        #expect(TagList.removing("北京", from: ["上海"]) == ["上海"])
    }
}
