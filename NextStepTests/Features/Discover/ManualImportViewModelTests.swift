import Foundation
import Testing
@testable import NextStep

@Suite("ManualImportViewModel")
struct ManualImportViewModelTests {
    @MainActor
    private final class FakeJobRepository: JobRepository {
        var importResult: Result<JobPosting, any Error> = .failure(RepositoryError.unavailable)
        private(set) var importedInputs: [ManualJobInput] = []

        func cachedJobs() throws -> [JobPosting] { [] }

        func refreshDiscover(query: JobQuery) async -> RefreshOutcome {
            .failed(error: RepositoryError.unavailable, cachedCount: 0)
        }

        func importManual(_ input: ManualJobInput) async throws -> JobPosting {
            importedInputs.append(input)
            return try importResult.get()
        }

        func lastRefreshAt(for source: JobIntakeMethod) -> Date? { nil }
    }

    @Test func saveWithBlankRequiredFieldsShowsInlineErrorsAndSkipsRepository() async {
        let repository = FakeJobRepository()
        let viewModel = ManualImportViewModel(jobRepository: repository)
        viewModel.title = "  "
        viewModel.companyName = "\n"
        viewModel.descriptionPlainText = "   "

        let savedID = await viewModel.save()

        #expect(savedID == nil)
        #expect(repository.importedInputs.isEmpty)
        #expect(viewModel.error(for: .title) == "请填写岗位标题")
        #expect(viewModel.error(for: .companyName) == "请填写公司")
        #expect(viewModel.error(for: .descriptionPlainText) == "请填写 JD 正文")
        #expect(viewModel.isSaving == false)
        #expect(viewModel.saveErrorMessage == nil)
    }

    @Test func saveWithInvalidJobURLShowsInlineErrorAndSkipsRepository() async {
        let repository = FakeJobRepository()
        let viewModel = ManualImportViewModel(jobRepository: repository)
        viewModel.title = "iOS 开发实习生"
        viewModel.companyName = "星舟科技"
        viewModel.descriptionPlainText = "参与 iOS 开发"
        viewModel.jobURLText = "example.com/jobs/1"

        let savedID = await viewModel.save()

        #expect(savedID == nil)
        #expect(repository.importedInputs.isEmpty)
        #expect(viewModel.error(for: .jobURL) == "请输入有效的岗位链接（需以 http 或 https 开头）")
        #expect(viewModel.error(for: .title) == nil)
    }

    @Test func saveTrimsFieldsAndPassesNormalizedInputToRepository() async throws {
        let repository = FakeJobRepository()
        let posting = JobPosting(
            identityKey: "manual:00000000-0000-0000-0000-000000000010",
            title: "iOS 开发实习生",
            companyName: "星舟科技",
            intakeMethod: .manual,
            descriptionPlainText: "参与 iOS 开发",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        repository.importResult = .success(posting)
        let viewModel = ManualImportViewModel(jobRepository: repository)
        viewModel.title = "  iOS 开发实习生  "
        viewModel.companyName = " 星舟科技 "
        viewModel.descriptionPlainText = "\n 参与 iOS 开发 \n"
        viewModel.location = "  远程 "
        viewModel.jobURLText = " https://example.com/jobs/1 "
        viewModel.jobType = .unknown
        viewModel.tagsText = " Swift, SwiftUI，Swift "

        let savedID = await viewModel.save()

        #expect(savedID == posting.id)
        #expect(repository.importedInputs.count == 1)
        let input = try #require(repository.importedInputs.first)
        #expect(input.title == "iOS 开发实习生")
        #expect(input.companyName == "星舟科技")
        #expect(input.descriptionPlainText == "参与 iOS 开发")
        #expect(input.location == "远程")
        #expect(input.jobURL == URL(string: "https://example.com/jobs/1"))
        #expect(input.jobType == nil)
        #expect(input.tags == ["Swift", "SwiftUI", "Swift"])
        #expect(viewModel.isSaving == false)
        #expect(viewModel.saveErrorMessage == nil)
        #expect(viewModel.error(for: .jobURL) == nil)
    }

    @Test func saveFailureKeepsFormContentAndShowsChineseError() async {
        let repository = FakeJobRepository()
        repository.importResult = .failure(RepositoryError.saveFailed)
        let viewModel = ManualImportViewModel(jobRepository: repository)
        viewModel.title = "iOS 开发实习生"
        viewModel.companyName = "星舟科技"
        viewModel.descriptionPlainText = "参与 iOS 开发"

        let savedID = await viewModel.save()

        #expect(savedID == nil)
        #expect(viewModel.title == "iOS 开发实习生")
        #expect(viewModel.companyName == "星舟科技")
        #expect(viewModel.descriptionPlainText == "参与 iOS 开发")
        #expect(viewModel.saveErrorMessage == "保存失败，请重试")
        #expect(viewModel.isSaving == false)
    }

    @Test(arguments: [
        (JobTypeOption.internship, "internship"),
        (JobTypeOption.fullTime, "full_time"),
        (JobTypeOption.contract, "contract"),
        (JobTypeOption.freelance, "freelance"),
        (JobTypeOption.partTime, "part_time"),
        (JobTypeOption.unknown, nil as String?),
    ])
    func jobTypeOptionsMapToCanonicalStoredValues(option: JobTypeOption, expected: String?) {
        #expect(option.jobTypeValue == expected)
    }
}
