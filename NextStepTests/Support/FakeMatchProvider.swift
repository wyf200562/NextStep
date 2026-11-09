import Foundation
@testable import NextStep

/// Test double for the matching seam. Results and eligibility are keyed by `identityKey`, and every
/// call is recorded so tests can assert evaluation happens on demand.
@MainActor
final class FakeMatchProvider: MatchProviding {
    var results: [String: MatchResult] = [:]
    var fallbackEligibility: [String: Eligibility] = [:]
    var evaluateError: (any Error)?
    var eligibilityError: (any Error)?

    private(set) var evaluateJobCalls: [JobPosting] = []
    private(set) var evaluateJobsCalls: [[JobPosting]] = []
    private(set) var eligibilityCalls: [[JobPosting]] = []

    func evaluate(job: JobPosting) throws -> MatchResult? {
        evaluateJobCalls.append(job)
        if let evaluateError { throw evaluateError }
        return results[job.identityKey]
    }

    func evaluate(jobs: [JobPosting]) throws -> [String: MatchResult] {
        evaluateJobsCalls.append(jobs)
        if let evaluateError { throw evaluateError }
        let keys = Set(jobs.map(\.identityKey))
        return results.filter { keys.contains($0.key) }
    }

    func eligibility(jobs: [JobPosting]) throws -> [String: Eligibility] {
        eligibilityCalls.append(jobs)
        if let eligibilityError { throw eligibilityError }
        let keys = Set(jobs.map(\.identityKey))
        return fallbackEligibility.filter { keys.contains($0.key) }
    }
}
