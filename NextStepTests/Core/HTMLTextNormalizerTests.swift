import Foundation
import Testing
@testable import NextStep

@Suite("HTMLTextNormalizer")
struct HTMLTextNormalizerTests {
    @Test func stripsTagsAndDecodesCommonEntities() {
        let text = HTMLTextNormalizer.plainText(
            from: "<p>Hello&nbsp;<b>world</b> &amp; <i>friends</i></p>"
        )

        #expect(text == "Hello world & friends")
    }

    @Test func dropsScriptAndStyleBodies() {
        let text = HTMLTextNormalizer.plainText(
            from: "<style>.x{color:red}</style><p>Visible</p><script>alert('hidden')</script>"
        )

        #expect(text == "Visible")
        #expect(!text.lowercased().contains("hidden"))
    }

    @Test func preservesLessThanSignsThatDoNotStartATag() {
        #expect(HTMLTextNormalizer.plainText(from: "1 < 2 and 3 > 2") == "1 < 2 and 3 > 2")
    }

    @Test func keepsParagraphBoundariesAndCollapsesWhitespace() {
        let text = HTMLTextNormalizer.plainText(from: "<p>First   line</p>\n\n<p>Second\tline</p>")

        #expect(text == "First line\n\nSecond line")
    }

    @Test func decodesDecimalAndHexEntities() {
        #expect(HTMLTextNormalizer.plainText(from: "&#65;&#x42;") == "AB")
    }

    @Test func leavesPlainTextUnchanged() {
        let plain = "熟悉 SwiftUI，了解 Combine。"

        #expect(HTMLTextNormalizer.plainText(from: plain) == plain)
    }
}
