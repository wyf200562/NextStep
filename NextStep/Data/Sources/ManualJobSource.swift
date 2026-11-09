import Foundation

/// Turns the raw "paste a JD" form input into one normalized `JobPostingDraft`.
///
/// Manual sources own normalization (trimming, tag cleanup, internship inference); they never
/// persist. Validation failures surface as `JobSourceError.invalidInput`.
nonisolated struct ManualJobSource: JobSource {
    let intakeMethod: JobIntakeMethod = .manual

    private let input: ManualJobInput
    private let id: UUID

    init(input: ManualJobInput, id: UUID = UUID()) {
        self.input = input
        self.id = id
    }

    func loadJobs() async throws -> [JobPostingDraft] {
        let title = Self.trimmed(input.title)
        let companyName = Self.trimmed(input.companyName)
        let descriptionPlainText = Self.trimmed(input.descriptionPlainText)

        guard !title.isEmpty, !companyName.isEmpty, !descriptionPlainText.isEmpty else {
            throw JobSourceError.invalidInput
        }
        if let jobURL = input.jobURL, !WebURL.isValid(jobURL) {
            throw JobSourceError.invalidInput
        }

        let draft = JobPostingDraft(
            identityKey: JobIdentityKey.manual(id: id),
            intakeMethod: .manual,
            title: title,
            companyName: companyName,
            descriptionPlainText: descriptionPlainText,
            jobURL: input.jobURL,
            location: Self.trimmedOptional(input.location),
            jobType: Self.resolvedJobType(input.jobType, title: title),
            tags: Self.normalizedTags(input.tags)
        )
        return [draft]
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func trimmedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = trimmed(value)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// An explicit type wins; otherwise an intern/实习 title is saved as an internship.
    ///
    /// Title matching reuses `MatchingTextNormalizer`'s alias boundaries, so "Internal Tools" and
    /// "International" never infer an internship.
    private static func resolvedJobType(_ value: String?, title: String) -> String? {
        if let explicit = trimmedOptional(value) {
            return explicit.lowercased()
        }
        let normalizedTitle = MatchingTextNormalizer.normalize(title)
        if MatchingTextNormalizer.indicatesInternshipInTitle(normalizedTitle) {
            return "internship"
        }
        return nil
    }

    private static func normalizedTags(_ tags: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for tag in tags {
            let trimmed = trimmed(tag)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }
}
