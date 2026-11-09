import Foundation

/// The thin matching seam used by Discover, JobDetail, and ApplicationDetail.
///
/// Reads the single `UserProfile`, enforces the profile gate (at least three dictionary-resolvable
/// skills and one non-empty target role), and delegates to the pure `MatchingEngine`. Results are
/// recomputed on every call and never stored.
@MainActor
final class MatchService: MatchProviding {
    private let profileRepository: any UserProfileRepository
    private let lexicon: MatchingLexicon
    private let engine: MatchingEngine

    init(
        profileRepository: any UserProfileRepository,
        lexicon: MatchingLexicon,
        engine: MatchingEngine = MatchingEngine()
    ) {
        self.profileRepository = profileRepository
        self.lexicon = lexicon
        self.engine = engine
    }

    func evaluate(job: JobPosting) throws -> MatchResult? {
        let profile = try profileRepository.fetchOrCreateProfile()
        guard let resolved = engine.resolveProfile(profile, dictionary: lexicon.skillDictionary) else {
            return nil
        }
        return engine.evaluate(profile: resolved, job: job, lexicon: lexicon)
    }

    func evaluate(jobs: [JobPosting]) throws -> [String: MatchResult] {
        let profile = try profileRepository.fetchOrCreateProfile()
        guard let resolved = engine.resolveProfile(profile, dictionary: lexicon.skillDictionary) else {
            return [:]
        }

        var results: [String: MatchResult] = [:]
        for job in jobs {
            results[job.identityKey] = engine.evaluate(profile: resolved, job: job, lexicon: lexicon)
        }
        return results
    }

    func eligibility(jobs: [JobPosting]) throws -> [String: Eligibility] {
        let profile = try profileRepository.fetchOrCreateProfile()

        var results: [String: Eligibility] = [:]
        for job in jobs {
            results[job.identityKey] = engine.eligibility(
                profile: profile,
                job: job,
                lexicon: lexicon
            )
        }
        return results
    }
}
