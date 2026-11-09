import Foundation

/// URLProtocol stub for deterministic, offline source tests.
///
/// Tests configure a response (or a failure) and inspect the recorded requests. Access is lock
/// protected because URLSession invokes the protocol on a background thread. Suites that use it
/// must be `.serialized` because the stub is process-global.
nonisolated final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    struct Stub: Sendable {
        let statusCode: Int
        let body: Data

        static func json(
            _ json: String,
            statusCode: Int = 200
        ) -> Stub {
            Stub(statusCode: statusCode, body: Data(json.utf8))
        }
    }

    enum Outcome: Sendable {
        case response(Stub)
        case failure(URLError)
    }

    private nonisolated final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var outcome: Outcome?
        private var requests: [URLRequest] = []

        func setOutcome(_ outcome: Outcome) {
            lock.lock()
            defer { lock.unlock() }
            self.outcome = outcome
        }

        func takeOutcome() -> Outcome? {
            lock.lock()
            defer { lock.unlock() }
            return outcome
        }

        func record(_ request: URLRequest) {
            lock.lock()
            defer { lock.unlock() }
            requests.append(request)
        }

        func allRequests() -> [URLRequest] {
            lock.lock()
            defer { lock.unlock() }
            return requests
        }

        func reset() {
            lock.lock()
            defer { lock.unlock() }
            outcome = nil
            requests = []
        }
    }

    private static let state = State()

    static func respond(statusCode: Int, json: String) {
        state.setOutcome(.response(.json(json, statusCode: statusCode)))
    }

    static func respond(statusCode: Int, body: Data) {
        state.setOutcome(.response(Stub(statusCode: statusCode, body: body)))
    }

    static func fail(with error: URLError) {
        state.setOutcome(.failure(error))
    }

    static func reset() {
        state.reset()
    }

    static var recordedRequests: [URLRequest] {
        state.allRequests()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.state.record(request)
        guard let outcome = Self.state.takeOutcome() else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        switch outcome {
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case .response(let stub):
            guard let url = request.url,
                  let response = HTTPURLResponse(
                      url: url,
                      statusCode: stub.statusCode,
                      httpVersion: "HTTP/1.1",
                      headerFields: ["Content-Type": "application/json"]
                  )
            else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
