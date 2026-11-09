import Foundation
import Observation
import os

/// Options shown by the manual import form's job type picker.
///
/// `.unknown` passes `nil` to `ManualJobInput`, letting `ManualJobSource` infer internship from the
/// title. Raw values match the canonical strings stored on `JobPosting.jobType`.
nonisolated enum JobTypeOption: String, CaseIterable, Identifiable, Sendable {
    case internship
    case fullTime = "full_time"
    case contract
    case freelance
    case partTime = "part_time"
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .internship: "实习"
        case .fullTime: "全职"
        case .contract: "合同"
        case .freelance: "自由职业"
        case .partTime: "兼职"
        case .unknown: "未知"
        }
    }

    var jobTypeValue: String? {
        self == .unknown ? nil : rawValue
    }

    /// Chinese label for a persisted raw `jobType`; unknown values fall back to their raw string.
    static func displayName(forJobType rawValue: String?) -> String? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        return switch rawValue.lowercased() {
        case "internship": "实习"
        case "full_time": "全职"
        case "contract": "合同"
        case "freelance": "自由职业"
        case "part_time": "兼职"
        default: rawValue
        }
    }
}

/// Presentation state for the "paste a JD" form: field values, inline validation, save lifecycle,
/// and Chinese error mapping.
@Observable
@MainActor
final class ManualImportViewModel {
    enum Field: Hashable {
        case title
        case companyName
        case descriptionPlainText
        case jobURL
    }

    var title = ""
    var companyName = ""
    var descriptionPlainText = ""
    var location = ""
    var jobURLText = ""
    var jobType: JobTypeOption = .unknown
    var tagsText = ""

    private(set) var fieldErrors: [Field: String] = [:]
    private(set) var isSaving = false
    private(set) var saveErrorMessage: String?

    private let jobRepository: any JobRepository

    init(jobRepository: any JobRepository) {
        self.jobRepository = jobRepository
    }

    func error(for field: Field) -> String? {
        fieldErrors[field]
    }

    /// Validates, then imports through the repository. Returns the new posting's id on success.
    func save() async -> UUID? {
        guard !isSaving else { return nil }
        saveErrorMessage = nil

        var errors: [Field: String] = [:]
        if trimmed(title).isEmpty { errors[.title] = "请填写岗位标题" }
        if trimmed(companyName).isEmpty { errors[.companyName] = "请填写公司" }
        if trimmed(descriptionPlainText).isEmpty { errors[.descriptionPlainText] = "请填写 JD 正文" }
        let parsedURL = parseJobURL()
        if !parsedURL.isValid {
            errors[.jobURL] = "请输入有效的岗位链接（需以 http 或 https 开头）"
        }
        fieldErrors = errors
        guard errors.isEmpty else { return nil }

        isSaving = true
        defer { isSaving = false }

        let input = ManualJobInput(
            title: trimmed(title),
            companyName: trimmed(companyName),
            descriptionPlainText: trimmed(descriptionPlainText),
            jobURL: parsedURL.url,
            location: trimmedOptional(location),
            jobType: jobType.jobTypeValue,
            tags: splitTags(tagsText)
        )

        do {
            let posting = try await jobRepository.importManual(input)
            return posting.id
        } catch {
            saveErrorMessage = Self.message(for: error)
            AppLogger.ui.error(
                "Manual import failed: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func parseJobURL() -> (url: URL?, isValid: Bool) {
        let text = trimmed(jobURLText)
        guard !text.isEmpty else { return (nil, true) }
        guard
            let url = URL(string: text),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            url.host?.isEmpty == false
        else {
            return (nil, false)
        }
        return (url, true)
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func trimmedOptional(_ value: String) -> String? {
        let trimmed = trimmed(value)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func splitTags(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",，"))
            .map { trimmed($0) }
            .filter { !$0.isEmpty }
    }

    /// Maps typed failures to the Chinese copy from spec §11; never shows raw errors.
    private static func message(for error: any Error) -> String {
        guard let sourceError = error as? JobSourceError else {
            return "保存失败，请重试"
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
