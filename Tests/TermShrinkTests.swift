import Foundation
import Testing
@testable import ScheduleCore

/// 学期设置被缩小时，课程数据必须同步收敛，否则导出与同步会因校验失败而中断。
struct TermShrinkTests {
    let calendar = ScheduleRules.calendar
    var semesterStart: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))!
    }
    func periods(_ count: Int) -> [ArchivedPeriod] {
        (1...count).map { ArchivedPeriod(index: $0, start: "08:00", end: "08:45") }
    }
    func course(_ title: String, weeks: [Int], start: Int = 1, end: Int = 2) -> ArchivedCourse {
        ArchivedCourse(id: title, title: title, room: "A302", teacher: "",
                       weekday: 0, startPeriod: start, endPeriod: end,
                       color: "blue", weeks: weeks)
    }

    // MARK: 周次裁剪后的备份必须仍可导出

    @Test func archiveWithWeeksBeyondTermIsRejected() {
        // 这验证的是「如果不裁剪会发生什么」——导出会直接失败。
        let term = ArchivedSemester(id: "t", name: "学期", startDate: semesterStart, totalWeeks: 16,
                                    periods: periods(10),
                                    courses: [course("超周", weeks: [1, 18])],
                                    exceptions: [])
        #expect(throws: ArchiveError.weeksOutsideTerm("超周", "学期")) {
            try ScheduleArchive(semesters: [term]).validated()
        }
    }

    @Test func clampingWeeksMakesArchiveValid() throws {
        let term = ArchivedSemester(id: "t", name: "学期", startDate: semesterStart, totalWeeks: 16,
                                    periods: periods(10),
                                    courses: [course("已裁剪", weeks: [1, 2])],
                                    exceptions: [])
        let archive = try ScheduleArchive(semesters: [term]).validated()
        #expect(archive.courseCount == 1)
    }

    // MARK: 节次裁剪后的备份必须仍可导出

    @Test func archiveWithPeriodBeyondTableIsRejected() {
        let term = ArchivedSemester(id: "t", name: "学期", startDate: semesterStart, totalWeeks: 20,
                                    periods: periods(8),
                                    courses: [course("超节次", weeks: [1], start: 9, end: 10)],
                                    exceptions: [])
        #expect(throws: ArchiveError.self) {
            try ScheduleArchive(semesters: [term]).validated()
        }
    }

    @Test func archiveWithPeriodInsideTablePasses() throws {
        let term = ArchivedSemester(id: "t", name: "学期", startDate: semesterStart, totalWeeks: 20,
                                    periods: periods(8),
                                    courses: [course("八节内", weeks: [1], start: 7, end: 8)],
                                    exceptions: [])
        let archive = try ScheduleArchive(semesters: [term]).validated()
        #expect(archive.courseCount == 1)
    }

    // MARK: 节次数量范围

    @Test func supportsCommonSchoolPeriodCounts() throws {
        // 国内高校常见 8 到 14 节，都应能正常导出。
        for count in [8, 10, 12, 14] {
            let term = ArchivedSemester(id: "t\(count)", name: "学期", startDate: semesterStart,
                                        totalWeeks: 20, periods: periods(count),
                                        courses: [course("课\(count)", weeks: [1], start: 1, end: 2)],
                                        exceptions: [])
            let archive = try ScheduleArchive(semesters: [term]).validated()
            #expect(archive.courseCount == 1)
        }
    }

    @Test func rejectsEmptyPeriodTable() {
        let term = ArchivedSemester(id: "t", name: "学期", startDate: semesterStart, totalWeeks: 20,
                                    periods: [], courses: [course("x", weeks: [1])], exceptions: [])
        #expect(throws: ArchiveError.emptyPeriods("学期")) {
            try ScheduleArchive(semesters: [term]).validated()
        }
    }
}
