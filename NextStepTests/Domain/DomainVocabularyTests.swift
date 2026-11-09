import Foundation
import Testing
@testable import NextStep

@Suite("Domain vocabulary")
struct DomainVocabularyTests {
    @Test func applicationStatusUsesStableRawValuesAndChineseDisplayNames() {
        #expect(ApplicationStatus.allCases.map(\.rawValue) == [
            "wishlist", "applied", "oa", "interview", "offer", "rejected", "withdrawn",
        ])
        #expect(ApplicationStatus.allCases.map(\.displayName) == [
            "想投", "已投", "OA/笔试", "面试", "Offer", "已拒", "已撤",
        ])
        #expect(ApplicationStatus(rawValue: "oa") == .oa)
        #expect(ApplicationStatus(rawValue: "unknown") == nil)
    }

    @Test func jobIntakeMethodUsesStableRawValues() {
        #expect(JobIntakeMethod.allCases.map(\.rawValue) == ["remotive", "manual", "url"])
        #expect(JobIntakeMethod.remotive.displayName == "Remotive")
        #expect(JobIntakeMethod.manual.displayName == "手动导入")
        #expect(JobIntakeMethod.url.displayName == "链接导入")
    }

    @Test func interviewFormatAndResultUseStableRawValuesAndChineseDisplayNames() {
        #expect(InterviewFormat.allCases.map(\.rawValue) == ["phone", "video", "onsite", "other"])
        #expect(InterviewFormat.allCases.map(\.displayName) == ["电话", "视频", "现场", "其他"])

        #expect(InterviewResult.allCases.map(\.rawValue) == ["pending", "passed", "failed", "cancelled"])
        #expect(InterviewResult.allCases.map(\.displayName) == ["待定", "通过", "未通过", "取消"])
    }

    @Test func identityKeyFormatIsStableForRemotiveAndManualSources() {
        #expect(JobIdentityKey.remotive(externalID: "12345") == "remotive:12345")

        let id = UUID(uuidString: "9F1B2C3D-4E5F-6789-ABCD-EF0123456789")!
        #expect(JobIdentityKey.manual(id: id) == "manual:9f1b2c3d-4e5f-6789-abcd-ef0123456789")
    }
}
