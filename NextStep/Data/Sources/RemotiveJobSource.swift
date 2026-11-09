import Foundation
import os

/// The Remotive public API source.
///
/// One `loadJobs()` call issues exactly one request with the injected `JobQuery`, decodes the daily
/// sample leniently, and returns normalized drafts. It never persists and never throttles; the
/// repository owns the `RefreshLedger`.
nonisolated struct RemotiveJobSource: JobSource {
    static let endpoint = URL(string: "https://remotive.com/api/remote-jobs")!
    static let timeoutInterval: TimeInterval = 15

    let intakeMethod: JobIntakeMethod = .remotive

    private let query: JobQuery
    private let session: URLSession

    init(query: JobQuery = JobQuery(), session: URLSession = .shared) {
        self.query = query
        self.session = session
    }

    func loadJobs() async throws -> [JobPostingDraft] {
        let request = Self.makeRequest(query: query)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw Self.map(error)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw JobSourceError.offline
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            AppLogger.data.error("Remotive returned a non-HTTP response")
            throw JobSourceError.decoding
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 429:
            throw JobSourceError.rateLimited
        default:
            throw JobSourceError.server(httpResponse.statusCode)
        }

        do {
            let payload = try JSONDecoder().decode(RemotiveJobsResponse.self, from: data)
            AppLogger.data.info(
                "Remotive sample: \(payload.jobs.count) jobs (job-count: \(payload.jobCount.map(String.init) ?? "nil", privacy: .public), total-job-count: \(payload.totalJobCount.map(String.init) ?? "nil", privacy: .public))"
            )
            return payload.drafts
        } catch {
            AppLogger.data.error(
                "Failed to decode the Remotive payload: \(error.localizedDescription, privacy: .public)"
            )
            throw JobSourceError.decoding
        }
    }

    // MARK: - Request

    static func makeRequest(query: JobQuery) -> URLRequest {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = []
        if let keyword = normalized(query.keyword) {
            queryItems.append(URLQueryItem(name: "search", value: keyword))
        }
        if let category = normalized(query.category) {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        queryItems.append(URLQueryItem(name: "limit", value: String(query.limit)))
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = timeoutInterval
        request.httpMethod = "GET"
        return request
    }

    // MARK: - Error mapping

    private static func map(_ error: URLError) -> any Error {
        switch error.code {
        case .cancelled:
            CancellationError()
        case .timedOut:
            JobSourceError.timedOut
        default:
            JobSourceError.offline
        }
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
