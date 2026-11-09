import Foundation
import os

/// The top-level Remotive `/api/remote-jobs` payload.
///
/// The public API currently exposes one small daily sample. `job-count`, `total-job-count`, and the
/// notices are tolerated but never drive the `JobSource` / `JobRepository` protocol.
nonisolated struct RemotiveJobsResponse: Decodable, Sendable {
    let jobCount: Int?
    let totalJobCount: Int?
    let jobs: [RemotiveJobDTO]

    enum CodingKeys: String, CodingKey {
        case jobs
        case jobCount = "job-count"
        case totalJobCount = "total-job-count"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jobs = try container.decode([RemotiveJobDTO].self, forKey: .jobs)
        // Metadata is diagnostic only; a type change must not fail the whole sample.
        jobCount = (try? container.decodeIfPresent(Int.self, forKey: .jobCount)) ?? nil
        totalJobCount = (try? container.decodeIfPresent(Int.self, forKey: .totalJobCount)) ?? nil
    }

    /// One draft per usable entry, in response order. Unusable entries are skipped, never fatal.
    var drafts: [JobPostingDraft] {
        jobs.compactMap(\.draft)
    }
}

/// One Remotive job entry.
///
/// Decoding is deliberately lenient per field: a missing or mistyped optional never fails the
/// batch, and only `id`, `title`, and `company_name` decide whether an entry becomes a draft.
nonisolated struct RemotiveJobDTO: Decodable, Sendable {
    let id: Int?
    let url: String?
    let title: String?
    let companyName: String?
    let companyLogoURL: String?
    let category: String?
    let tags: [String]?
    let jobType: String?
    let publicationDate: String?
    let candidateRequiredLocation: String?
    let salary: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case title
        case companyName = "company_name"
        case companyLogoURL = "company_logo_url"
        case category
        case tags
        case jobType = "job_type"
        case publicationDate = "publication_date"
        case candidateRequiredLocation = "candidate_required_location"
        case salary
        case description
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = Self.decodeID(from: container)
        url = (try? container.decodeIfPresent(String.self, forKey: .url)) ?? nil
        title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? nil
        companyName = (try? container.decodeIfPresent(String.self, forKey: .companyName)) ?? nil
        companyLogoURL = (try? container.decodeIfPresent(String.self, forKey: .companyLogoURL)) ?? nil
        category = (try? container.decodeIfPresent(String.self, forKey: .category)) ?? nil
        tags = (try? container.decodeIfPresent([String].self, forKey: .tags)) ?? nil
        jobType = (try? container.decodeIfPresent(String.self, forKey: .jobType)) ?? nil
        publicationDate = (try? container.decodeIfPresent(String.self, forKey: .publicationDate)) ?? nil
        candidateRequiredLocation =
            (try? container.decodeIfPresent(String.self, forKey: .candidateRequiredLocation)) ?? nil
        salary = (try? container.decodeIfPresent(String.self, forKey: .salary)) ?? nil
        description = (try? container.decodeIfPresent(String.self, forKey: .description)) ?? nil
    }

    /// The draft for this entry, or `nil` when identity or display fields are unusable.
    var draft: JobPostingDraft? {
        guard
            let id,
            let title = Self.trimmed(title),
            let companyName = Self.trimmed(companyName)
        else {
            AppLogger.data.debug(
                "Skipping a Remotive item without id, title, or company name (id: \(self.id.map(String.init) ?? "nil", privacy: .public))"
            )
            return nil
        }

        return JobPostingDraft(
            identityKey: JobIdentityKey.remotive(externalID: String(id)),
            intakeMethod: .remotive,
            title: title,
            companyName: companyName,
            descriptionPlainText: HTMLTextNormalizer.plainText(from: description ?? ""),
            externalJobID: String(id),
            jobURL: Self.webURL(url),
            location: Self.trimmed(candidateRequiredLocation),
            jobType: Self.trimmed(jobType)?.lowercased(),
            tags: tags ?? [],
            publishedAt: Self.parseDate(publicationDate),
            salary: Self.trimmed(salary),
            companyLogoURL: Self.webURL(companyLogoURL)
        )
    }

    // MARK: - Field normalization

    /// Remotive sends numeric ids today; accept a numeric string too so one entry cannot fail the sample.
    private static func decodeID(from container: KeyedDecodingContainer<CodingKeys>) -> Int? {
        if let value = (try? container.decodeIfPresent(Int.self, forKey: .id)) ?? nil {
            return value
        }
        if let raw = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? nil {
            return Int(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    /// Only absolute http(s) URLs with a host are usable links; anything else becomes `nil`.
    private static func webURL(_ raw: String?) -> URL? {
        guard let raw = trimmed(raw), let url = URL(string: raw) else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        guard url.host?.isEmpty == false else { return nil }
        return url
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Dates

    /// Parses Remotive's ISO 8601 date (with or without a zone); a bad value becomes `nil`.
    static func parseDate(_ raw: String?) -> Date? {
        guard let raw = trimmed(raw) else { return nil }

        let internetFormatter = ISO8601DateFormatter()
        internetFormatter.formatOptions = [.withInternetDateTime]
        if let date = internetFormatter.date(from: raw) {
            return date
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: raw) {
            return date
        }

        // The public sample currently omits the zone ("2026-11-06T08:51:01"); Remotive publishes UTC.
        let zonedFormatter = DateFormatter()
        zonedFormatter.locale = Locale(identifier: "en_US_POSIX")
        zonedFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        zonedFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return zonedFormatter.date(from: raw)
    }
}
