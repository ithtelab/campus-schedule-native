import Foundation
import Testing
@testable import ScheduleCore

struct TeachingClassTests {
    // MARK: 去重

    @Test func sameCourseDifferentClassIsNotMerged() {
        // 教师端典型情况：同一门课、同一时段、同一教室，两个教学班。
        let a = ParsedCourse(title: "高等数学", teacher: "陈老师", room: "A302",
                             weekday: 0, startPeriod: 1, endPeriod: 2, weeks: [1, 2],
                             teachingClass: "2026 级 1 班")
        let b = ParsedCourse(title: "高等数学", teacher: "陈老师", room: "A302",
                             weekday: 0, startPeriod: 1, endPeriod: 2, weeks: [1, 2],
                             teachingClass: "2026 级 2 班")
        let result = TimetableTextParser.deduplicate([a, b])
        #expect(result.count == 2)
    }

    @Test func fullyIdenticalCoursesStillDeduplicated() {
        let a = ParsedCourse(title: "高等数学", weekday: 0, startPeriod: 1, endPeriod: 2,
                             weeks: [1, 2], teachingClass: "2026 级 1 班")
        let result = TimetableTextParser.deduplicate([a, a])
        #expect(result.count == 1)
    }

    @Test func studentCoursesWithoutClassStillDeduplicate() {
        // 学生端没有教学班，行为必须与改动前一致。
        let a = ParsedCourse(title: "高等数学", weekday: 0, startPeriod: 1, endPeriod: 2, weeks: [1, 2])
        let result = TimetableTextParser.deduplicate([a, a])
        #expect(result.count == 1)
    }

    // MARK: 导入方案

    @Test func sameSlotDifferentClassIsNotReplaced() {
        let existing = [ParsedCourse(title: "高等数学", weekday: 0, startPeriod: 1, endPeriod: 2,
                                     weeks: [1], teachingClass: "2026 级 1 班")]
        let incoming = ParsedCourse(title: "高等数学", weekday: 0, startPeriod: 1, endPeriod: 2,
                                    weeks: [1], teachingClass: "2026 级 2 班")
        #expect(ImportPlanner.replacementIndex(for: incoming, in: existing, totalWeeks: 20) == nil)
    }

    @Test func sameClassStillReplaces() {
        let existing = [ParsedCourse(title: "高等数学", weekday: 0, startPeriod: 1, endPeriod: 2,
                                     weeks: [1], teachingClass: "2026 级 1 班")]
        let incoming = ParsedCourse(title: "高等数学", weekday: 0, startPeriod: 1, endPeriod: 2,
                                    weeks: [1], teachingClass: "2026 级 1 班")
        #expect(ImportPlanner.replacementIndex(for: incoming, in: existing, totalWeeks: 20) == 0)
    }

    @Test func differentClassesDoNotMergeInPlan() {
        let parsed = ParseOutcome(courses: [
            ParsedCourse(title: "高等数学", weekday: 0, startPeriod: 1, endPeriod: 2,
                         weeks: [1], teachingClass: "2026 级 1 班"),
            ParsedCourse(title: "高等数学", weekday: 0, startPeriod: 1, endPeriod: 2,
                         weeks: [1], teachingClass: "2026 级 2 班"),
        ])
        let plan = ImportPlanner.plan(parsed, existing: [], totalWeeks: 20, periodCount: 10)
        #expect(plan.courses.count == 2)
    }

    // MARK: 内嵌 JSON

    @Test func readsTeachingClassFromTeacherJSON() throws {
        let json = """
        [{"kcmc":"高等数学","jxbmc":"2026 级 1 班","xqj":1,"jcs":1,"jce":2,
          "jsxm":"陈老师","cdmc":"A302","zcd":[1,2,3]}]
        """
        let outcome = try #require(AcademicSystemProfile.courses(fromEmbeddedJSON: json, totalWeeks: 20))
        #expect(outcome.courses.first?.teachingClass == "2026 级 1 班")
        #expect(outcome.courses.first?.teacher == "陈老师")
    }

    @Test func studentJSONHasNoTeachingClass() throws {
        let json = """
        [{"courseName":"大学英语","xqj":2,"startNode":3,"endNode":4,
          "teacher":"林老师","room":"B205","weeks":[1,2,3]}]
        """
        let outcome = try #require(AcademicSystemProfile.courses(fromEmbeddedJSON: json, totalWeeks: 20))
        #expect(outcome.courses.first?.teachingClass == "")
    }

    @Test func teacherFieldIsNotMistakenForClass() throws {
        // 学生端只给教师姓名，不能顺着 classKeys 把教师当成教学班。
        let json = """
        [{"kcmc":"线性代数","xqj":1,"jcs":3,"jce":4,"jsxm":"李老师","cdmc":"B201","zcd":[1]}]
        """
        let outcome = try #require(AcademicSystemProfile.courses(fromEmbeddedJSON: json, totalWeeks: 20))
        #expect(outcome.courses.first?.teachingClass == "")
        #expect(outcome.courses.first?.teacher == "李老师")
    }

    @Test func readsAlternativeClassKeys() throws {
        let json = """
        [{"kcmc":"物理","skbjmc":"物理 A 班","xqj":3,"jcs":5,"jce":6,"zcd":[4]}]
        """
        let outcome = try #require(AcademicSystemProfile.courses(fromEmbeddedJSON: json, totalWeeks: 20))
        #expect(outcome.courses.first?.teachingClass == "物理 A 班")
    }

    @Test func blankClassKeyFallsBackToEmpty() throws {
        let json = """
        [{"kcmc":"化学","jxbmc":"   ","xqj":1,"jcs":1,"jce":2,"zcd":[1]}]
        """
        let outcome = try #require(AcademicSystemProfile.courses(fromEmbeddedJSON: json, totalWeeks: 20))
        #expect(outcome.courses.first?.teachingClass == "")
    }
}

struct TeachingClassArchiveTests {
    func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9))!
    }

    @Test func teachingClassRoundTripsThroughArchive() throws {
        let course = ArchivedCourse(id: "c1", title: "高等数学", room: "A302", teacher: "陈老师",
                                    weekday: 0, startPeriod: 1, endPeriod: 2, color: "blue",
                                    weeks: [1, 2], teachingClass: "2026 级 1 班")
        let archive = ScheduleArchive(semesters: [
            ArchivedSemester(id: "t1", name: "学期", startDate: day(2027, 2, 22), totalWeeks: 20,
                             periods: [ArchivedPeriod(index: 1, start: "08:00", end: "08:45"),
                                       ArchivedPeriod(index: 2, start: "08:50", end: "09:35")],
                             courses: [course], exceptions: []),
        ])
        let decoded = try ScheduleArchive.decoded(from: archive.encoded())
        #expect(decoded.semesters.first?.courses.first?.teachingClass == "2026 级 1 班")
    }

    @Test func oldArchiveWithoutTeachingClassStillDecodes() throws {
        let json = """
        {"schema":1,"exportedAt":"2027-01-01T00:00:00.000Z","semesters":[{
          "id":"t1","name":"学期","startDate":"2027-02-22T01:00:00.000Z","totalWeeks":20,
          "periods":[{"index":1,"start":"08:00","end":"08:45"}],
          "courses":[{"id":"c1","title":"高等数学","room":"A302","teacher":"陈老师",
                      "weekday":0,"startPeriod":1,"endPeriod":1,"color":"blue",
                      "weeks":[1],"remindersEnabled":true}],
          "exceptions":[]}]}
        """
        let decoded = try ScheduleArchive.decoded(from: Data(json.utf8))
        // 旧备份没有教学班字段，解码必须成功并且缺省为空。
        #expect(decoded.semesters.first?.courses.first?.teachingClass == nil)
        #expect(decoded.semesters.first?.courses.first?.title == "高等数学")
    }

    @Test func summaryStillWorksWithTeachingClasses() {
        let course = ArchivedCourse(id: "c1", title: "高等数学", room: "A302", teacher: "陈老师",
                                    weekday: 0, startPeriod: 1, endPeriod: 2, color: "blue",
                                    weeks: [1], teachingClass: "2026 级 1 班")
        let archive = ScheduleArchive(semesters: [
            ArchivedSemester(id: "t1", name: "学期", startDate: day(2027, 2, 22), totalWeeks: 20,
                             periods: [ArchivedPeriod(index: 1, start: "08:00", end: "08:45")],
                             courses: [course], exceptions: []),
        ])
        #expect(archive.summary.contains("1 门课程"))
    }
}
