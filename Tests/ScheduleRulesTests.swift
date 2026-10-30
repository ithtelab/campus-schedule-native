import Foundation
import Testing
@testable import ScheduleCore

struct ScheduleRulesTests {
    let start = ScheduleRules.calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))!
    @Test func weekBoundaries() {
        #expect(ScheduleRules.week(on: start, semesterStart: start) == 1)
        #expect(ScheduleRules.week(on: start.addingTimeInterval(-1), semesterStart: start) == 0)
        #expect(ScheduleRules.week(on: start.addingTimeInterval(7 * 86400), semesterStart: start) == 2)
    }
    @Test func invalidTimesAreRejected() {
        #expect(ScheduleRules.date(day: start, time: "24:10") == nil)
        #expect(ScheduleRules.date(day: start, time: "09:99") == nil)
        #expect(ScheduleRules.date(day: start, time: "bad") == nil)
    }
    @Test func usesCampusTimezone() {
        let date = ScheduleRules.date(day: start, time: "08:00")!
        #expect(ScheduleRules.calendar.component(.hour, from: date) == 8)
        #expect(date.timeIntervalSince1970 == 1788739200)
    }
    @Test func endBoundaryMovesToNextCourse() {
        let first = CourseOccurrence(id: "1", courseID: "a", title: "数学", room: "A", start: start, end: start.addingTimeInterval(3600))
        let second = CourseOccurrence(id: "2", courseID: "b", title: "英语", room: "B", start: first.end.addingTimeInterval(600), end: first.end.addingTimeInterval(4200))
        #expect(ScheduleRules.next(in: [second, first], now: first.end)?.id == "2")
        #expect(ScheduleRules.next(in: [first], now: first.end) == nil)
    }
    @Test func unknownLocationIsNotSameRoom() {
        #expect(ScheduleRules.needsMove(from: "", to: "A302") == nil)
        #expect(ScheduleRules.needsMove(from: "地点待定", to: "A302") == nil)
        #expect(ScheduleRules.needsMove(from: "A · 302", to: "a302") == false)
        #expect(ScheduleRules.needsMove(from: "A302", to: "B205") == true)
    }
    @Test func mergeOnlySameCourseSameRoomShortBreak() {
        let first = CourseOccurrence(id: "1", courseID: "a", title: "数学", room: "A302", start: start, end: start.addingTimeInterval(2700))
        var second = CourseOccurrence(id: "2", courseID: "a", title: "数学", room: "A 302", start: first.end.addingTimeInterval(300), end: first.end.addingTimeInterval(3000))
        #expect(ScheduleRules.mergeContinuous([second, first]).count == 1)
        second.room = "B205"
        #expect(ScheduleRules.mergeContinuous([first, second]).count == 2)
        second.room = "A302"; second.courseID = "b"
        #expect(ScheduleRules.mergeContinuous([first, second]).count == 2)
        second.courseID = "a"; second.start = first.end.addingTimeInterval(3600)
        second.end = second.start.addingTimeInterval(2700)
        #expect(ScheduleRules.mergeContinuous([first, second]).count == 2)
    }
}
