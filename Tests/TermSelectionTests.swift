import Foundation
import Testing
@testable import ScheduleCore

struct TermSelectionTests {
    let calendar = ScheduleRules.calendar
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }
    func term(_ id: String, _ name: String, start: Date, weeks: Int = 20) -> TermSummary {
        TermSummary(id: id, name: name, startDate: start, totalWeeks: weeks)
    }
    // 2026-09-07 是周一。
    var autumn: TermSummary { term("autumn", "2026 秋季学期", start: date(2026, 9, 7)) }
    var spring: TermSummary { term("spring", "2027 春季学期", start: date(2027, 2, 22)) }

    // MARK: 区间

    @Test func termStartsOnItsFirstDay() {
        #expect(autumn.startDate == date(2026, 9, 7))
    }

    @Test func lastDayIsStartPlusWeeksTimesSevenMinusOne() {
        // 20 周 = 140 天，最后一天是第 140 天，即开学后第 139 天。
        let expected = calendar.date(byAdding: .day, value: 139, to: date(2026, 9, 7))!
        let endDay = calendar.startOfDay(for: autumn.endDate)
        #expect(endDay == expected)
    }

    @Test func containsCoversFirstAndLastDay() {
        #expect(autumn.contains(date(2026, 9, 7)))
        let lastDay = calendar.date(byAdding: .day, value: 139, to: date(2026, 9, 7))!
        #expect(autumn.contains(lastDay))
    }

    @Test func excludesDayBeforeAndAfter() {
        #expect(!autumn.contains(date(2026, 9, 6)))
        let dayAfter = calendar.date(byAdding: .day, value: 140, to: date(2026, 9, 7))!
        #expect(!autumn.contains(dayAfter))
    }

    @Test func singleWeekTermSpansSevenDays() {
        let one = term("t", "单周", start: date(2026, 9, 7), weeks: 1)
        #expect(one.contains(date(2026, 9, 13)))
        #expect(!one.contains(date(2026, 9, 14)))
    }

    // MARK: 当前学期

    @Test func findsTermInSession() {
        let all = [autumn, spring]
        #expect(TermSelection.current(in: all, on: date(2026, 10, 1))?.id == "autumn")
        #expect(TermSelection.current(in: all, on: date(2027, 3, 10))?.id == "spring")
    }

    @Test func overlappingTermsPreferLatestStart() {
        // 排错也可能造成重叠；新学期应当优先。
        let overlapping = term("old", "旧", start: date(2026, 9, 7), weeks: 30)
        let all = [overlapping, spring]
        #expect(TermSelection.current(in: all, on: date(2027, 2, 25))?.id == "spring")
    }

    @Test func holidayGapHasNoCurrentTerm() {
        // 秋季 20 周在 2027-01-24 结束，春季 2027-02-22 开始，中间是假期。
        let gap = date(2027, 2, 1)
        #expect(TermSelection.current(in: [autumn, spring], on: gap) == nil)
    }

    // MARK: 假期回退

    @Test func gapPrefersUpcomingTerm() {
        let gap = date(2027, 2, 1)
        #expect(TermSelection.fallback(in: [autumn, spring], on: gap)?.id == "spring")
    }

    @Test func afterLastTermFallsBackToMostRecent() {
        let later = date(2027, 12, 1)
        #expect(TermSelection.fallback(in: [autumn, spring], on: later)?.id == "spring")
    }

    @Test func beforeFirstTermPrefersSoonestStart() {
        let early = date(2026, 1, 1)
        #expect(TermSelection.fallback(in: [autumn, spring], on: early)?.id == "autumn")
    }

    @Test func preferredUsesCurrentThenFallback() {
        #expect(TermSelection.preferred(in: [autumn, spring], on: date(2026, 10, 1))?.id == "autumn")
        #expect(TermSelection.preferred(in: [autumn, spring], on: date(2027, 2, 1))?.id == "spring")
    }

    @Test func emptyListHasNoSelection() {
        #expect(TermSelection.current(in: [], on: date(2026, 10, 1)) == nil)
        #expect(TermSelection.preferred(in: [], on: date(2026, 10, 1)) == nil)
        #expect(TermSelection.fallback(in: [], on: date(2026, 10, 1)) == nil)
    }

    // MARK: 排序

    @Test func sortedPutsNewestFirst() {
        let ordered = TermSelection.sorted([autumn, spring])
        #expect(ordered.map(\.id) == ["spring", "autumn"])
    }

    @Test func sameStartDateSortsByNameForStability() {
        let a = term("a", "A", start: date(2026, 9, 7))
        let b = term("b", "B", start: date(2026, 9, 7))
        #expect(TermSelection.sorted([b, a]).map(\.name) == ["A", "B"])
    }

    // MARK: 新建

    @Test func uniqueNameAppendsSuffix() {
        #expect(TermSelection.uniqueName("2026 秋季学期", existing: [autumn]) == "2026 秋季学期 2")
        let twice = [autumn, term("x", "2026 秋季学期 2", start: date(2026, 9, 7))]
        #expect(TermSelection.uniqueName("2026 秋季学期", existing: twice) == "2026 秋季学期 3")
    }

    @Test func uniqueNameKeepsFreeName() {
        #expect(TermSelection.uniqueName("2027 春季学期", existing: [autumn]) == "2027 春季学期")
    }

    @Test func suggestedStartIsAMonday() {
        let start = TermSelection.suggestedStart(after: [autumn])
        #expect(calendar.component(.weekday, from: start) == 2)
    }

    @Test func suggestedStartIsAfterPreviousTerm() {
        let start = TermSelection.suggestedStart(after: [autumn])
        #expect(start > autumn.endDate)
    }

    @Test func suggestedStartForFirstTermIsAMonday() {
        let start = TermSelection.suggestedStart(after: [])
        #expect(calendar.component(.weekday, from: start) == 2)
    }

    @Test func nextMondayCoversEveryWeekday() {
        // 2026-09-07 是周一，连续七天覆盖整周。
        for offset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: offset, to: date(2026, 9, 7))!
            let result = TermSelection.nextMonday(onOrAfter: day)
            #expect(calendar.component(.weekday, from: result) == 2)
            #expect(result >= calendar.startOfDay(for: day))
            // 结果必须是最近的周一，即相差不超过 6 天。
            let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: day), to: result).day ?? 99
            #expect((0...6).contains(gap))
        }
    }

    @Test func nextMondayIsIdempotentOnMonday() {
        let monday = date(2026, 9, 7)
        let result = TermSelection.nextMonday(onOrAfter: monday)
        #expect(result == calendar.startOfDay(for: monday))
    }

    // MARK: 删除

    @Test func deletingActiveTermSelectsAnother() {
        let next = TermSelection.afterRemoving("autumn", from: [autumn, spring], on: date(2026, 10, 1))
        #expect(next?.id == "spring")
    }

    @Test func deletingOnlyTermLeavesNothing() {
        #expect(TermSelection.afterRemoving("autumn", from: [autumn], on: date(2026, 10, 1)) == nil)
    }
}
