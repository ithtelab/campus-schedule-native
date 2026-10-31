import Foundation
import Testing
@testable import ScheduleCore

struct ShareCodeParserTests {

    // MARK: 超星

    let chaoxing = """
    {"data":[{"name":"高等数学","teacherName":"陈老师","location":"A302",
      "dayOfWeek":1,"beginNumber":1,"length":2,"weeks":"1-16"},
      {"name":"大学英语","teacherName":"林老师","location":"B205",
      "dayOfWeek":3,"beginNumber":3,"length":2,"weeks":"1-16"}]}
    """

    @Test func parsesChaoxingShare() throws {
        let outcome = try #require(ShareCodeParser.parse(chaoxing))
        #expect(outcome.courses.count == 2)
        let math = outcome.courses.first { $0.title == "高等数学" }
        #expect(math?.weekday == 0)      // 超星 1 = 周一
        #expect(math?.startPeriod == 1)
        #expect(math?.endPeriod == 2)
        #expect(math?.room == "A302")
        #expect(math?.teacher == "陈老师")
        #expect(math?.weeks == Set(1...16))
    }

    @Test func chaoxingMapsThirdDayToWednesday() throws {
        let outcome = try #require(ShareCodeParser.parse(chaoxing))
        let english = outcome.courses.first { $0.title == "大学英语" }
        #expect(english?.weekday == 2)
        #expect(english?.startPeriod == 3)
    }

    @Test func ignoresChaoxingRowsMissingFields() throws {
        let partial = """
        {"data":[{"name":"完整","dayOfWeek":2,"beginNumber":5,"length":2,"weeks":"1-8"},
                 {"name":"缺时长","dayOfWeek":2,"beginNumber":5,"weeks":"1-8"}]}
        """
        let outcome = try #require(ShareCodeParser.parse(partial))
        #expect(outcome.courses.count == 1)
        #expect(!outcome.warnings.isEmpty)
    }

    @Test func acceptsArrayWeeks() throws {
        let json = """
        {"data":[{"name":"高数","dayOfWeek":1,"beginNumber":1,"length":2,"weeks":[1,3,5]}]}
        """
        let outcome = try #require(ShareCodeParser.parse(json))
        #expect(outcome.courses.first?.weeks == [1, 3, 5])
    }

    // MARK: WakeUp

    let wakeUp = """
    {"courses":[{"courseName":"线性代数","teacher":"李老师","room":"B205",
      "day":2,"startNode":2,"step":2,"week":1},
      {"courseName":"程序设计","teacher":"王老师","room":"实验楼502",
      "day":5,"startNode":0,"step":2,"week":1}]}
    """

    @Test func parsesWakeUpShare() throws {
        let outcome = try #require(ShareCodeParser.parse(wakeUp))
        #expect(outcome.courses.count == 2)
        let algebra = outcome.courses.first { $0.title == "线性代数" }
        #expect(algebra?.weekday == 1)          // WakeUp 2 = 周二
        #expect(algebra?.startPeriod == 3)      // startNode 2（0 起）→ 第 3 节
        #expect(algebra?.endPeriod == 4)
    }

    @Test func wakeUpMapsFifthDayToFriday() throws {
        let outcome = try #require(ShareCodeParser.parse(wakeUp))
        let programming = outcome.courses.first { $0.title == "程序设计" }
        #expect(programming?.weekday == 4)
    }

    // MARK: 容错

    @Test func plainTextIsNotAShareCode() {
        #expect(ShareCodeParser.parse("周一 第1-2节 高等数学") == nil)
    }

    @Test func emptyInputReturnsNil() {
        #expect(ShareCodeParser.parse("") == nil)
        #expect(ShareCodeParser.parse("   ") == nil)
    }

    @Test func invalidJSONReturnsNil() {
        #expect(ShareCodeParser.parse("{不是 JSON}") == nil)
    }

    @Test func jsonWithoutCourseFieldsReturnsNil() {
        #expect(ShareCodeParser.parse(#"{"foo":"bar"}"#) == nil)
    }

    @Test func extractsJSONFromSurroundingText() throws {
        // 分享码常带一段说明文字，需要能定位到 JSON 本体。
        let wrapped = "复制这段分享码到 App：\n" + chaoxing + "\n有效期 7 天"
        let outcome = try #require(ShareCodeParser.parse(wrapped))
        #expect(outcome.courses.count == 2)
    }

    @Test func clampsShareWeeksToTerm() throws {
        let json = """
        {"data":[{"name":"高数","dayOfWeek":1,"beginNumber":1,"length":2,"weeks":"1-30"}]}
        """
        let outcome = try #require(ShareCodeParser.parse(json, totalWeeks: 20))
        #expect(outcome.courses.first?.weeks == Set(1...20))
    }

    @Test func numbersAsStringsAreAccepted() throws {
        let json = """
        {"data":[{"name":"高数","dayOfWeek":"1","beginNumber":"1","length":"2","weeks":"1-8"}]}
        """
        let outcome = try #require(ShareCodeParser.parse(json))
        #expect(outcome.courses.count == 1)
        #expect(outcome.courses.first?.endPeriod == 2)
    }

    @Test func invalidWeekdayIsSkipped() throws {
        let json = """
        {"data":[{"name":"坏数据","dayOfWeek":9,"beginNumber":1,"length":2,"weeks":"1-8"},
                 {"name":"好的","dayOfWeek":1,"beginNumber":1,"length":2,"weeks":"1-8"}]}
        """
        let outcome = try #require(ShareCodeParser.parse(json))
        #expect(outcome.courses.count == 1)
        #expect(outcome.courses.first?.title == "好的")
    }
}
