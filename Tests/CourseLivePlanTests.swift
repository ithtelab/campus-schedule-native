import Foundation
import CoreGraphics
import Testing
@testable import ScheduleCore

@Suite struct CourseLivePlanTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    func course() -> CourseOccurrence { .init(id: "a", courseID: "a", title: "课", room: "A302", start: start, end: start.addingTimeInterval(5700)) }
    @Test func doesNotStartSixHoursEarly() {
        #expect(!CourseLivePlan.canStartManually(course(), now: start.addingTimeInterval(-21600), lead: 10))
    }
    @Test func exactLeadAndEndBoundaries() {
        #expect(!CourseLivePlan.canStartManually(course(), now: start.addingTimeInterval(-601), lead: 10))
        #expect(CourseLivePlan.canStartManually(course(), now: start.addingTimeInterval(-600), lead: 10))
        #expect(CourseLivePlan.canStartManually(course(), now: start, lead: 10))
        #expect(!CourseLivePlan.canStartManually(course(), now: course().end, lead: 10))
    }
    @Test func compactClockHasBoundedWidth() {
        #expect(CourseLivePlan.compactTime(end: course().end).count == 5)
    }
    @Test func spriteRowsDoNotIncludeNextRowsHands() {
        let rect = CampusSpriteLayout.rect(index: 11, girl: true, width: 887, height: 1774)!
        #expect(rect.maxY <= 1288)
        #expect(CampusSpriteLayout.rect(index: 15, girl: true, width: 887, height: 1774)!.minY >= 1295)
        #expect(CampusSpriteLayout.rect(index: 16, girl: true, width: 887, height: 1774) == nil)
        // The leaning hat and walking toes extend past an equal-width column.
        #expect(CampusSpriteLayout.rect(index: 4, girl: true, width: 887, height: 1774)!.maxX >= 250)
        #expect(CampusSpriteLayout.rect(index: 12, girl: false, width: 887, height: 1774)!.maxX >= 234)
        for girl in [false, true] {
            for index in 0..<16 {
                let scaled = CampusSpriteLayout.rect(index: index, girl: girl, width: 1774, height: 3548)!
                #expect(CGRect(x: 0, y: 0, width: 1774, height: 3548).contains(scaled))
            }
        }
    }
}
