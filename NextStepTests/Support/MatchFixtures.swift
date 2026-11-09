import Foundation
@testable import NextStep

/// Deterministic constructions for match-display tests. Dates are fixed literals, never the clock.
@MainActor
enum MatchFixtures {
    static func job(
        identityKey: String,
        title: String = "iOS Intern",
        companyName: String = "Acme",
        intakeMethod: JobIntakeMethod = .remotive,
        descriptionPlainText: String = "Build with Swift.",
        createdAt: Date = Date(timeIntervalSince1970: 1_000),
        location: String? = "Remote",
        jobType: String? = "internship",
        tags: [String] = [],
        publishedAt: Date? = nil
    ) -> JobPosting {
        JobPosting(
            identityKey: identityKey,
            title: title,
            companyName: companyName,
            intakeMethod: intakeMethod,
            descriptionPlainText: descriptionPlainText,
            createdAt: createdAt,
            location: location,
            jobType: jobType,
            tags: tags,
            publishedAt: publishedAt
        )
    }

    static func result(
        score: Int? = 80,
        band: MatchBand? = .strong,
        matchedSkills: [SkillID] = [],
        missingSkills: [SkillID] = [],
        components: MatchComponents = MatchComponents(
            skills: 50,
            direction: 20,
            location: 10,
            jobType: 10
        ),
        eligibility: Eligibility = .eligible,
        confidence: Confidence = .high,
        reason: String = "匹配说明。"
    ) -> MatchResult {
        MatchResult(
            score: score,
            band: band,
            matchedSkills: matchedSkills,
            missingSkills: missingSkills,
            components: components,
            eligibility: eligibility,
            confidence: confidence,
            reason: reason,
            evidence: []
        )
    }
}
