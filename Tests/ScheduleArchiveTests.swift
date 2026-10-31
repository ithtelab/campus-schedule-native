import Foundation
import Testing
@testable import ScheduleCore

struct ScheduleArchiveTests {
    let start = ScheduleRules.calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))!

    func periods(_ count: Int = 10) -> [ArchivedPeriod] {
        (1...count).map { index in
            ArchivedPeriod(index: index,
                           start: String(format: "%02d:00", 8 + index - 1),
                           end: String(format: "%02d:45", 8 + index - 1))
        }
    }

    func course(id: String = "c1", title: String = "高等数学", weekday: Int = 0,
                startPeriod: Int = 1, endPeriod: Int = 2, weeks: [Int] = [1, 2, 3]) -> ArchivedCourse {
        ArchivedCourse(id: id, title: title, room: "教学楼 A · 302", teacher: "陈老师",
                       weekday: weekday, startPeriod: startPeriod, endPeriod: endPeriod,
                       color: "blue", weeks: weeks)
    }

    func semester(courses: [ArchivedCourse] = [], exceptions: [ArchivedException] = [],
                  totalWeeks: Int = 20, periodCount: Int = 10) -> ArchivedSemester {
        ArchivedSemester(id: "term-1", name: "2026 秋季学期", startDate: start, totalWeeks: totalWeeks,
                         periods: periods(periodCount),
                         courses: courses.isEmpty ? [course()] : courses,
                         exceptions: exceptions)
    }

    func archive(_ semesters: [ArchivedSemester]) -> ScheduleArchive {
        ScheduleArchive(exportedAt: start, appVersion: "0.1.0", semesters: semesters)
    }

    // MARK: 往返

    @Test func roundTripPreservesEveryField() throws {
        let source = archive([semester(courses: [
            course(id: "a", title: "高等数学", weekday: 0, startPeriod: 1, endPeriod: 2, weeks: [1, 3, 5]),
            ArchivedCourse(id: "b", sourceID: "imported-9", title: "大学英语", room: "教学楼 B · 205",
                           teacher: "林老师", weekday: 3, startPeriod: 3, endPeriod: 4,
                           color: "purple", weeks: [2, 4], remindersEnabled: false)
        ], exceptions: [
            ArchivedException(id: "e1", courseID: "a", day: start.addingTimeInterval(86400),
                              cancelled: false, start: start.addingTimeInterval(90000),
                              end: start.addingTimeInterval(93000), room: "教学楼 C · 101")
        ])])

        let decoded = try ScheduleArchive.decoded(from: try source.encoded())
        #expect(decoded.schema == ScheduleArchive.currentSchema)
        #expect(decoded.semesters == source.semesters)
        #expect(decoded.courseCount == 2)
        #expect(decoded.semesters[0].exceptions[0].room == "教学楼 C · 101")
    }

    @Test func exportedJSONIsHumanReadable() throws {
        let data = try archive([semester()]).encoded()
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"schema\" : 1"))
        #expect(text.contains("高等数学"))
        #expect(text.contains(".000Z"))          // ISO 8601 时间，而不是浮点时间戳
        #expect(!text.contains("756000000"))     // Date 的 timeIntervalSinceReferenceDate
        #expect(text.contains("\"totalWeeks\" : 20"))
    }

    @Test func acceptsTimestampsWithoutFractionalSeconds() throws {
        let data = try #require("""
        {"schema":1,"exportedAt":"2026-09-07T00:00:00Z","semesters":[{
        "id":"t","name":"学期","startDate":"2026-09-07T00:00:00Z","totalWeeks":20,
        "periods":[{"index":1,"start":"08:00","end":"08:45"}],
        "courses":[{"id":"c","title":"课","room":"A","teacher":"T","weekday":0,
        "startPeriod":1,"endPeriod":1,"color":"blue","weeks":[1],"remindersEnabled":true}],
        "exceptions":[]}]}
        """.data(using: .utf8))
        let decoded = try ScheduleArchive.decoded(from: data)
        #expect(decoded.courseCount == 1)
    }

    // MARK: 版本

    @Test func rejectsFutureSchema() {
        var future = archive([semester()])
        future.schema = ScheduleArchive.currentSchema + 1
        #expect(throws: ArchiveError.unsupportedSchema(future.schema)) { try future.validated() }
    }

    @Test func rejectsZeroSchema() {
        var broken = archive([semester()])
        broken.schema = 0
        #expect(throws: ArchiveError.unsupportedSchema(0)) { try broken.validated() }
    }

    // MARK: 学期与节次

    @Test func rejectsEmptySemesters() {
        #expect(throws: ArchiveError.emptySemesterList) { try archive([]).validated() }
    }

    @Test func rejectsOutOfRangeTotalWeeks() {
        #expect(throws: ArchiveError.invalidTotalWeeks(0)) {
            try archive([semester(totalWeeks: 0)]).validated()
        }
        #expect(throws: ArchiveError.invalidTotalWeeks(54)) {
            try archive([semester(totalWeeks: 54)]).validated()
        }
    }

    @Test func rejectsMalformedPeriodTime() {
        var broken = semester()
        broken.periods[0] = ArchivedPeriod(index: 1, start: "8:00", end: "08:45")
        #expect(throws: ArchiveError.malformedTime("2026 秋季学期", "8:00")) {
            try archive([broken]).validated()
        }
    }

    @Test func rejectsOutOfRangeClockTime() {
        var broken = semester()
        broken.periods[0] = ArchivedPeriod(index: 1, start: "24:00", end: "08:45")
        #expect(throws: ArchiveError.malformedTime("2026 秋季学期", "24:00")) {
            try archive([broken]).validated()
        }
    }

    @Test func rejectsDuplicatePeriodIndex() {
        var broken = semester()
        broken.periods[1] = ArchivedPeriod(index: 1, start: "09:00", end: "09:45")
        #expect(throws: ArchiveError.duplicatePeriodIndex("2026 秋季学期", 1)) {
            try archive([broken]).validated()
        }
    }

    @Test func rejectsEmptyPeriods() {
        var broken = semester()
        broken.periods = []
        #expect(throws: ArchiveError.emptyPeriods("2026 秋季学期")) {
            try archive([broken]).validated()
        }
    }

    // MARK: 课程

    @Test func rejectsInvalidWeekday() {
        let bad = course(weekday: 7)
        #expect(throws: ArchiveError.invalidWeekday(bad.title, 7)) {
            try archive([semester(courses: [bad])]).validated()
        }
        let negative = course(weekday: -1)
        #expect(throws: ArchiveError.invalidWeekday(negative.title, -1)) {
            try archive([semester(courses: [negative])]).validated()
        }
    }

    @Test func rejectsEndPeriodBeforeStart() {
        let bad = course(startPeriod: 4, endPeriod: 2)
        #expect(throws: ArchiveError.invalidPeriodRange(bad.title, "2026 秋季学期")) {
            try archive([semester(courses: [bad])]).validated()
        }
    }

    @Test func rejectsPeriodBeyondDeclaredPeriods() {
        // 只有 5 个节次，却引用了第 8 节。
        let bad = course(startPeriod: 8, endPeriod: 8)
        let term = semester(courses: [bad], periodCount: 5)
        #expect(throws: ArchiveError.invalidPeriodRange(bad.title, "2026 秋季学期")) {
            try archive([term]).validated()
        }
    }

    @Test func rejectsWeeksOutsideTerm() {
        let bad = course(weeks: [1, 25])
        #expect(throws: ArchiveError.weeksOutsideTerm(bad.title, "2026 秋季学期")) {
            try archive([semester(courses: [bad], totalWeeks: 20)]).validated()
        }
    }

    @Test func rejectsEmptyWeekSet() {
        let bad = course(weeks: [])
        #expect(throws: ArchiveError.weeksOutsideTerm(bad.title, "2026 秋季学期")) {
            try archive([semester(courses: [bad])]).validated()
        }
    }

    @Test func rejectsDuplicateCourseID() {
        let duplicate = [course(id: "same"), course(id: "same", title: "另一门")]
        #expect(throws: ArchiveError.duplicateCourseID("same")) {
            try archive([semester(courses: duplicate)]).validated()
        }
    }

    @Test func rejectsArchiveWithoutAnyCourse() {
        var empty = semester()
        empty.courses = []
        #expect(throws: ArchiveError.emptySemesterList) { try archive([empty]).validated() }
    }

    // MARK: 调课记录

    @Test func rejectsExceptionForUnknownCourse() {
        let orphan = ArchivedException(id: "e1", courseID: "missing", day: start)
        #expect(throws: ArchiveError.exceptionWithoutCourse("missing")) {
            try archive([semester(exceptions: [orphan])]).validated()
        }
    }

    @Test func rejectsDuplicateExceptionID() {
        let single = course(id: "a")
        let duplicates = [ArchivedException(id: "same", courseID: "a", day: start),
                          ArchivedException(id: "same", courseID: "a", day: start.addingTimeInterval(86400))]
        #expect(throws: ArchiveError.duplicateExceptionID("same")) {
            try archive([semester(courses: [single], exceptions: duplicates)]).validated()
        }
    }

    // MARK: 多学期

    @Test func acceptsMultipleSemesters() throws {
        let first = semester()
        var second = semester()
        second.id = "term-2"
        second.name = "2027 春季学期"
        let validated = try archive([first, second]).validated()
        #expect(validated.semesters.count == 2)
        #expect(validated.courseCount == 2)
    }

    @Test func rejectsMoreSemestersThanSupported() {
        let terms = (1...5).map { index -> ArchivedSemester in
            var term = semester()
            term.id = "term-\(index)"
            return term
        }
        #expect(throws: ArchiveError.tooManySemesters(5)) { try archive(terms).validated() }
    }

    @Test func rejectsDuplicateSemesterID() {
        #expect(throws: ArchiveError.duplicateSemesterID("term-1")) {
            try archive([semester(), semester()]).validated()
        }
    }

    // MARK: 摘要

    @Test func summaryMentionsSemesterAndCounts() {
        let text = archive([semester()]).summary
        #expect(text.contains("2026 秋季学期"))
        #expect(text.contains("20 周"))
        #expect(text.contains("1 门课程"))
    }

    @Test func rejectsTruncatedJSON() throws {
        let data = try archive([semester()]).encoded()
        #expect(throws: (any Error).self) {
            _ = try ScheduleArchive.decoded(from: data.dropLast(40))
        }
    }
}
