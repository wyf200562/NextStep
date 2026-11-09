import Foundation
import os

/// A profile resolved against the skill dictionary and pass through the matching gate.
nonisolated struct ResolvedProfile: Sendable, Equatable {
    let skillIDs: Set<SkillID>
    let targetRoles: [String]
    let preferredLocations: [String]
    let timeZoneIdentifier: String?
}

/// Pure, deterministic matching engine.
///
/// The engine performs no I/O and holds no state. Its public entry points are main-actor isolated
/// because `UserProfile` and `JobPosting` are `@Model` types whose stored properties are isolated
/// to the main actor; the computation itself is synchronous and side-effect free.
nonisolated struct MatchingEngine: Sendable {
    // The profile gate lives here so both `MatchService` and direct callers share one rule.
    private static let minimumResolvableSkills = 3

    /// Resolves profile skills to dictionary ids and enforces the profile gate.
    ///
    /// Returns `nil` when fewer than three skills resolve or no target role is present.
    @MainActor
    func resolveProfile(_ profile: UserProfile, dictionary: SkillDictionary) -> ResolvedProfile? {
        var skillIDs: Set<SkillID> = []
        for rawName in profile.skills {
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            if let skill = dictionary.skill(named: name) {
                skillIDs.insert(skill.id)
            } else {
                AppLogger.matching.debug(
                    "Unknown profile skill '\(name, privacy: .public)' ignored"
                )
            }
        }

        let targetRoles = profile.targetRoles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let preferredLocations = profile.preferredLocations
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard skillIDs.count >= Self.minimumResolvableSkills, !targetRoles.isEmpty else {
            return nil
        }
        return ResolvedProfile(
            skillIDs: skillIDs,
            targetRoles: targetRoles,
            preferredLocations: preferredLocations,
            timeZoneIdentifier: profile.timeZoneIdentifier
        )
    }

    /// Evaluates one posting, returning `nil` when the profile gate is unmet.
    @MainActor
    func evaluate(
        profile: UserProfile,
        job: JobPosting,
        lexicon: MatchingLexicon
    ) -> MatchResult? {
        guard let resolved = resolveProfile(profile, dictionary: lexicon.skillDictionary) else {
            return nil
        }
        return evaluate(profile: resolved, job: job, lexicon: lexicon)
    }

    /// Evaluates one posting for an already-resolved profile.
    @MainActor
    func evaluate(
        profile: ResolvedProfile,
        job: JobPosting,
        lexicon: MatchingLexicon
    ) -> MatchResult {
        let title = MatchingTextNormalizer.normalize(job.title)
        let tags = MatchingTextNormalizer.normalize(job.tags.joined(separator: " "))
        let description = MatchingTextNormalizer.normalize(job.descriptionPlainText)

        let scan = scanSkills(
            title: title,
            tags: tags,
            description: description,
            dictionary: lexicon.skillDictionary
        )
        let requiredSkills = scan.requiredSkillIDs
        let matchedSkills = requiredSkills.filter { profile.skillIDs.contains($0) }
        let missingSkills = requiredSkills.filter { !profile.skillIDs.contains($0) }

        let hasDescription = !description.isEmpty
        let lowConfidence = !hasDescription || requiredSkills.isEmpty
        let baseSkillScore = requiredSkills.isEmpty
            ? 0
            : Int((60.0 * Double(matchedSkills.count) / Double(requiredSkills.count)).rounded())
        let skillScore = lowConfidence
            ? Int((Double(baseSkillScore) * 0.5).rounded())
            : baseSkillScore

        let directionScore = evaluateDirection(
            profile: profile,
            title: title,
            tags: tags,
            description: description,
            lexicon: lexicon.roleDirectionLexicon
        )
        let locationEvaluation = evaluateLocation(
            profile: profile,
            jobLocation: job.location,
            lexicon: lexicon.locationLexicon
        )
        let jobTypeEvaluation = evaluateJobType(jobType: job.jobType, title: title)

        let components = MatchComponents(
            skills: skillScore,
            direction: directionScore,
            location: locationEvaluation.component,
            jobType: jobTypeEvaluation.component
        )
        let eligibility = eligibility(jobType: jobTypeEvaluation, location: locationEvaluation)
        let isEligible: Bool
        if case .eligible = eligibility {
            isEligible = true
        } else {
            isEligible = false
        }
        let confidence: Confidence = lowConfidence ? .low : .high
        let score = isEligible ? components.total : nil
        let band = isEligible ? Self.band(for: components.total) : nil
        let reason = makeReason(
            matchedSkills: matchedSkills,
            requiredSkills: requiredSkills,
            missingSkills: missingSkills,
            dictionary: lexicon.skillDictionary,
            location: locationEvaluation,
            jobType: jobTypeEvaluation,
            eligibility: eligibility,
            confidence: confidence
        )

        return MatchResult(
            score: score,
            band: band,
            matchedSkills: matchedSkills,
            missingSkills: missingSkills,
            components: components,
            eligibility: eligibility,
            confidence: confidence,
            reason: reason,
            evidence: scan.evidence
        )
    }

    /// Gate-independent eligibility for grouping when the profile is incomplete.
    ///
    /// Only the job-type and location rules are evaluated; skill resolution and the profile gate are
    /// skipped, so a profile with too few skills still yields a meaningful grouping.
    @MainActor
    func eligibility(
        profile: UserProfile,
        job: JobPosting,
        lexicon: MatchingLexicon
    ) -> Eligibility {
        let locationProfile = ResolvedProfile(
            skillIDs: [],
            targetRoles: [],
            preferredLocations: profile.preferredLocations
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            timeZoneIdentifier: profile.timeZoneIdentifier
        )
        let location = evaluateLocation(
            profile: locationProfile,
            jobLocation: job.location,
            lexicon: lexicon.locationLexicon
        )
        let jobType = evaluateJobType(
            jobType: job.jobType,
            title: MatchingTextNormalizer.normalize(job.title)
        )
        return eligibility(jobType: jobType, location: location)
    }

    // MARK: - Skill scanning

    private struct EvidenceKey: Hashable {
        let skillID: SkillID
        let field: SkillMatchField
        let alias: String
    }

    private struct SkillScanResult {
        let requiredSkillIDs: [SkillID]
        let evidence: [SkillEvidence]
    }

    private func scanSkills(
        title: String,
        tags: String,
        description: String,
        dictionary: SkillDictionary
    ) -> SkillScanResult {
        let fields: [(SkillMatchField, String)] = [
            (.title, title),
            (.tags, tags),
            (.description, description),
        ]

        var hitSkillIDs: Set<SkillID> = []
        var evidence: [SkillEvidence] = []
        var seenEvidence: Set<EvidenceKey> = []

        for (field, text) in fields where !text.isEmpty {
            var claimedRanges: [Range<Int>] = []

            for entry in dictionary.aliasesInScanOrder {
                for range in MatchingTextNormalizer.occurrences(of: entry.alias, in: text) {
                    let offsets = Self.offsets(of: range, in: text)
                    if claimedRanges.contains(where: { $0.overlaps(offsets) }) { continue }
                    claimedRanges.append(offsets)
                    hitSkillIDs.insert(entry.skillID)

                    let key = EvidenceKey(skillID: entry.skillID, field: field, alias: entry.alias)
                    if seenEvidence.insert(key).inserted {
                        evidence.append(
                            SkillEvidence(skillID: entry.skillID, field: field, matchedAlias: entry.alias)
                        )
                    }
                }
            }
        }

        let requiredSkillIDs = dictionary.skills.map(\.id).filter { hitSkillIDs.contains($0) }
        var dictionaryOrder: [SkillID: Int] = [:]
        for (index, skill) in dictionary.skills.enumerated() {
            dictionaryOrder[skill.id] = index
        }
        let fieldOrder: [SkillMatchField: Int] = [.title: 0, .tags: 1, .description: 2]

        evidence.sort { lhs, rhs in
            let lhsSkillIndex = dictionaryOrder[lhs.skillID] ?? Int.max
            let rhsSkillIndex = dictionaryOrder[rhs.skillID] ?? Int.max
            if lhsSkillIndex != rhsSkillIndex { return lhsSkillIndex < rhsSkillIndex }

            let lhsFieldIndex = fieldOrder[lhs.field] ?? Int.max
            let rhsFieldIndex = fieldOrder[rhs.field] ?? Int.max
            if lhsFieldIndex != rhsFieldIndex { return lhsFieldIndex < rhsFieldIndex }

            if lhs.matchedAlias.count != rhs.matchedAlias.count {
                return lhs.matchedAlias.count > rhs.matchedAlias.count
            }
            return lhs.matchedAlias < rhs.matchedAlias
        }

        return SkillScanResult(requiredSkillIDs: requiredSkillIDs, evidence: evidence)
    }

    private static func offsets(of range: Range<String.Index>, in text: String) -> Range<Int> {
        let start = text.distance(from: text.startIndex, to: range.lowerBound)
        let end = text.distance(from: text.startIndex, to: range.upperBound)
        return start..<end
    }

    // MARK: - Direction

    private func evaluateDirection(
        profile: ResolvedProfile,
        title: String,
        tags: String,
        description: String,
        lexicon: RoleDirectionLexicon
    ) -> Int {
        let titleTagsText = [title, tags].filter { !$0.isEmpty }.joined(separator: " ")
        let titleTagDirections = lexicon.directionIDs(in: titleTagsText)
        let descriptionDirections = lexicon.directionIDs(in: description)

        var targetFamilies: Set<String> = []
        var fallbackRoles: [String] = []
        for targetRole in profile.targetRoles {
            let normalized = MatchingTextNormalizer.normalize(targetRole)
            let families = lexicon.directionIDs(in: normalized)
            if families.isEmpty {
                fallbackRoles.append(normalized)
            } else {
                targetFamilies.formUnion(families)
            }
        }

        let familyHitsTitleTags = !targetFamilies.isEmpty
            && !targetFamilies.isDisjoint(with: titleTagDirections)
        let familyHitsDescription = !targetFamilies.isEmpty
            && !targetFamilies.isDisjoint(with: descriptionDirections)
        let fallbackHitsTitleTags = targetFallbackMatches(fallbackRoles, in: titleTagsText)
        let fallbackHitsDescription = targetFallbackMatches(fallbackRoles, in: description)

        if familyHitsTitleTags || fallbackHitsTitleTags { return 20 }
        if familyHitsDescription || fallbackHitsDescription { return 15 }
        if !titleTagDirections.isEmpty { return 0 }
        return 10
    }

    private func targetFallbackMatches(_ roles: [String], in text: String) -> Bool {
        guard !text.isEmpty else { return false }
        for role in roles where !role.isEmpty {
            if MatchingTextNormalizer.containsAlias(role, in: text) { return true }
            for token in Self.latinTokens(in: role) where !Self.fallbackStopWords.contains(token) {
                if MatchingTextNormalizer.containsAlias(token, in: text) { return true }
            }
        }
        return false
    }

    private static let fallbackStopWords: Set<String> = [
        "intern", "interns", "internship", "internships",
        "developer", "developers", "engineer", "engineers",
        "job", "jobs", "role", "roles", "position", "positions", "team", "teams",
    ]

    private static func latinTokens(in text: String) -> [String] {
        text.split { character in
            !(character.isASCII && (character.isLetter || character.isNumber))
        }
        .map(String.init)
        .filter { $0.count >= 2 }
    }

    // MARK: - Location

    private enum LocationOutcome: Equatable {
        case remote
        case matched
        case unknown
        case mismatch(regionNames: [String])
    }

    private struct LocationEvaluation {
        let component: Int
        let outcome: LocationOutcome
    }

    private func evaluateLocation(
        profile: ResolvedProfile,
        jobLocation: String?,
        lexicon: LocationLexicon
    ) -> LocationEvaluation {
        let normalizedLocation = MatchingTextNormalizer.normalize(jobLocation ?? "")
        guard !normalizedLocation.isEmpty else {
            return LocationEvaluation(component: 5, outcome: .unknown)
        }

        let remoteID = LocationLexicon.remoteRegionID
        let allJobRegions = lexicon.regionIDs(in: normalizedLocation)
        let jobRegions = allJobRegions.subtracting([remoteID])
        if allJobRegions.contains(remoteID), jobRegions.isEmpty {
            return LocationEvaluation(component: 10, outcome: .remote)
        }

        var keywords: [String] = []
        for location in profile.preferredLocations {
            let normalized = MatchingTextNormalizer.normalize(location)
            if !normalized.isEmpty { keywords.append(normalized) }
        }
        if let timeZoneIdentifier = profile.timeZoneIdentifier {
            for component in timeZoneIdentifier.split(separator: "/") {
                let normalized = MatchingTextNormalizer.normalize(
                    String(component).replacingOccurrences(of: "_", with: " ")
                )
                if !normalized.isEmpty { keywords.append(normalized) }
            }
        }
        var seenKeywords: Set<String> = []
        keywords = keywords.filter { seenKeywords.insert($0).inserted }

        guard !keywords.isEmpty else {
            return LocationEvaluation(component: 5, outcome: .unknown)
        }

        var userRegions: Set<String> = []
        for keyword in keywords {
            userRegions.formUnion(lexicon.regionIDs(in: keyword))
        }

        let jobHasRegionRestriction = !jobRegions.isEmpty
        for keyword in keywords {
            let keywordRegions = lexicon.regionIDs(in: keyword)
            if jobHasRegionRestriction, keywordRegions.contains(remoteID) { continue }
            if MatchingTextNormalizer.containsAlias(keyword, in: normalizedLocation) {
                return LocationEvaluation(component: 10, outcome: .matched)
            }
        }

        guard !jobRegions.isEmpty else {
            return LocationEvaluation(component: 5, outcome: .unknown)
        }

        for jobRegion in jobRegions {
            for userRegion in userRegions where lexicon.related(jobRegion, userRegion) {
                return LocationEvaluation(component: 10, outcome: .matched)
            }
        }

        let names = lexicon.regions.filter { jobRegions.contains($0.id) }.map(\.name)
        return LocationEvaluation(component: 0, outcome: .mismatch(regionNames: names))
    }

    // MARK: - Job type

    private enum JobTypeOutcome: Equatable {
        case internship
        case unknown
        case nonInternship(label: String)
    }

    private struct JobTypeEvaluation {
        let component: Int
        let outcome: JobTypeOutcome
    }

    private func evaluateJobType(jobType: String?, title: String) -> JobTypeEvaluation {
        let normalizedType = MatchingTextNormalizer.normalize(jobType ?? "")
        let key = normalizedType
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        switch key {
        case "internship", "intern", "实习":
            return JobTypeEvaluation(component: 10, outcome: .internship)
        case "full_time", "fulltime", "permanent", "全职":
            return JobTypeEvaluation(component: 0, outcome: .nonInternship(label: "全职"))
        case "contract", "contractor", "合同":
            return JobTypeEvaluation(component: 0, outcome: .nonInternship(label: "合同"))
        case "freelance", "freelancer", "自由职业":
            return JobTypeEvaluation(component: 0, outcome: .nonInternship(label: "自由职业"))
        case "part_time", "parttime", "兼职":
            return JobTypeEvaluation(component: 0, outcome: .nonInternship(label: "兼职"))
        default:
            break
        }

        if titleIndicatesInternship(title) {
            return JobTypeEvaluation(component: 10, outcome: .internship)
        }
        return JobTypeEvaluation(component: 5, outcome: .unknown)
    }

    private func titleIndicatesInternship(_ normalizedTitle: String) -> Bool {
        for alias in ["intern", "interns", "internship", "internships", "实习"] {
            if MatchingTextNormalizer.containsAlias(alias, in: normalizedTitle) { return true }
        }
        return false
    }

    // MARK: - Result helpers

    private func eligibility(
        jobType: JobTypeEvaluation,
        location: LocationEvaluation
    ) -> Eligibility {
        if case .nonInternship = jobType.outcome {
            return .ineligible(reason: .notInternship)
        }
        if case .mismatch = location.outcome {
            return .ineligible(reason: .locationMismatch)
        }
        return .eligible
    }

    private static func band(for score: Int) -> MatchBand {
        if score >= 75 { return .strong }
        if score >= 50 { return .medium }
        return .low
    }

    private func makeReason(
        matchedSkills: [SkillID],
        requiredSkills: [SkillID],
        missingSkills: [SkillID],
        dictionary: SkillDictionary,
        location: LocationEvaluation,
        jobType: JobTypeEvaluation,
        eligibility: Eligibility,
        confidence: Confidence
    ) -> String {
        let skillSummary: String
        if requiredSkills.isEmpty {
            skillSummary = "未识别到技能"
        } else {
            skillSummary = "匹配 \(matchedSkills.count)/\(requiredSkills.count) 项技能"
        }

        switch eligibility {
        case .eligible:
            var parts: [String] = [skillSummary]
            if !missingSkills.isEmpty {
                let names = missingSkills.compactMap { dictionary.skill(id: $0)?.name }
                parts.append("缺少 \(names.joined(separator: "、"))")
            }
            parts.append("\(locationPhrase(location.outcome))，\(jobTypePhrase(jobType.outcome))")
            if confidence == .low { parts.append("低置信度") }
            return parts.joined(separator: "；") + "。"

        case .ineligible(let reason):
            var reasons: [String] = []
            if case .nonInternship(let label) = jobType.outcome {
                reasons.append("非实习（\(label)）")
            }
            if case .mismatch(let names) = location.outcome {
                let display = names.isEmpty ? "未知地区" : names.joined(separator: "、")
                reasons.append("地点不符（\(display)）")
            }
            if reasons.isEmpty { reasons.append(reason.displayName) }

            var parts: [String] = ["岗位不符合：\(reasons.joined(separator: "、"))", skillSummary]
            if confidence == .low { parts.append("低置信度") }
            return parts.joined(separator: "；") + "。"
        }
    }

    private func locationPhrase(_ outcome: LocationOutcome) -> String {
        switch outcome {
        case .remote: return "远程全球"
        case .matched: return "地点匹配"
        case .unknown: return "地点未知"
        case .mismatch: return "地点不符"
        }
    }

    private func jobTypePhrase(_ outcome: JobTypeOutcome) -> String {
        switch outcome {
        case .internship: return "实习岗位"
        case .unknown: return "岗位类型未知"
        case .nonInternship(let label): return "非实习（\(label)）"
        }
    }
}
