import Foundation
import Testing
@testable import NextStep

@Suite("JobSourceErrorCopy")
struct JobSourceErrorCopyTests {
    nonisolated struct MessageCase: Sendable {
        let error: JobSourceError
        let message: String
    }

    @Test(arguments: [
        MessageCase(error: .invalidInput, message: "请检查必填项"),
        MessageCase(error: .offline, message: "网络不可用，请检查连接"),
        MessageCase(error: .timedOut, message: "请求超时，请稍后重试"),
        MessageCase(error: .rateLimited, message: "请求过于频繁，请稍后再试"),
        MessageCase(error: .server(503), message: "服务器暂时不可用（HTTP 503）"),
        MessageCase(error: .decoding, message: "数据格式暂时无法识别"),
    ])
    func mapsEveryTypedSourceErrorToSpecCopy(testCase: MessageCase) {
        let message = JobSourceErrorCopy.message(
            for: testCase.error,
            fallback: "加载失败，请稍后重试"
        )

        #expect(message == testCase.message)
    }

    @Test func unknownErrorsUseTheCallersFallback() {
        #expect(
            JobSourceErrorCopy.message(
                for: RepositoryError.loadFailed,
                fallback: "加载失败，请稍后重试"
            ) == "加载失败，请稍后重试"
        )
        #expect(
            JobSourceErrorCopy.message(
                for: RepositoryError.saveFailed,
                fallback: "保存失败，请重试"
            ) == "保存失败，请重试"
        )
    }
}
