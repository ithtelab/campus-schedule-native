import Foundation
import Testing
@testable import ScheduleCore

struct TimetableTextParserTests {

    // MARK: 周次

    @Test func parsesSimpleWeekRange() {
        #expect(TimetableTextParser.parseWeeks("1-16周") == Set(1...16))
        #expect(TimetableTextParser.parseWeeks("第1-16周") == Set(1...16))
    }

    @Test func parsesOddAndEvenWeeks() {
        #expect(TimetableTextParser.parseWeeks("1-8周(单)") == Set([1, 3, 5, 7]))
        #expect(TimetableTextParser.parseWeeks("1-8周(双)") == Set([2, 4, 6, 8]))
        #expect(TimetableTextParser.parseWeeks("1-8单周") == Set([1, 3, 5, 7]))
    }

    @Test func parsesDiscontinuousWeeks() {
        #expect(TimetableTextParser.parseWeeks("1,3,5周") == Set([1, 3, 5]))
        #expect(TimetableTextParser.parseWeeks("1-4,6-8周") == Set([1, 2, 3, 4, 6, 7, 8]))
    }

    @Test func parsesChineseTildeAndFullWidthComma() {
        #expect(TimetableTextParser.parseWeeks("1～8周") == Set(1...8))
        #expect(TimetableTextParser.parseWeeks("1，3，5周") == Set([1, 3, 5]))
    }

    @Test func weeksWithoutMarkerReturnNil() {
        // 教室号不能当成周次。
        #expect(TimetableTextParser.parseWeeks("A302") == nil)
        #expect(TimetableTextParser.parseWeeks("教学楼 205") == nil)
        #expect(TimetableTextParser.parseWeeks("") == nil)
    }

    @Test func weeksMentionedButUnreadableReturnsEmpty() {
        #expect(TimetableTextParser.parseWeeks("每周") == Set())
    }

    @Test func clampsToTotalWeeks() {
        let result = TimetableTextParser.parseWeeks("1-30周", totalWeeks: 20)
        #expect(result?.contains(21) == false)
        #expect(result?.contains(20) == true)
    }

    // MARK: 节次

    @Test func parsesPeriodRanges() {
        #expect(TimetableTextParser.parsePeriods("第1-2节")?.start == 1)
        #expect(TimetableTextParser.parsePeriods("第1-2节")?.end == 2)
        #expect(TimetableTextParser.parsePeriods("3-4节")?.end == 4)
    }

    @Test func parsesSinglePeriod() {
        #expect(TimetableTextParser.parsePeriods("第5节")?.start == 5)
        #expect(TimetableTextParser.parsePeriods("第5节")?.end == 5)
    }

    @Test func parsesCommaSeparatedPeriods() {
        #expect(TimetableTextParser.parsePeriods("1,2节")?.end == 2)
    }

    @Test func rejectsUnreasonablePeriods() {
        #expect(TimetableTextParser.parsePeriods("第99节") == nil)
        #expect(TimetableTextParser.parsePeriods("数学") == nil)
    }

    // MARK: 星期

    @Test func parsesAllWeekdayForms() {
        #expect(TimetableTextParser.parseWeekday("周一") == 0)
        #expect(TimetableTextParser.parseWeekday("星期一") == 0)
        #expect(TimetableTextParser.parseWeekday("礼拜三") == 2)
        #expect(TimetableTextParser.parseWeekday("周五") == 4)
        #expect(TimetableTextParser.parseWeekday("星期日") == 6)
        #expect(TimetableTextParser.parseWeekday("周天") == 6)
        #expect(TimetableTextParser.parseWeekday("Sun") == 6)
    }

    @Test func unknownWeekdayReturnsNil() {
        #expect(TimetableTextParser.parseWeekday("数学") == nil)
        #expect(TimetableTextParser.parseWeekday("") == nil)
    }

    // MARK: 单元格

    @Test func parsesMultiLineCell() {
        let cell = "高等数学\n陈老师\n教学楼A302\n1-16周"
        let course = TimetableTextParser.parseCourseCell(cell)
        #expect(course?.title == "高等数学")
        #expect(course?.teacher == "陈老师")
        #expect(course?.room == "教学楼A302")
        #expect(course?.weeks == Set(1...16))
    }

    @Test func parsesCellWithRoomBeforeWeeks() {
        let cell = "大学英语\nB205\n1-8周(单)"
        let course = TimetableTextParser.parseCourseCell(cell)
        #expect(course?.title == "大学英语")
        #expect(course?.room == "B205")
        #expect(course?.weeks == Set([1, 3, 5, 7]))
    }

    @Test func singleLineCellKeepsTitle() {
        let course = TimetableTextParser.parseCourseCell("体育")
        #expect(course?.title == "体育")
    }

    @Test func emptyCellHasNoCourse() {
        #expect(TimetableTextParser.parseCourseCell("") == nil)
        #expect(TimetableTextParser.parseCourseCell("   \n  ") == nil)
    }

    @Test func recognisesRoomShapes() {
        #expect(TimetableTextParser.looksLikeRoom("教学楼 A302"))
        #expect(TimetableTextParser.looksLikeRoom("实验楼 · 502"))
        #expect(TimetableTextParser.looksLikeRoom("A302"))
        #expect(TimetableTextParser.looksLikeRoom("东区体育馆"))
        #expect(!TimetableTextParser.looksLikeRoom("高等数学"))
    }

    // MARK: 网格

    func grid() -> [[String]] {
        [
            ["节次", "周一", "周二", "周三", "周四", "周五"],
            ["第1-2节", "高等数学\n陈老师\nA302\n1-16周", "", "线性代数\n李老师\nB205\n1-8周", "", ""],
            ["第3-4节", "", "大学英语\n林老师\nB205\n1-16周", "", "", "程序设计\n王老师\n实验楼502\n1-12周"],
        ]
    }

    @Test func parsesGridWithHeaderRow() {
        let outcome = TimetableTextParser.parseGrid(grid())
        #expect(outcome.courses.count == 3)
        let math = outcome.courses.first { $0.title == "高等数学" }
        #expect(math?.weekday == 0)
        #expect(math?.startPeriod == 1)
        #expect(math?.endPeriod == 2)
        #expect(math?.room == "A302")
    }

    @Test func gridMapsColumnsToWeekdays() {
        let outcome = TimetableTextParser.parseGrid(grid())
        let english = outcome.courses.first { $0.title == "大学英语" }
        #expect(english?.weekday == 1)   // 周二
        #expect(english?.startPeriod == 3)
        let programming = outcome.courses.first { $0.title == "程序设计" }
        #expect(programming?.weekday == 4)  // 周五
    }

    @Test func gridIgnoresFirstColumnWithoutWeekday() {
        let outcome = TimetableTextParser.parseGrid(grid())
        // 「第1-2节」这一列不应被当成课程。
        #expect(!outcome.courses.contains { $0.title.contains("节") })
    }

    @Test func gridWithoutHeaderFails() {
        let outcome = TimetableTextParser.parseGrid([["随便", "一些"], ["内容", "而已"]])
        #expect(outcome.courses.isEmpty)
        #expect(!outcome.warnings.isEmpty)
    }

    @Test func gridWithOnlyHeaderFails() {
        let outcome = TimetableTextParser.parseGrid([["节次", "周一", "周二", "周三"]])
        #expect(outcome.courses.isEmpty)
    }

    @Test func gridCellWeekdayOverridesColumn() {
        // 有些系统在单元格里写死星期，此时应以单元格为准。
        let rows: [[String]] = [
            ["节次", "周一", "周二", "周三"],
            ["第1-2节", "", "数学\n周二\n1-16周", ""],
        ]
        let outcome = TimetableTextParser.parseGrid(rows)
        #expect(outcome.courses.first?.weekday == 1)
    }

    @Test func duplicateCellsAreMerged() {
        let cell = "高等数学\nA302\n1-16周"
        let rows: [[String]] = [
            ["节次", "周一", "周二", "周三"],
            ["第1-2节", cell, cell, ""],
        ]
        let outcome = TimetableTextParser.parseGrid(rows)
        // 两个不同星期列上完全相同的内容是真实的两节课，不能合并。
        #expect(outcome.courses.count == 2)
        #expect(Set(outcome.courses.map(\.weekday)) == [0, 1])
    }

    // MARK: 自由文本

    @Test func parsesLineBasedText() {
        let text = """
        周一 第1-2节 高等数学 陈老师 A302 1-16周
        周三 第3-4节 线性代数 李老师 B205 1-8周
        """
        let outcome = TimetableTextParser.parseLines(text)
        #expect(outcome.courses.count == 2)
        #expect(outcome.courses[0].weekday == 0)
        #expect(outcome.courses[1].weekday == 2)
    }

    @Test func ignoresLinesWithoutWeekdayOrPeriod() {
        let text = """
        欢迎使用教务系统
        课表查询
        周一 第1-2节 高等数学
        """
        let outcome = TimetableTextParser.parseLines(text)
        #expect(outcome.courses.count == 1)
    }

    @Test func emptyTextYieldsNoCoursesWithWarning() {
        let outcome = TimetableTextParser.parseLines("没有课表内容")
        #expect(outcome.courses.isEmpty)
        #expect(!outcome.warnings.isEmpty)
    }

    @Test func lineTextDeduplicates() {
        let text = """
        周一 第1-2节 高等数学 A302 1-16周
        周一 第1-2节 高等数学 A302 1-16周
        """
        let outcome = TimetableTextParser.parseLines(text)
        #expect(outcome.courses.count == 1)
    }
}
