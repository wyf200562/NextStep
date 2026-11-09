import Foundation
import Testing
@testable import NextStep

@Suite("Core foundations")
struct CoreFoundationTests {
    private struct SampleError: Error {}

    @Test func loadStateExposesValueOnlyWhenLoaded() {
        #expect(LoadState<Int>.loaded(42).value == 42)
        #expect(LoadState<Int>.idle.value == nil)
        #expect(LoadState<Int>.loading.value == nil)
        #expect(LoadState<Int>.failed(SampleError()).value == nil)

        #expect(LoadState<Int>.loading.isLoading)
        #expect(LoadState<Int>.loaded(1).isLoading == false)
        #expect(LoadState<Int>.failed(SampleError()).error is SampleError)
        #expect(LoadState<Int>.loaded(1).error == nil)
    }

    @Test func fixedDateProviderReturnsInjectedDateAndCalendar() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!

        let provider = FixedDateProvider(now: now, calendar: calendar)

        #expect(provider.now == now)
        #expect(provider.calendar.identifier == .gregorian)
        #expect(provider.calendar.timeZone == TimeZone(identifier: "Asia/Shanghai"))
    }
}
