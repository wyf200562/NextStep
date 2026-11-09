import Foundation

/// The seam through which ViewModels obtain derived match explanations.
///
/// `MatchService` reads the profile, applies the profile gate (at least three resolvable skills and
/// one target role), and calls the pure `MatchingEngine`. Results are always recomputed, never stored.
@MainActor
protocol MatchProviding: AnyObject {
    /// Returns `nil` when the profile gate is unmet or matching is unavailable.
    func evaluate(job: JobPosting) throws -> MatchResult?

    /// Results keyed by `JobPosting.identityKey`; postings without a result are omitted.
    func evaluate(jobs: [JobPosting]) throws -> [String: MatchResult]

    /// Gate-independent eligibility for grouping postings when the profile is incomplete.
    ///
    /// Only the job-type and location rules are applied; resolving skills and the profile gate are
    /// skipped. Keys are `JobPosting.identityKey`.
    func eligibility(jobs: [JobPosting]) throws -> [String: Eligibility]
}
