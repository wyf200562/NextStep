import Foundation
import Observation
import os

/// Presentation state for the Discover tab: cached jobs, derived match groups, sample counts, the
/// refresh loop, and the session-only internship display filter.
@Observable
@MainActor
final class DiscoverViewModel {
    /// The last refresh attempt's outcome. `.skipped(.fresh)` and cancellation are silent.
    enum RefreshState: Equatable {
        case idle
        case refreshing
        case refreshed(added: Int, updated: Int)
        case skipped(RefreshOutcome.SkipReason)
        case failed(RefreshFailure)
    }

    struct RefreshFailure: Equatable {
        /// Chinese copy; raw errors are never shown.
        let message: String
    }

    /// A user-facing refresh prompt. The View renders notices in amber and blocking prompts
    /// full-screen; the ViewModel decides which applies from the cache and the outcome.
    struct RefreshPrompt: Equatable {
        let title: String
        let message: String?
    }

    static let automaticRefreshInterval: TimeInterval = 6 * 60 * 60

    private static let refreshQuery = JobQuery()

    private let jobRepository: any JobRepository
    private let dateProvider: any DateProvider
    /// `nil` means the bundled lexicon is unavailable; postings still group by stored job type.
    private let matchProvider: (any MatchProviding)?

    private(set) var cacheState: LoadState<[JobPosting]> = .idle
    var onlyInternships = false

    private(set) var matchAvailability: MatchAvailability = .unavailable
    private(set) var isShowingAllIneligible = false

    private(set) var refreshState: RefreshState = .idle
    /// The most recent *successful* refresh, used for the header and the 6-hour TTL.
    private(set) var lastRefreshAt: Date?
    /// "本次刷新 N 条" after a `.refreshed` outcome; cleared by any other outcome.
    private(set) var lastRefreshSummary: String?

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

    /// "更新于 11 月 9 日 10:05"; the header footer falls back to "尚未成功刷新".
    var lastRefreshText: String {
        guard let lastRefreshAt else { return "尚未成功刷新" }
        let components = dateProvider.calendar.dateComponents(
            [.month, .day, .hour, .minute],
            from: lastRefreshAt
        )
        let minute = String(format: "%02d", components.minute ?? 0)
        return "更新于 \(components.month ?? 1) 月 \(components.day ?? 1) 日 \(components.hour ?? 0):\(minute)"
    }

    var isRefreshing: Bool {
        refreshState == .refreshing
    }

    /// The first screen shows a spinner only while the empty cache is being filled.
    var isInitialLoading: Bool {
        if case .idle = cacheState { return true }
        return jobs.isEmpty && isRefreshing
    }

    /// Amber, non-blocking prompt shown above the list when a cache exists.
    var refreshNotice: RefreshPrompt? {
        guard !jobs.isEmpty else { return nil }
        switch refreshState {
        case .failed(let failure):
            return RefreshPrompt(
                title: "今天没能刷新 · 显示 \(cachedDatePhrase)",
                message: failure.message
            )
        case .skipped(.quotaExhausted):
            return RefreshPrompt(
                title: "今天的刷新次数已用完 · 显示 \(cachedDatePhrase)",
                message: "配额明天恢复，也可以先粘贴 JD。"
            )
        case .skipped(.tooSoon):
            return RefreshPrompt(title: "刷新太频繁，请稍后再试", message: nil)
        case .idle, .refreshing, .refreshed, .skipped(.fresh):
            return nil
        }
    }

    /// Full-screen "暂时拿不到岗位" state when a blocked or failed refresh has no cache to fall back on.
    var blockingRefreshPrompt: RefreshPrompt? {
        guard jobs.isEmpty else { return nil }
        switch refreshState {
        case .failed(let failure):
            return RefreshPrompt(
                title: "暂时拿不到岗位",
                message: "\(failure.message)。手动粘贴不依赖 Remotive，可以先用它。"
            )
        case .skipped(.quotaExhausted):
            return RefreshPrompt(
                title: "暂时拿不到岗位",
                message: "今天的刷新次数已用完，配额明天恢复。手动粘贴不依赖 Remotive，现在就能用。"
            )
        case .skipped(.tooSoon):
            return RefreshPrompt(
                title: "暂时拿不到岗位",
                message: "刷新太频繁，请稍后再试。手动粘贴不依赖 Remotive，现在就能用。"
            )
        case .idle, .refreshing, .refreshed, .skipped(.fresh):
            return nil
        }
    }

    /// First appearance: show the cache immediately, then refresh unless a fresh successful refresh
    /// already covers a non-empty cache.
    func loadAndRefreshIfNeeded() async {
        loadCachedJobs()
        guard !Task.isCancelled else { return }

        if !jobs.isEmpty,
           let lastSuccess = jobRepository.lastRefreshAt(for: .remotive),
           dateProvider.now.timeIntervalSince(lastSuccess) < Self.automaticRefreshInterval {
            refreshState = .skipped(.fresh)
            return
        }
        await refresh()
    }

    /// Pull-to-refresh, retry, and the post-TTL automatic path. Ignores the 6-hour TTL; the
    /// repository still enforces the rolling quota and the 60-second interval.
    func refresh() async {
        guard !isRefreshing else { return }
        refreshState = .refreshing

        let outcome = await jobRepository.refreshDiscover(query: Self.refreshQuery)
        lastRefreshAt = jobRepository.lastRefreshAt(for: .remotive)

        switch outcome {
        case .refreshed(let added, let updated):
            loadCachedJobs()
            lastRefreshAt = jobRepository.lastRefreshAt(for: .remotive)
            lastRefreshSummary = "本次刷新 \(added + updated) 条"
            refreshState = .refreshed(added: added, updated: updated)
        case .skipped(let reason):
            lastRefreshSummary = nil
            refreshState = .skipped(reason)
        case .failed(let error, _):
            guard !(error is CancellationError) else {
                lastRefreshSummary = nil
                refreshState = .idle
                return
            }
            lastRefreshSummary = nil
            refreshState = .failed(RefreshFailure(message: Self.message(for: error)))
        }
    }

    private var cachedDatePhrase: String {
        guard let lastRefreshAt else { return "本机缓存" }
        let components = dateProvider.calendar.dateComponents(
            [.month, .day],
            from: lastRefreshAt
        )
        return "\(components.month ?? 1) 月 \(components.day ?? 1) 日的缓存"
    }

    func loadCachedJobs() {
        do {
            cacheState = .loaded(try jobRepository.cachedJobs())
            lastRefreshAt = jobRepository.lastRefreshAt(for: .remotive)
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
        JobSourceError.message(for: error, fallback: "加载失败，请稍后重试")
    }

    private static let ineligiblePreviewLimit = 4
}
