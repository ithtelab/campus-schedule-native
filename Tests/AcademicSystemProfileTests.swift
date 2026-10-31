import Foundation
import Testing
@testable import ScheduleCore

struct AcademicSystemProfileTests {

    // MARK: 内嵌 JSON 发现

    @Test func findsVarAssignment() {
        let html = """
        <script>var kbList = [{"courseName":"高等数学","weekday":1,"startSection":1,"endSection":2}];</script>
        """
        let found = AcademicSystemProfile.embeddedJSON(from: html)
        #expect(!found.isEmpty)
        #expect(found[0].contains("高等数学"))
    }

    @Test func findsWindowAssignment() {
        let html = """
        <script>window.scheduleData = [{"kcmc":"线性代数","xqj":2,"jcs":3,"jce":4}];</script>
        """
        #expect(!AcademicSystemProfile.embeddedJSON(from: html).isEmpty)
    }

    @Test func ignoresShortFragments() {
        #expect(AcademicSystemProfile.embeddedJSON(from: "var courseData = [1];").isEmpty)
    }

    @Test func noScriptYieldsNothing() {
        #expect(AcademicSystemProfile.embeddedJSON(from: "<table><tr><td>x</td></tr></table>").isEmpty)
    }

    // MARK: 从内嵌 JSON 提取

    @Test func parsesZhengfangStyleFields() throws {
        let json = """
        [{"courseName":"高等数学","weekday":1,"startSection":1,"endSection":2,
          "room":"A302","teacher":"陈老师","weeks":"1-16"}]
        """
        let outcome = try #require(AcademicSystemProfile.courses(fromEmbeddedJSON: json, totalWeeks: 20))
        #expect(outcome.courses.count == 1)
        let course = outcome.courses[0]
        #expect(course.title == "高等数学")
        #expect(course.weekday == 0)   // 1 = 周一
        #expect(course.startPeriod == 1)
        #expect(course.endPeriod == 2)
        #expect(course.room == "A302")
        #expect(course.weeks == Set(1...16))
    }

    @Test func parsesURPStyleFields() throws {
        let json = """
        [{"kcmc":" линейная","xqj":3,"jcs":5,"jce":6,"cdmc":"B205","xm":"李老师"}]
        """
        let outcome = try #require(AcademicSystemProfile.courses(fromEmbeddedJSON: json, totalWeeks: 20))
        #expect(outcome.courses.first?.weekday == 2)
        #expect(outcome.courses.first?.startPeriod == 5)
        #expect(outcome.courses.first?.room == "B205")
        #expect(outcome.courses.first?.teacher == "李老师")
    }

    @Test func zeroBasedWeekdayIsKept() throws {
        let json = """
        [{"courseName":"体育","weekday":0,"startSection":1,"endSection":2}]
        """
        let outcome = try #require(AcademicSystemProfile.courses(fromEmbeddedJSON: json, totalWeeks: 20))
        #expect(outcome.courses.first?.weekday == 0)
    }

    @Test func missingEndSectionDefaultsToTwoPeriods() throws {
        let json = """
        [{"courseName":"体育","weekday":1,"startSection":3}]
        """
        let outcome = try #require(AcademicSystemProfile.courses(fromEmbeddedJSON: json, totalWeeks: 20))
        #expect(outcome.courses.first?.startPeriod == 3)
        #expect(outcome.courses.first?.endPeriod == 4)
    }

    @Test func missingWeeksMeansWholeTerm() throws {
        let json = """
        [{"courseName":"体育","weekday":1,"startSection":1,"endSection":2}]
        """
        let outcome = try #require(AcademicSystemProfile.courses(fromEmbeddedJSON: json, totalWeeks: 20))
        #expect(outcome.courses.first?.weeks.isEmpty == true)
    }

    @Test func skipsIncompleteRows() throws {
        let json = """
        [{"courseName":"完整","weekday":1,"startSection":1,"endSection":2},
         {"courseName":"缺节次","weekday":1}]
        """
        let outcome = try #require(AcademicSystemProfile.courses(fromEmbeddedJSON: json, totalWeeks: 20))
        #expect(outcome.courses.count == 1)
    }

    @Test func invalidWeekdayIsSkipped() throws {
        let json = """
        [{"courseName":"坏","weekday":99,"startSection":1,"endSection":2},
         {"courseName":"好","weekday":1,"startSection":1,"endSection":2}]
        """
        let outcome = try #require(AcademicSystemProfile.courses(fromEmbeddedJSON: json, totalWeeks: 20))
        #expect(outcome.courses.count == 1)
        #expect(outcome.courses.first?.title == "好")
    }

    @Test func noCoursesReturnsNil() {
        #expect(AcademicSystemProfile.courses(fromEmbeddedJSON: #"[{"foo":"bar"}]"#, totalWeeks: 20) == nil)
        #expect(AcademicSystemProfile.courses(fromEmbeddedJSON: "not json", totalWeeks: 20) == nil)
    }

    @Test func clampsWeeksToTerm() throws {
        let json = """
        [{"courseName":"高数","weekday":1,"startSection":1,"endSection":2,"weeks":"1-30"}]
        """
        let outcome = try #require(AcademicSystemProfile.courses(fromEmbeddedJSON: json, totalWeeks: 20))
        #expect(outcome.courses.first?.weeks == Set(1...20))
    }

    // MARK: 页面特征

    @Test func detectsScheduleMarkers() {
        #expect(AcademicSystemProfile.hasEmbeddedSchedule("<div>kbList</div>"))
        #expect(AcademicSystemProfile.hasEmbeddedSchedule("<span>timetable</span>"))
        #expect(!AcademicSystemProfile.hasEmbeddedSchedule("<html><body>登录</body></html>"))
    }
}
