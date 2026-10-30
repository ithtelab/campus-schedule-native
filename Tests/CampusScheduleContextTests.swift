import Foundation
import Testing
@testable import ScheduleCore

@Suite struct CampusScheduleContextTests {
    let day = ScheduleRules.calendar.date(from: DateComponents(year: 2026, month: 10, day: 26))!
    func time(_ value: String) -> Date { ScheduleRules.date(day: day, time: value)! }
    func course(_ id: String, _ start: String, _ end: String, _ room: String = "A302") -> CourseOccurrence {
        .init(id: id, courseID: id, title: id, room: room, start: time(start), end: time(end))
    }
    @Test func leadWindowHasExactBoundary() {
        let items = [course("a", "10:00", "11:35")]
        #expect(CampusScheduleContext.make(items: items, now: time("09:49"), leadMinutes: 10).phase == .freeReading)
        #expect(CampusScheduleContext.make(items: items, now: time("09:50"), leadMinutes: 10).phase == .preparing)
        #expect(CampusScheduleContext.make(items: items, now: time("10:00"), leadMinutes: 10).phase == .inClass)
    }
    @Test func classAlwaysUsesSeatedReadingResponse() {
        let context = CampusScheduleContext.make(items: [course("a", "10:00", "11:35")], now: time("10:30"), leadMinutes: 30)
        #expect(context.stableState == .seatedReading)
        #expect(context.response == .turnPage)
    }
    @Test func movingRequiresKnownDifferentRoomAndLeadWindow() {
        let items = [course("a", "08:00", "09:35"), course("b", "10:00", "11:35", "B205")]
        #expect(CampusScheduleContext.make(items: items, now: time("09:41"), leadMinutes: 10).phase == .betweenClasses)
        #expect(CampusScheduleContext.make(items: items, now: time("09:50"), leadMinutes: 10).phase == .moving)
        let sameRoom = [items[0], course("b", "10:00", "11:35", "A302")]
        #expect(CampusScheduleContext.make(items: sameRoom, now: time("09:50"), leadMinutes: 10).phase == .preparing)
    }
    @Test func unknownRoomDoesNotInventMovement() {
        let context = CampusScheduleContext.make(items: [course("a", "08:00", "09:35"), course("b", "10:00", "11:35", "地点待定")], now: time("09:55"), leadMinutes: 10)
        #expect(context.phase == .preparing)
    }
    @Test func currentLessonWinsOverNextLeadWindow() {
        let context = CampusScheduleContext.make(items: [course("a", "10:00", "10:45"), course("b", "10:50", "11:35", "B205")], now: time("10:40"), leadMinutes: 15)
        #expect(context.phase == .inClass)
        #expect(context.occurrenceID == "a")
    }
    @Test func endOfDayAndNoClassesHaveDifferentStates() {
        let finished = CampusScheduleContext.make(items: [course("a", "10:00", "11:35")], now: time("11:35"), leadMinutes: 10)
        #expect(finished.phase == .finished)
        #expect(finished.stableState == .seatedEmpty)
        #expect(CampusScheduleContext.make(items: [], now: time("10:30"), leadMinutes: 10).phase == .freeReading)
    }
}
