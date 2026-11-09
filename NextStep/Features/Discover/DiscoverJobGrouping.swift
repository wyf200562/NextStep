import Foundation

/// One posting ready for the grouped Discover list, with its derived (never persisted) match data.
struct DiscoverJobItem {
    let job: JobPosting
    /// `nil` when the profile gate is unmet or matching is unavailable.
    let match: MatchResult?
    /// From `MatchResult` when present, otherwise the gate-independent fallback.
    let eligibility: Eligibility
}

/// The two Discover groups. Eligibility never mixes: ineligible postings always sort after eligible.
struct DiscoverJobGroups {
    let eligible: [DiscoverJobItem]
    let ineligible: [DiscoverJobItem]

    static let empty = DiscoverJobGroups(eligible: [], ineligible: [])
}

/// Pure grouping and ordering for the Discover list.
///
/// Ready eligible postings sort by score, matched-skill count, published date (nil last), then
/// identity key. With an incomplete profile or unavailable matching they sort by published date
/// (nil last) then identity key. Ineligible postings always sort by creation date descending then
/// identity key, and are grouped by eligibility rather than by source.
enum DiscoverJobGrouping {
    static func make(
        jobs: [JobPosting],
        matches: [String: MatchResult],
        fallbackEligibility: [String: Eligibility],
        availability: MatchAvailability,
        onlyInternships: Bool
    ) -> DiscoverJobGroups {
        let visibleJobs = onlyInternships ? jobs.filter(isInternship) : jobs

        var items: [DiscoverJobItem] = []
        items.reserveCapacity(visibleJobs.count)
        for job in visibleJobs {
            let match = matches[job.identityKey]
            let eligibility = match?.eligibility
                ?? fallbackEligibility[job.identityKey]
                ?? storedJobTypeEligibility(for: job)
            items.append(DiscoverJobItem(job: job, match: match, eligibility: eligibility))
        }

        var eligible: [DiscoverJobItem] = []
        var ineligible: [DiscoverJobItem] = []
        for item in items {
            switch item.eligibility {
            case .eligible:
                eligible.append(item)
            case .ineligible:
                ineligible.append(item)
            }
        }

        eligible.sort { eligiblePrecedes($0, $1, availability: availability) }
        ineligible.sort(by: ineligiblePrecedes)

        return DiscoverJobGroups(eligible: eligible, ineligible: ineligible)
    }

    /// Gate-independent eligibility for a posting when no match result is available.
    ///
    /// Only the job-type rule can be evaluated without the lexicon; location mismatches require a
    /// `MatchResult` (or the provider's gate-independent eligibility map).
    static func storedJobTypeEligibility(for job: JobPosting) -> Eligibility {
        let normalizedType = MatchingTextNormalizer.normalize(job.jobType ?? "")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        switch normalizedType {
        case "internship", "intern", "实习":
            return .eligible
        case "full_time", "fulltime", "permanent", "全职",
             "contract", "contractor", "合同",
             "freelance", "freelancer", "自由职业",
             "part_time", "parttime", "兼职":
            return .ineligible(reason: .notInternship)
        default:
            break
        }

        let normalizedTitle = MatchingTextNormalizer.normalize(job.title)
        for alias in ["intern", "interns", "internship", "internships", "实习"]
        where MatchingTextNormalizer.containsAlias(alias, in: normalizedTitle) {
            return .eligible
        }
        return .eligible
    }

    // MARK: - Ordering

    private static func eligiblePrecedes(
        _ lhs: DiscoverJobItem,
        _ rhs: DiscoverJobItem,
        availability: MatchAvailability
    ) -> Bool {
        if availability == .ready {
            let lhsScore = lhs.match?.score ?? Int.min
            let rhsScore = rhs.match?.score ?? Int.min
            if lhsScore != rhsScore { return lhsScore > rhsScore }

            let lhsMatched = lhs.match?.matchedSkills.count ?? 0
            let rhsMatched = rhs.match?.matchedSkills.count ?? 0
            if lhsMatched != rhsMatched { return lhsMatched > rhsMatched }
        }
        return publishedAtPrecedes(lhs.job, rhs.job)
    }

    /// Newest first; undated postings last; identity key ascending is the final deterministic tie.
    private static func publishedAtPrecedes(_ lhs: JobPosting, _ rhs: JobPosting) -> Bool {
        switch (lhs.publishedAt, rhs.publishedAt) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate > rhsDate
        case (nil, .some):
            return false
        case (.some, nil):
            return true
        default:
            return lhs.identityKey < rhs.identityKey
        }
    }

    private static func ineligiblePrecedes(_ lhs: DiscoverJobItem, _ rhs: DiscoverJobItem) -> Bool {
        if lhs.job.createdAt != rhs.job.createdAt {
            return lhs.job.createdAt > rhs.job.createdAt
        }
        return lhs.job.identityKey < rhs.job.identityKey
    }

    private static func isInternship(_ job: JobPosting) -> Bool {
        job.jobType?.lowercased() == "internship"
    }
}
