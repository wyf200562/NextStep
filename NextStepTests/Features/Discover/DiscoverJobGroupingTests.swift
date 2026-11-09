import Foundation
import Testing
@testable import NextStep

@Suite("DiscoverJobGrouping")
@MainActor
struct DiscoverJobGroupingTests {
    private func makeGroups(
        jobs: [JobPosting],
        matches: [String: MatchResult] = [:],
        fallbackEligibility: [String: Eligibility] = [:],
        availability: MatchAvailability = .ready,
        onlyInternships: Bool = false
    ) -> DiscoverJobGroups {
        DiscoverJobGrouping.make(
            jobs: jobs,
            matches: matches,
            fallbackEligibility: fallbackEligibility,
            availability: availability,
            onlyInternships: onlyInternships
        )
    }

    private func matches(_ pairs: [(JobPosting, MatchResult)]) -> [String: MatchResult] {
        Dictionary(uniqueKeysWithValues: pairs.map { ($0.identityKey, $1) })
    }

    @Test func readyEligibleSortsByScoreDescending() {
        let low = MatchFixtures.job(identityKey: "a")
        let high = MatchFixtures.job(identityKey: "b")
        let middle = MatchFixtures.job(identityKey: "c")

        let groups = makeGroups(
            jobs: [low, high, middle],
            matches: matches([
                (low, MatchFixtures.result(score: 70, band: .medium)),
                (high, MatchFixtures.result(score: 90, band: .strong)),
                (middle, MatchFixtures.result(score: 80, band: .strong)),
            ])
        )

        #expect(groups.eligible.map(\.job.identityKey) == ["b", "c", "a"])
    }

    @Test func readyEligibleTiesBreakByMatchedSkillCount() {
        let fewer = MatchFixtures.job(identityKey: "a")
        let more = MatchFixtures.job(identityKey: "b")

        let groups = makeGroups(
            jobs: [fewer, more],
            matches: matches([
                (fewer, MatchFixtures.result(score: 80, matchedSkills: ["swift"])),
                (more, MatchFixtures.result(
                    score: 80,
                    matchedSkills: ["swift", "swiftui", "uikit"]
                )),
            ])
        )

        #expect(groups.eligible.map(\.job.identityKey) == ["b", "a"])
    }

    @Test func readyEligibleTiesBreakByPublishedAtDescendingWithNilLast() {
        let older = MatchFixtures.job(
            identityKey: "a",
            publishedAt: Date(timeIntervalSince1970: 100)
        )
        let newer = MatchFixtures.job(
            identityKey: "b",
            publishedAt: Date(timeIntervalSince1970: 200)
        )
        let undated = MatchFixtures.job(identityKey: "c", publishedAt: nil)

        let groups = makeGroups(
            jobs: [undated, older, newer],
            matches: matches([
                (undated, MatchFixtures.result(score: 80)),
                (older, MatchFixtures.result(score: 80)),
                (newer, MatchFixtures.result(score: 80)),
            ])
        )

        #expect(groups.eligible.map(\.job.identityKey) == ["b", "a", "c"])
    }

    @Test func readyEligibleFinalTieBreaksByIdentityKeyAscending() {
        let beta = MatchFixtures.job(identityKey: "beta")
        let alpha = MatchFixtures.job(identityKey: "alpha")

        let groups = makeGroups(
            jobs: [beta, alpha],
            matches: matches([
                (beta, MatchFixtures.result(score: 80)),
                (alpha, MatchFixtures.result(score: 80)),
            ])
        )

        #expect(groups.eligible.map(\.job.identityKey) == ["alpha", "beta"])
    }

    @Test func ineligibleSortsByCreatedAtDescendingThenIdentityKey() {
        let old = MatchFixtures.job(
            identityKey: "z",
            createdAt: Date(timeIntervalSince1970: 100),
            jobType: "full_time"
        )
        let newBeta = MatchFixtures.job(
            identityKey: "beta",
            createdAt: Date(timeIntervalSince1970: 200),
            jobType: "full_time"
        )
        let newAlpha = MatchFixtures.job(
            identityKey: "alpha",
            createdAt: Date(timeIntervalSince1970: 200),
            jobType: "full_time"
        )

        let groups = makeGroups(
            jobs: [old, newBeta, newAlpha],
            matches: matches([
                (old, MatchFixtures.result(
                    score: nil,
                    band: nil,
                    eligibility: .ineligible(reason: .notInternship)
                )),
                (newBeta, MatchFixtures.result(
                    score: nil,
                    band: nil,
                    eligibility: .ineligible(reason: .notInternship)
                )),
                (newAlpha, MatchFixtures.result(
                    score: nil,
                    band: nil,
                    eligibility: .ineligible(reason: .notInternship)
                )),
            ])
        )

        #expect(groups.ineligible.map(\.job.identityKey) == ["alpha", "beta", "z"])
    }

    @Test func eligibilityNeverMixesGroupsAndSourceDoesNotMatter() {
        let remotiveEligible = MatchFixtures.job(identityKey: "remotive:a", intakeMethod: .remotive)
        let manualIneligible = MatchFixtures.job(
            identityKey: "manual:b",
            intakeMethod: .manual,
            jobType: "full_time"
        )
        let manualEligible = MatchFixtures.job(identityKey: "manual:c", intakeMethod: .manual)
        let remotiveIneligible = MatchFixtures.job(
            identityKey: "remotive:d",
            intakeMethod: .remotive,
            jobType: "contract"
        )

        let groups = makeGroups(
            jobs: [remotiveEligible, manualIneligible, manualEligible, remotiveIneligible],
            matches: matches([
                (remotiveEligible, MatchFixtures.result(score: 90)),
                (manualEligible, MatchFixtures.result(score: 60, band: .medium)),
                (manualIneligible, MatchFixtures.result(
                    score: nil,
                    band: nil,
                    eligibility: .ineligible(reason: .notInternship)
                )),
                (remotiveIneligible, MatchFixtures.result(
                    score: nil,
                    band: nil,
                    eligibility: .ineligible(reason: .notInternship)
                )),
            ])
        )

        #expect(groups.eligible.map(\.job.identityKey) == ["remotive:a", "manual:c"])
        #expect(Set(groups.ineligible.map(\.job.identityKey)) == ["manual:b", "remotive:d"])
    }

    @Test func profileIncompleteSortsEligibleByPublishedAtAndUsesFallbackEligibility() {
        let newer = MatchFixtures.job(
            identityKey: "a",
            intakeMethod: .manual,
            publishedAt: Date(timeIntervalSince1970: 200)
        )
        let older = MatchFixtures.job(
            identityKey: "b",
            publishedAt: Date(timeIntervalSince1970: 100)
        )
        let undated = MatchFixtures.job(identityKey: "c", publishedAt: nil)
        let locationMismatch = MatchFixtures.job(
            identityKey: "d",
            createdAt: Date(timeIntervalSince1970: 300)
        )

        let groups = makeGroups(
            jobs: [newer, older, undated, locationMismatch],
            fallbackEligibility: [
                "a": .eligible,
                "b": .eligible,
                "c": .eligible,
                "d": .ineligible(reason: .locationMismatch),
            ],
            availability: .profileIncomplete
        )

        #expect(groups.eligible.map(\.job.identityKey) == ["a", "b", "c"])
        #expect(groups.ineligible.map(\.job.identityKey) == ["d"])
        #expect(groups.ineligible.first?.eligibility == .ineligible(reason: .locationMismatch))
        #expect(groups.eligible.allSatisfy { $0.match == nil })
    }

    @Test func unavailableFallsBackToStoredJobTypeAndTitleInference() {
        let internship = MatchFixtures.job(identityKey: "intern", jobType: "internship")
        let fullTime = MatchFixtures.job(
            identityKey: "full",
            title: "iOS Engineer",
            jobType: "full_time"
        )
        let inferred = MatchFixtures.job(
            identityKey: "inferred",
            title: "iOS 开发实习生",
            jobType: nil
        )
        let unknown = MatchFixtures.job(
            identityKey: "unknown",
            title: "iOS Engineer",
            jobType: nil
        )

        let groups = makeGroups(
            jobs: [internship, fullTime, inferred, unknown],
            availability: .unavailable
        )

        #expect(Set(groups.eligible.map(\.job.identityKey)) == ["intern", "inferred", "unknown"])
        #expect(groups.ineligible.map(\.job.identityKey) == ["full"])
        #expect(groups.ineligible.first?.eligibility == .ineligible(reason: .notInternship))
    }

    @Test func onlyInternshipsFiltersBothGroupsWithoutReordering() {
        let bestFullTime = MatchFixtures.job(
            identityKey: "full:best",
            jobType: "full_time"
        )
        let internHigh = MatchFixtures.job(identityKey: "intern:high")
        let internLow = MatchFixtures.job(identityKey: "intern:low")
        let fullTimeIneligible = MatchFixtures.job(
            identityKey: "full:blocked",
            title: "iOS Engineer",
            jobType: "full_time"
        )
        let internIneligible = MatchFixtures.job(
            identityKey: "intern:blocked",
            jobType: "internship"
        )

        let groups = makeGroups(
            jobs: [
                bestFullTime,
                internHigh,
                internLow,
                fullTimeIneligible,
                internIneligible,
            ],
            matches: [
                "full:best": MatchFixtures.result(score: 99),
                "intern:high": MatchFixtures.result(score: 80),
                "intern:low": MatchFixtures.result(score: 60, band: .medium),
                "full:blocked": MatchFixtures.result(
                    score: nil,
                    band: nil,
                    eligibility: .ineligible(reason: .notInternship)
                ),
                "intern:blocked": MatchFixtures.result(
                    score: nil,
                    band: nil,
                    eligibility: .ineligible(reason: .locationMismatch)
                ),
            ],
            onlyInternships: true
        )

        #expect(groups.eligible.map(\.job.identityKey) == ["intern:high", "intern:low"])
        #expect(groups.ineligible.map(\.job.identityKey) == ["intern:blocked"])
    }
}
