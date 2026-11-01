import Foundation
import Testing
@testable import ScheduleCore

struct ImportPlannerTests {
    func course(_ title: String, day: Int, start: Int, end: Int, weeks: Set<Int> = []) -> ParsedCourse {
        ParsedCourse(title: title, weekday: day, startPeriod: start, endPeriod: end, weeks: weeks)
    }

    // MARK: 基本转换

    @Test func planAcceptsValidCourses() {
        let plan = ImportPlanner.plan(ParseOutcome(courses: [course("高数", day: 0, start: 1, end: 2)]),
                                      existing: [], totalWeeks: 20)
        #expect(plan.courses.count == 1)
        #expect(plan.isApplicable)
    }

    @Test func emptyParseIsNotApplicable() {
        let plan = ImportPlanner.plan(ParseOutcome(courses: []), existing: [], totalWeeks: 20)
        #expect(!plan.isApplicable)
    }

    @Test func dropsCoursesOutsideTerm() {
        // 周次全在 21–30，超出 20 周学期。
        let plan = ImportPlanner.plan(
            ParseOutcome(courses: [course("暑期课", day: 0, start: 1, end: 2, weeks: [21, 22])]),
            existing: [], totalWeeks: 20)
        #expect(plan.courses.isEmpty)
        #expect(plan.warnings.contains { $0.contains("忽略") })
    }

    @Test func clampsPartiallyOutOfRangeWeeks() {
        let plan = ImportPlanner.plan(
            ParseOutcome(courses: [course("高数", day: 0, start: 1, end: 2, weeks: [1, 2, 25])]),
            existing: [], totalWeeks: 20)
        #expect(plan.courses.first?.weeks == [1, 2])
    }

    @Test func rejectsInvalidWeekday() {
        let bad = ParsedCourse(title: "x", weekday: 7, startPeriod: 1, endPeriod: 2)
        let plan = ImportPlanner.plan(ParseOutcome(courses: [bad]), existing: [], totalWeeks: 20)
        #expect(plan.courses.isEmpty)
    }

    @Test func rejectsEndBeforeStart() {
        let bad = ParsedCourse(title: "x", weekday: 0, startPeriod: 4, endPeriod: 2)
        let plan = ImportPlanner.plan(ParseOutcome(courses: [bad]), existing: [], totalWeeks: 20)
        #expect(plan.courses.isEmpty)
    }

    @Test func keepsParseWarnings() {
        let plan = ImportPlanner.plan(ParseOutcome(courses: [course("高数", day: 0, start: 1, end: 2)],
                                                   warnings: ["原始提示"]),
                                      existing: [], totalWeeks: 20)
        #expect(plan.warnings.contains("原始提示"))
    }

    // MARK: 冲突

    @Test func detectsOverlappingSameDay() {
        let existing = [course("线性代数", day: 0, start: 1, end: 2)]
        let plan = ImportPlanner.plan(
            ParseOutcome(courses: [course("高数", day: 0, start: 2, end: 3)]),
            existing: existing, totalWeeks: 20)
        #expect(plan.conflicts.count == 1)
        #expect(plan.conflicts[0].existingTitle == "线性代数")
    }

    @Test func noConflictOnDifferentDays() {
        let existing = [course("线性代数", day: 1, start: 1, end: 2)]
        let plan = ImportPlanner.plan(
            ParseOutcome(courses: [course("高数", day: 0, start: 1, end: 2)]),
            existing: existing, totalWeeks: 20)
        #expect(plan.conflicts.isEmpty)
    }

    @Test func noConflictWhenPeriodsTouchButDoNotOverlap() {
        let existing = [course("线性代数", day: 0, start: 1, end: 2)]
        let plan = ImportPlanner.plan(
            ParseOutcome(courses: [course("高数", day: 0, start: 3, end: 4)]),
            existing: existing, totalWeeks: 20)
        #expect(plan.conflicts.isEmpty)
    }

    @Test func disjointWeeksAreNotAConflict() {
        // 同一时段但单双周分开，是正常排课。
        let existing = [course("实验", day: 0, start: 5, end: 6, weeks: [1, 3, 5])]
        let plan = ImportPlanner.plan(
            ParseOutcome(courses: [course("实验", day: 0, start: 5, end: 6, weeks: [2, 4, 6])]),
            existing: existing, totalWeeks: 20)
        #expect(plan.conflicts.isEmpty)
    }

    @Test func overlappingWeeksConflict() {
        let existing = [course("实验", day: 0, start: 5, end: 6, weeks: [1, 2, 3])]
        let plan = ImportPlanner.plan(
            ParseOutcome(courses: [course("实验", day: 0, start: 5, end: 6, weeks: [2, 3, 4])]),
            existing: existing, totalWeeks: 20)
        #expect(plan.conflicts.count == 1)
    }

    @Test func conflictDetailNamesWeekdayAndPeriods() {
        let existing = [course("线性代数", day: 2, start: 3, end: 4)]
        let plan = ImportPlanner.plan(
            ParseOutcome(courses: [course("高数", day: 2, start: 3, end: 4)]),
            existing: existing, totalWeeks: 20)
        #expect(plan.conflicts[0].detail.contains("周三"))
        #expect(plan.conflicts[0].detail.contains("3-4"))
    }

    // MARK: 替换计数

    @Test func countsReplacedCourses() {
        let existing = [course("高等数学", day: 0, start: 1, end: 2)]
        let plan = ImportPlanner.plan(
            ParseOutcome(courses: [course("高等数学", day: 0, start: 1, end: 2)]),
            existing: existing, totalWeeks: 20)
        #expect(plan.replacedCount == 1)
    }

    @Test func differentTimeIsNotReplacement() {
        let existing = [course("高等数学", day: 0, start: 1, end: 2)]
        let plan = ImportPlanner.plan(
            ParseOutcome(courses: [course("高等数学", day: 3, start: 1, end: 2)]),
            existing: existing, totalWeeks: 20)
        #expect(plan.replacedCount == 0)
    }

    // MARK: 摘要

    @Test func summaryMentionsCounts() {
        let existing = [course("线性代数", day: 0, start: 1, end: 2)]
        let plan = ImportPlanner.plan(
            ParseOutcome(courses: [course("高等数学", day: 0, start: 1, end: 2)]),
            existing: existing, totalWeeks: 20)
        #expect(plan.summary.contains("1 门课程"))
        #expect(plan.summary.contains("1 处时间重叠"))
    }

    @Test func weekdayNamesAreChinese() {
        #expect(ImportPlanner.weekdayName(0) == "一")
        #expect(ImportPlanner.weekdayName(6) == "日")
        #expect(ImportPlanner.weekdayName(9) == "?")
    }
}

/// 节次数量可配置后的规划行为。
struct ImportPlannerPeriodRangeTests {
    func course(_ title: String, start: Int, end: Int) -> ParsedCourse {
        ParsedCourse(title: title, weekday: 0, startPeriod: start, endPeriod: end)
    }

    @Test func acceptsCoursesWithinConfiguredPeriods() {
        let plan = ImportPlanner.plan(ParseOutcome(courses: [course("第12节", start: 11, end: 12)]),
                                      existing: [], totalWeeks: 20, periodCount: 14)
        #expect(plan.courses.count == 1)
    }

    @Test func rejectsCoursesBeyondConfiguredPeriods() {
        let plan = ImportPlanner.plan(ParseOutcome(courses: [course("第15节", start: 15, end: 16)]),
                                      existing: [], totalWeeks: 20, periodCount: 14)
        #expect(plan.courses.isEmpty)
        #expect(plan.warnings.contains { $0.contains("14 节") })
    }

    @Test func warningExplainsHowToFix() {
        let plan = ImportPlanner.plan(ParseOutcome(courses: [course("超范围", start: 13, end: 13)]),
                                      existing: [], totalWeeks: 20, periodCount: 10)
        // 提示必须告诉用户去哪里改，否则只知道失败不知道怎么办。
        #expect(plan.warnings.contains { $0.contains("学期与作息") })
    }

    @Test func defaultPeriodCountIsTen() {
        // 未显式传参时保持原行为，避免破坏既有调用点。
        let fits = ImportPlanner.plan(ParseOutcome(courses: [course("第10节", start: 10, end: 10)]),
                                      existing: [], totalWeeks: 20)
        #expect(fits.courses.count == 1)
        let overflows = ImportPlanner.plan(ParseOutcome(courses: [course("第11节", start: 11, end: 11)]),
                                           existing: [], totalWeeks: 20)
        #expect(overflows.courses.isEmpty)
    }
}
