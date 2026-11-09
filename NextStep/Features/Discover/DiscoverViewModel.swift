import Foundation
import Observation
import os

/// Presentation state for the Discover tab: cached jobs, sample counts, and the session-only
/// internship display filter. Refresh, TTL, and quota handling belong to ticket 23.
@Observable
@MainActor
final class DiscoverViewModel {
    private let jobRepository: any JobRepository
    private let dateProvider: any DateProvider

    private(set) var cacheState: LoadState<[JobPosting]> = .idle
    var onlyInternships = false

    init(jobRepository: any JobRepository, dateProvider: any DateProvider) {
        self.jobRepository = jobRepository
        self.dateProvider = dateProvider
    }

    var jobs: [JobPosting] { cacheState.value ?? [] }

    var visibleJobs: [JobPosting] {
        guard onlyInternships else { return jobs }
        return jobs.filter { $0.jobType?.lowercased() == "internship" }
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
        } catch {
            cacheState = .failed(error)
            AppLogger.ui.error(
                "Failed to load cached jobs: \(error.localizedDescription, privacy: .public)"
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
}
