import Foundation
import Testing
@testable import ScheduleCore

struct ScheduleSummaryTests {
    let calendar = ScheduleRules.calendar
    let semesterStart: Date

    init() {
        // 2026-09-07 是周一。
        semesterStart = ScheduleRules.calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))!
    }

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func occurrence(_ title: String, start: Date, hours: Double = 1.5, courseID: String? = nil) -> CourseOccurrence {
        CourseOccurrence(id: "\(title)-\(start.timeIntervalSince1970)", courseID: courseID ?? title,
                         title: title, room: "A302", start: start,
                         end: start.addingTimeInterval(hours * 3600))
    }

    // MARK: 空

    @Test func emptyScheduleHasZeroCounts() {
        let summary = ScheduleSummary.make(occurrences: [], now: date(2026, 10, 26, 9),
                                           semesterStart: semesterStart)
        #expect(summary.weekSessions == 0)
        #expect(summary.monthSessions == 0)
        #expect(summary.todayRemaining == 0)
        #expect(summary.todayCompleted == 0)
    }

    @Test func monthProgressIsNilWithoutClasses() {
        #expect(ScheduleSummary().monthProgress == nil)
    }

    // MARK: 本周

    @Test func countsOnlyCurrentWeek() {
        // 2026-10-26 是第 8 周周一。
        let inWeek = occurrence("高数", start: date(2026, 10, 27, 9))
        let lastWeek = occurrence("英语", start: date(2026, 10, 20, 9))
        let summary = ScheduleSummary.make(occurrences: [inWeek, lastWeek],
                                           now: date(2026, 10, 28, 12),
                                           semesterStart: semesterStart)
        #expect(summary.weekSessions == 1)
    }

    @Test func weekBoundaryIncludesMondayExcludesNextMonday() {
        let monday = occurrence("周一课", start: date(2026, 10, 26, 8))
        let nextMonday = occurrence("下周一课", start: date(2026, 11, 2, 8))
        let summary = ScheduleSummary.make(occurrences: [monday, nextMonday],
                                           now: date(2026, 10, 28, 12),
                                           semesterStart: semesterStart)
        #expect(summary.weekSessions == 1)
    }

    // MARK: 本月

    @Test func countsThisMonthOnly() {
        let october = occurrence("十月课", start: date(2026, 10, 5, 9))
        let september = occurrence("九月课", start: date(2026, 9, 28, 9))
        let summary = ScheduleSummary.make(occurrences: [october, september],
                                           now: date(2026, 10, 20, 12),
                                           semesterStart: semesterStart)
        #expect(summary.monthSessions == 1)
    }

    @Test func monthCompletedCountsPastClasses() {
        let earlier = occurrence("早课", start: date(2026, 10, 10, 9), hours: 2)
        let later = occurrence("晚课", start: date(2026, 10, 25, 9), hours: 2)
        let summary = ScheduleSummary.make(occurrences: [earlier, later],
                                           now: date(2026, 10, 20, 12),
                                           semesterStart: semesterStart)
        #expect(summary.monthSessions == 2)
        #expect(summary.monthCompleted == 1)
    }

    @Test func monthProgressReflectsCompletion() {
        let done = occurrence("已完成", start: date(2026, 10, 5, 9), hours: 2)
        let pending = occurrence("待上", start: date(2026, 10, 25, 9), hours: 2)
        let summary = ScheduleSummary.make(occurrences: [done, pending],
                                           now: date(2026, 10, 20, 12),
                                           semesterStart: semesterStart)
        #expect(summary.monthProgress == 0.5)
    }

    // MARK: 今天

    @Test func todaySplitsCompletedAndRemaining() {
        let morning = occurrence("早课", start: date(2026, 10, 28, 8), hours: 2)
        let afternoon = occurrence("午课", start: date(2026, 10, 28, 14), hours: 2)
        let summary = ScheduleSummary.make(occurrences: [morning, afternoon],
                                           now: date(2026, 10, 28, 12),
                                           semesterStart: semesterStart)
        #expect(summary.todayCompleted == 1)
        #expect(summary.todayRemaining == 1)
    }

    @Test func ongoingClassCountsAsRemaining() {
        // 正在上的课：开始时刻未过，因此归入「还没上」，而不是已完成。
        let ongoing = occurrence("正在上", start: date(2026, 10, 28, 10), hours: 2)
        let summary = ScheduleSummary.make(occurrences: [ongoing],
                                           now: date(2026, 10, 28, 10),
                                           semesterStart: semesterStart)
        #expect(summary.todayRemaining == 1)
        #expect(summary.todayCompleted == 0)
    }

    @Test func ignoresOtherDaysForTodayCounts() {
        let yesterday = occurrence("昨天", start: date(2026, 10, 27, 9))
        let summary = ScheduleSummary.make(occurrences: [yesterday],
                                           now: date(2026, 10, 28, 12),
                                           semesterStart: semesterStart)
        #expect(summary.todayCompleted == 0)
        #expect(summary.todayRemaining == 0)
    }
}
