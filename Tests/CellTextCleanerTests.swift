import Foundation
import Testing
@testable import ScheduleCore

struct CellTextCleanerTests {

    @Test func stripsTrailingStar() {
        #expect(CellTextCleaner.clean("高等数学 A-2★") == "高等数学 A-2")
    }

    @Test func stripsMultipleMarks() {
        #expect(CellTextCleaner.clean("线性代数◆○") == "线性代数")
    }

    @Test func stripsKnownNoteInParentheses() {
        #expect(CellTextCleaner.clean("同和楼 409(多)") == "同和楼 409")
        #expect(CellTextCleaner.clean("实验楼 502（单）") == "实验楼 502")
    }

    @Test func stripsMarkAndNoteTogether() {
        #expect(CellTextCleaner.clean("大学英语(多)★") == "大学英语")
    }

    @Test func keepsRealCourseSuffix() {
        // 「(二)」是课程名的一部分，不能当作注记剥掉。
        #expect(CellTextCleaner.clean("大学英语(二)") == "大学英语(二)")
    }

    @Test func keepsParenthesesWithLongerContent() {
        #expect(CellTextCleaner.clean("设计基础(实验班)") == "设计基础(实验班)")
    }

    @Test func leavesCleanTextAlone() {
        #expect(CellTextCleaner.clean("高等数学") == "高等数学")
        #expect(CellTextCleaner.clean("同和楼 409") == "同和楼 409")
    }

    @Test func trimsWhitespace() {
        #expect(CellTextCleaner.clean("  高等数学  ") == "高等数学")
    }

    @Test func emptyStaysEmpty() {
        #expect(CellTextCleaner.clean("") == "")
        #expect(CellTextCleaner.clean("★") == "")
    }

    // 端到端：解析单元格时注记已被剥离

    @Test func parseCellStripsAnnotations() {
        let course = TimetableTextParser.parseCourseCell("高等数学 A-2★\n陈老师\n同和楼 409(多)\n1-16周")
        #expect(course?.title == "高等数学 A-2")
        #expect(course?.room == "同和楼 409")
    }
}
