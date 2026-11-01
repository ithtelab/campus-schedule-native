import Foundation
import Testing
@testable import ScheduleCore

struct CourseSearchTests {
    func course(_ title: String, teacher: String = "", room: String = "",
                weekday: Int = 0, start: Int = 1, end: Int = 2,
                weeks: Set<Int> = Set(1...20), id: String? = nil) -> SearchableCourse {
        SearchableCourse(id: id ?? title, title: title, teacher: teacher, room: room,
                         weekday: weekday, startPeriod: start, endPeriod: end, weeks: weeks)
    }

    // MARK: 匹配

    @Test func matchesByTitle() {
        let items = [course("高等数学"), course("大学英语")]
        #expect(CourseSearch.search(items, query: "数学", totalWeeks: 20).map(\.title) == ["高等数学"])
    }

    @Test func matchesByTeacher() {
        let items = [course("高等数学", teacher: "陈老师"), course("线性代数", teacher: "李老师")]
        #expect(CourseSearch.search(items, query: "陈", totalWeeks: 20).count == 1)
    }

    @Test func matchesByRoom() {
        let items = [course("课一", room: "A302"), course("课二", room: "B205")]
        #expect(CourseSearch.search(items, query: "B205", totalWeeks: 20).first?.title == "课二")
    }

    @Test func searchIsCaseInsensitive() {
        let items = [course("Python 程序设计")]
        #expect(CourseSearch.search(items, query: "python", totalWeeks: 20).count == 1)
    }

    @Test func emptyQueryReturnsAll() {
        let items = [course("A课"), course("B课"), course("C课")]
        #expect(CourseSearch.search(items, query: "", totalWeeks: 20).count == 3)
        // 按名称排序，结果稳定。
        #expect(CourseSearch.search(items, query: "  ", totalWeeks: 20).map(\.title) == ["A课", "B课", "C课"])
    }

    @Test func noMatchReturnsEmpty() {
        #expect(CourseSearch.search([course("高等数学")], query: "物理", totalWeeks: 20).isEmpty)
    }

    // MARK: 合并

    @Test func sameCourseMergeSlots() {
        // 同名同师同地点但不同时段，应合并成一条并列出所有时段。
        let items = [course("高等数学", teacher: "陈老师", room: "A302", weekday: 0, start: 1, end: 2, id: "a"),
                     course("高等数学", teacher: "陈老师", room: "A302", weekday: 2, start: 3, end: 4, id: "b")]
        let hits = CourseSearch.search(items, query: "数学", totalWeeks: 20)
        #expect(hits.count == 1)
        #expect(hits[0].slots.count == 2)
        #expect(hits[0].slots[0].contains("周一"))
        #expect(hits[0].slots[1].contains("周三"))
    }

    @Test func slotsSortedByDayThenPeriod() {
        let items = [course("课", weekday: 3, start: 5, end: 6, id: "d"),
                     course("课", weekday: 0, start: 7, end: 8, id: "a"),
                     course("课", weekday: 0, start: 1, end: 2, id: "b")]
        let hit = CourseSearch.search(items, query: "", totalWeeks: 20)[0]
        #expect(hit.slots[0].contains("周一") && hit.slots[0].contains("1–2"))
        #expect(hit.slots[1].contains("周一") && hit.slots[1].contains("7–8"))
        #expect(hit.slots[2].contains("周四"))
    }

    @Test func differentTeachersStaySeparate() {
        // 同名但不同老师，是两门课。
        let items = [course("导论", teacher: "张老师"), course("导论", teacher: "王老师")]
        #expect(CourseSearch.search(items, query: "导论", totalWeeks: 20).count == 2)
    }

    @Test func differentRoomsStaySeparate() {
        let items = [course("课", room: "A302"), course("课", room: "B205")]
        #expect(CourseSearch.search(items, query: "课", totalWeeks: 20).count == 2)
    }

    // MARK: 周次说明

    @Test func fullTermSaysWholeTerm() {
        #expect(CourseSearch.weeksText(Set(1...20), totalWeeks: 20) == "整学期")
        #expect(CourseSearch.weeksText([], totalWeeks: 20) == "整学期")
    }

    @Test func oddAndEvenWeeks() {
        #expect(CourseSearch.weeksText(Set(stride(from: 1, through: 20, by: 2)), totalWeeks: 20) == "单周")
        #expect(CourseSearch.weeksText(Set(stride(from: 2, through: 20, by: 2)), totalWeeks: 20) == "双周")
    }

    @Test func rangeWeeks() {
        #expect(CourseSearch.weeksText(Set(1...8), totalWeeks: 20) == "1-8 周")
    }

    @Test func discontinuousWeeks() {
        #expect(CourseSearch.weeksText([1, 2, 5, 9], totalWeeks: 20) == "1-2,5,9 周")
    }

    // MARK: 其他

    @Test func respectsLimit() {
        let items = (1...60).map { course("课\($0)") }
        #expect(CourseSearch.search(items, query: "", totalWeeks: 20, limit: 10).count == 10)
    }

    @Test func weekdayNames() {
        #expect(CourseSearch.weekdayName(0) == "周一")
        #expect(CourseSearch.weekdayName(6) == "周日")
        #expect(CourseSearch.weekdayName(9) == "未知")
    }
}
