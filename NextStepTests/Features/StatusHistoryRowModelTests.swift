import Foundation
import Testing
@testable import NextStep

@Suite("StatusHistoryRowModel")
struct StatusHistoryRowModelTests {
    nonisolated struct TransitionCase: Sendable, CustomTestStringConvertible {
        let from: ApplicationStatus?
        let to: ApplicationStatus
        let expected: String

        var testDescription: String { "\(from?.rawValue ?? "creation")→\(to.rawValue)" }
    }

    private nonisolated static let transitionCases: [TransitionCase] = [
        TransitionCase(from: nil, to: .applied, expected: "创建 → 已投"),
        TransitionCase(from: .wishlist, to: .applied, expected: "想投 → 已投"),
        TransitionCase(from: .oa, to: .interview, expected: "OA/笔试 → 面试"),
        TransitionCase(from: .interview, to: .offer, expected: "面试 → Offer"),
        TransitionCase(from: .applied, to: .rejected, expected: "已投 → 已拒"),
        TransitionCase(from: .applied, to: .withdrawn, expected: "已投 → 已撤")
    ]

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) throws -> Date {
        try #require(makeCalendar().date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }

    @Test(
        "row transition text uses the creation marker or the Chinese from/to names",
        arguments: Self.transitionCases
    )
    func transitionTextUsesChineseStatusNames(testCase: TransitionCase) throws {
        let row = StatusHistoryRowModel(
            id: UUID(),
            fromStatus: testCase.from,
            toStatus: testCase.to,
            changedAt: try makeDate(year: 2026, month: 10, day: 1, hour: 9, minute: 0),
            note: nil,
            calendar: makeCalendar()
        )

        #expect(row.transitionText == testCase.expected)
    }

    @Test("row note text is trimmed and absent when blank")
    func noteTextIsTrimmedAndBlankNotesAreAbsent() throws {
        func makeRow(note: String?) throws -> StatusHistoryRowModel {
            StatusHistoryRowModel(
                id: UUID(),
                fromStatus: .applied,
                toStatus: .oa,
                changedAt: try makeDate(year: 2026, month: 11, day: 9, hour: 14, minute: 5),
                note: note,
                calendar: makeCalendar()
            )
        }

        #expect(try makeRow(note: "HR 约了笔试").noteText == "HR 约了笔试")
        #expect(try makeRow(note: "  改期到周五  ").noteText == "改期到周五")
        #expect(try makeRow(note: nil).noteText == nil)
        #expect(try makeRow(note: "   \n ").noteText == nil)
    }

    @Test("row time text uses the injected calendar and time zone")
    func timeTextUsesInjectedCalendarAndTimeZone() throws {
        var shanghai = Calendar(identifier: .gregorian)
        shanghai.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!

        let date = try #require(shanghai.date(from: DateComponents(
            year: 2026,
            month: 11,
            day: 9,
            hour: 7,
            minute: 30
        )))

        let shanghaiRow = StatusHistoryRowModel(
            id: UUID(),
            fromStatus: .applied,
            toStatus: .oa,
            changedAt: date,
            note: nil,
            calendar: shanghai
        )
        let utcRow = StatusHistoryRowModel(
            id: UUID(),
            fromStatus: .applied,
            toStatus: .oa,
            changedAt: date,
            note: nil,
            calendar: utc
        )

        #expect(shanghaiRow.timeText == "2026年11月9日 07:30")
        #expect(utcRow.timeText == "2026年11月8日 23:30")
    }
}
