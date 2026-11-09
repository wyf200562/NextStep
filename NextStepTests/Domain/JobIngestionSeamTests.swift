import Foundation
import Testing
@testable import NextStep

@Suite("Job ingestion seams")
struct JobIngestionSeamTests {
    private struct FakeJobSource: JobSource {
        let intakeMethod: JobIntakeMethod
        let drafts: [JobPostingDraft]

        func loadJobs() async throws -> [JobPostingDraft] { drafts }
    }

    @Test func jobQueryDefaultsToTheSoftwareDevSample() {
        let query = JobQuery()

        #expect(query.keyword == nil)
        #expect(query.category == "software-dev")
        #expect(query.limit == 50)
    }

    @Test func jobSourceFactoryCreatesConfiguredSourcesThroughTheUnifiedSeam() async throws {
        let draft = JobPostingDraft(
            identityKey: JobIdentityKey.manual(),
            intakeMethod: .manual,
            title: "iOS Intern",
            companyName: "Acme",
            descriptionPlainText: "虚构 JD"
        )
        let factory = JobSourceFactory(
            makeRemote: { _ in FakeJobSource(intakeMethod: .remotive, drafts: []) },
            makeManual: { _ in FakeJobSource(intakeMethod: .manual, drafts: [draft]) }
        )

        let manualSource = factory.makeManual(
            ManualJobInput(title: "iOS Intern", companyName: "Acme", descriptionPlainText: "虚构 JD")
        )
        #expect(manualSource.intakeMethod == .manual)
        #expect(try await manualSource.loadJobs() == [draft])

        let remoteSource = factory.makeRemote(JobQuery())
        #expect(remoteSource.intakeMethod == .remotive)
        #expect(try await remoteSource.loadJobs().isEmpty)
    }

    @Test func jobSourceErrorUsesTypedCases() {
        #expect(JobSourceError.server(503) == .server(503))
        #expect(JobSourceError.invalidInput == .invalidInput)
        #expect(JobSourceError.offline == .offline)
        #expect(JobSourceError.timedOut == .timedOut)
        #expect(JobSourceError.rateLimited == .rateLimited)
        #expect(JobSourceError.decoding == .decoding)
    }

    @Test func refreshOutcomeCarriesRefreshSkipAndFailureDetail() {
        if case .refreshed(let added, let updated) = RefreshOutcome.refreshed(added: 2, updated: 1) {
            #expect(added == 2)
            #expect(updated == 1)
        } else {
            Issue.record("Expected refreshed outcome")
        }

        if case .skipped(let reason) = RefreshOutcome.skipped(reason: .quotaExhausted) {
            #expect(reason == .quotaExhausted)
        } else {
            Issue.record("Expected skipped outcome")
        }

        if case .failed(let error, let cachedCount) = RefreshOutcome.failed(
            error: JobSourceError.offline,
            cachedCount: 3
        ) {
            #expect(error is JobSourceError)
            #expect(cachedCount == 3)
        } else {
            Issue.record("Expected failed outcome")
        }
    }
}
