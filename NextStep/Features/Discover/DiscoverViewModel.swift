import Foundation
import Observation
import os

/// Presentation state for the Discover tab: cached jobs, derived match groups, sample counts, and
/// the session-only internship display filter. Refresh, TTL, and quota handling belong to ticket 23.
@Observable
@MainActor
final class DiscoverViewModel {
    private let jobRepository: any JobRepository
    private let dateProvider: any DateProvider
    /// `nil` means the bundled lexicon is unavailable; postings still group by stored job type.
    private let matchProvider: (any MatchProviding)?

    private(set) var cacheState: LoadState<[JobPosting]> = .idle
    var onlyInternships = false

    private(set) var matchAvailability: MatchAvailability = .unavailable
    private(set) var isShowingAllIneligible = false

    /// Derived, never persisted. Recomputed on every cache load.
    private var matches: [String: MatchResult] = [:]
    private var fallbackEligibility: [String: Eligibility] = [:]

    init(
        jobRepository: any JobRepository,
        dateProvider: any DateProvider,
        matchProvider: (any MatchProviding)? = nil
    ) {
        self.jobRepository = jobRepository
        self.dateProvider = dateProvider
        self.matchProvider = matchProvider
    }

    var jobs: [JobPosting] { cacheState.value ?? [] }

    var visibleJobs: [JobPosting] {
        guard onlyInternships else { return jobs }
        return jobs.filter { $0.jobType?.lowercased() == "internship" }
    }

    /// Eligible and ineligible groups, obeying the display-only internship filter.
    var groupedJobs: DiscoverJobGroups {
        DiscoverJobGrouping.make(
            jobs: jobs,
            matches: matches,
            fallbackEligibility: fallbackEligibility,
            availability: matchAvailability,
            onlyInternships: onlyInternships
        )
    }

    var eligibleJobs: [DiscoverJobItem] { groupedJobs.eligible }
    var ineligibleJobs: [DiscoverJobItem] { groupedJobs.ineligible }

    /// The ineligible group shows four rows by default and can expand to all.
    var visibleIneligibleJobs: [DiscoverJobItem] {
        isShowingAllIneligible
            ? ineligibleJobs
            : Array(ineligibleJobs.prefix(Self.ineligiblePreviewLimit))
    }

    var hasMoreIneligible: Bool {
        ineligibleJobs.count > Self.ineligiblePreviewLimit
    }

    func toggleIneligibleExpansion() {
        isShowingAllIneligible.toggle()
    }

    var remotiveCount: Int {
        jobs.filter { $0.intakeMethod == .remotive }.count
    }

    var remotiveInternshipCount: Int {
        jobs.filter {
            $0.intakeMethod == .remotive && $0.jobType?.lowercased() == "internship"
        }.count
    }

    var manualCount: Int {
        jobs.filter { $0.intakeMethod == .manual }.count
    }

    var cacheErrorMessage: String? {
        guard case .failed(let error) = cacheState else { return nil }
        return Self.message(for: error)
    }

    var sampleDateText: String {
        let components = dateProvider.calendar.dateComponents(
            [.month, .day],
            from: dateProvider.now
        )
        return "\(components.month ?? 1) 月 \(components.day ?? 1) 日 · 今日样本"
    }

    func loadCachedJobs() {
        do {
            cacheState = .loaded(try jobRepository.cachedJobs())
            refreshMatches()
        } catch {
            cacheState = .failed(error)
            matches = [:]
            fallbackEligibility = [:]
            matchAvailability = .unavailable
            AppLogger.ui.error(
                "Failed to load cached jobs: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Recomputes match data for every cached posting; results are never stored.
    private func refreshMatches() {
        let cachedJobs = jobs
        guard !cachedJobs.isEmpty else {
            matches = [:]
            fallbackEligibility = [:]
            matchAvailability = .ready
            return
        }
        guard let matchProvider else {
            matches = [:]
            fallbackEligibility = [:]
            matchAvailability = .unavailable
            return
        }

        do {
            let results = try matchProvider.evaluate(jobs: cachedJobs)
            matches = results
            if results.isEmpty {
                // An empty dictionary with cached jobs means the profile gate is unmet.
                matchAvailability = .profileIncomplete
                do {
                    fallbackEligibility = try matchProvider.eligibility(jobs: cachedJobs)
                } catch {
                    fallbackEligibility = [:]
                    AppLogger.matching.error(
                        "Failed to evaluate gate-independent eligibility: \(error.localizedDescription, privacy: .public)"
                    )
                }
            } else {
                matchAvailability = .ready
                fallbackEligibility = [:]
            }
        } catch {
            matches = [:]
            fallbackEligibility = [:]
            matchAvailability = .unavailable
            AppLogger.matching.error(
                "Failed to evaluate cached jobs: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Maps typed data-layer failures to the Chinese copy from spec §11; never shows raw errors.
    private static func message(for error: any Error) -> String {
        guard let sourceError = error as? JobSourceError else {
            return "加载失败，请稍后重试"
        }
        return switch sourceError {
        case .invalidInput: "请检查必填项"
        case .offline: "网络不可用，请检查连接"
        case .timedOut: "请求超时，请稍后重试"
        case .rateLimited: "请求过于频繁，请稍后再试"
        case .server(let code): "服务器暂时不可用（HTTP \(code)）"
        case .decoding: "数据格式暂时无法识别"
        }
    }

    private static let ineligiblePreviewLimit = 4
}
