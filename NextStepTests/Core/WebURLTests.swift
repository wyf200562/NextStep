import Foundation
import Testing
@testable import NextStep

@Suite("WebURL")
struct WebURLTests {
    @Test(arguments: [
        "https://example.com/jobs/1",
        "http://example.com",
        "HTTPS://Example.com/jobs/1",
        "  https://example.com/jobs/1  ",
    ])
    func acceptsAbsoluteHTTPURLsWithAHost(raw: String) {
        #expect(WebURL.parse(raw) != nil)
    }

    @Test(arguments: [
        "example.com/jobs/1",
        "ftp://example.com/job",
        "not-a-url",
        "https://",
        "mailto:jobs@example.com",
        "   ",
        "",
    ])
    func rejectsNonWebAndBlankInputs(raw: String) {
        #expect(WebURL.parse(raw) == nil)
    }

    @Test func nilInputIsRejected() {
        #expect(WebURL.parse(nil) == nil)
    }

    @Test func validatesAlreadyParsedURLs() throws {
        let secure = try #require(URL(string: "https://example.com/jobs/1"))
        let plain = try #require(URL(string: "http://example.com"))
        let insecureScheme = try #require(URL(string: "ftp://example.com/job"))

        #expect(WebURL.isValid(secure))
        #expect(WebURL.isValid(plain))
        #expect(WebURL.isValid(insecureScheme) == false)
        #expect(URL(string: "https://").map(WebURL.isValid) == false)
    }
}
