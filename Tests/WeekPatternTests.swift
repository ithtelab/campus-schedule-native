import Foundation
import Testing
@testable import ScheduleCore

struct WeekPatternTests {
    @Test func fullTermIsEveryWeek() {
        #expect(WeekPattern.infer(from: Set(1...20), totalWeeks: 20) == .everyWeek)
    }

    @Test func emptyWeeksTreatedAsEveryWeek() {
        // 空集合表示未指定，界面不应显示任何角标。
        #expect(WeekPattern.infer(from: [], totalWeeks: 20) == .everyWeek)
    }

    @Test func oddWeeksDetected() {
        #expect(WeekPattern.infer(from: Set([1, 3, 5, 7, 9]), totalWeeks: 9) == .odd)
    }

    @Test func evenWeeksDetected() {
        #expect(WeekPattern.infer(from: Set([2, 4, 6, 8]), totalWeeks: 9) == .even)
    }

    @Test func partialRangesAreCustom() {
        // 1-8 周不是整学期，也不是单双周。
        #expect(WeekPattern.infer(from: Set(1...8), totalWeeks: 20) == .custom)
    }

    @Test func irregularSetIsCustom() {
        #expect(WeekPattern.infer(from: [1, 2, 5, 9], totalWeeks: 20) == .custom)
    }

    @Test func badgesMatchPattern() {
        #expect(WeekPattern.everyWeek.badge == nil)
        #expect(WeekPattern.odd.badge == "单")
        #expect(WeekPattern.even.badge == "双")
        #expect(WeekPattern.custom.badge == "部分周")
    }

    @Test func fullOddTermIsNotMarkedOdd() {
        // 20 周全是奇数周不成立，但若总周数为 1 且只有第 1 周，应视为整学期。
        #expect(WeekPattern.infer(from: [1], totalWeeks: 1) == .everyWeek)
    }
}
