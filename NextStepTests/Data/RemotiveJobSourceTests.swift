import Foundation
import Testing
@testable import NextStep

@Suite("RemotiveJobSource", .serialized)
struct RemotiveJobSourceTests {
    init() {
        URLProtocolStub.reset()
    }

    struct HTTPErrorCase: Sendable {
        let statusCode: Int
        let expected: JobSourceError
    }

    private func makeSource(query: JobQuery = JobQuery()) -> RemotiveJobSource {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        return RemotiveJobSource(query: query, session: session)
    }

    private func expectSourceError(
        _ expected: JobSourceError,
        from source: RemotiveJobSource,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        do {
            _ = try await source.loadJobs()
            Issue.record("Expected \(expected) but loadJobs succeeded", sourceLocation: sourceLocation)
        } catch let error as JobSourceError {
            #expect(error == expected, sourceLocation: sourceLocation)
        } catch {
            Issue.record("Expected \(expected), got \(error)", sourceLocation: sourceLocation)
        }
    }

    @Test func loadsDraftsFromA200Response() async throws {
        URLProtocolStub.respond(statusCode: 200, json: """
        {
          "job-count": 2,
          "total-job-count": 2,
          "jobs": [
            {
              "id": 1,
              "title": "iOS Intern",
              "company_name": "Acme",
              "job_type": "internship",
              "description": "<p>Build with Swift.</p>"
            },
            {
              "id": 2,
              "title": "Backend Intern",
              "company_name": "Globex",
              "job_type": "internship",
              "description": ""
            }
          ]
        }
        """)
        let source = makeSource()

        let drafts = try await source.loadJobs()

        #expect(source.intakeMethod == .remotive)
        #expect(drafts.count == 2)
        #expect(drafts.map(\.identityKey) == ["remotive:1", "remotive:2"])
        #expect(drafts.first?.descriptionPlainText == "Build with Swift.")
    }

    @Test func emptySampleIsAValidSuccessfulLoad() async throws {
        URLProtocolStub.respond(statusCode: 200, json: """
        { "job-count": 0, "total-job-count": 0, "jobs": [] }
        """)
        let source = makeSource()

        let drafts = try await source.loadJobs()

        #expect(drafts.isEmpty)
    }

    @Test func requestUsesTheDefaultQueryAndFifteenSecondTimeout() async throws {
        URLProtocolStub.respond(statusCode: 200, json: #"{ "jobs": [] }"#)
        let source = makeSource()

        _ = try await source.loadJobs()

        let request = try #require(URLProtocolStub.recordedRequests.first)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        #expect(components.scheme == "https")
        #expect(components.host == "remotive.com")
        #expect(components.path == "/api/remote-jobs")
        #expect(queryItems.contains(URLQueryItem(name: "category", value: "software-dev")))
        #expect(queryItems.contains(URLQueryItem(name: "limit", value: "50")))
        #expect(queryItems.contains { $0.name == "search" } == false)
        #expect(request.timeoutInterval == 15)
    }

    @Test func requestForwardsAnExplicitQuery() async throws {
        URLProtocolStub.respond(statusCode: 200, json: #"{ "jobs": [] }"#)
        let source = makeSource(query: JobQuery(keyword: "ios", category: nil, limit: 5))

        _ = try await source.loadJobs()

        let request = try #require(URLProtocolStub.recordedRequests.first)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        #expect(queryItems.contains(URLQueryItem(name: "search", value: "ios")))
        #expect(queryItems.contains(URLQueryItem(name: "limit", value: "5")))
        #expect(queryItems.contains { $0.name == "category" } == false)
    }

    @Test(arguments: [
        HTTPErrorCase(statusCode: 429, expected: .rateLimited),
        HTTPErrorCase(statusCode: 500, expected: .server(500)),
        HTTPErrorCase(statusCode: 503, expected: .server(503)),
        HTTPErrorCase(statusCode: 404, expected: .server(404)),
    ])
    func mapsHTTPFailuresToTypedErrors(testCase: HTTPErrorCase) async {
        URLProtocolStub.respond(statusCode: testCase.statusCode, json: #"{ "jobs": [] }"#)

        await expectSourceError(testCase.expected, from: makeSource())
    }

    @Test func mapsMalformedJSONToDecoding() async {
        URLProtocolStub.respond(statusCode: 200, json: "{ not json")
        await expectSourceError(.decoding, from: makeSource())

        URLProtocolStub.respond(statusCode: 200, json: #"{ "unexpected": true }"#)
        await expectSourceError(.decoding, from: makeSource())
    }

    @Test func mapsTimeoutToTimedOut() async {
        URLProtocolStub.fail(with: URLError(.timedOut))
        await expectSourceError(.timedOut, from: makeSource())
    }

    @Test(arguments: [
        URLError.Code.notConnectedToInternet,
        .networkConnectionLost,
        .cannotFindHost,
        .cannotConnectToHost,
        .dataNotAllowed,
    ])
    func mapsNetworkUnavailabilityToOffline(code: URLError.Code) async {
        URLProtocolStub.fail(with: URLError(code))
        await expectSourceError(.offline, from: makeSource())
    }

    @Test func mapsCancellationToCancellationError() async {
        URLProtocolStub.fail(with: URLError(.cancelled))

        do {
            _ = try await makeSource().loadJobs()
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            // Expected: cancellation is handled separately and never rendered as an error.
        } catch {
            Issue.record("Expected CancellationError, got \(error)")
        }
    }
}
