import Foundation
import Testing
@testable import ScheduleCore

struct CourseDeepLinkTests {
    @Test func instanceAndTermSurviveURLRoundTrip() throws {
        let url = try #require(CourseDeepLink.url(courseID: "课程/:甲", termID: "学期&2", occurrenceID: "课程/:甲:123"))
        #expect(CourseDeepLink.target(url) == .init(courseID: "课程/:甲", termID: "学期&2", occurrenceID: "课程/:甲:123"))
    }

    @Test func olderLiveActivityKeysPreserveCourseIDsContainingColons() throws {
        let url = try #require(CourseDeepLink.activityURL(courseID: nil, termID: nil, occurrenceID: "school:math:1793000000"))
        #expect(CourseDeepLink.target(url) == .init(courseID: "school:math", termID: nil, occurrenceID: "school:math:1793000000"))
        #expect(CourseDeepLink.activityURL(courseID: nil, termID: nil, occurrenceID: "unrecognized")?.host == "today")
    }

    @Test func explicitInstanceDoesNotSwitchToNextWeeksClassAfterEnding() {
        let now = Date(timeIntervalSince1970: 1793000000)
        let ended = CourseOccurrence(id: "ended", courseID: "math", title: "数学", room: "旧教室",
                                     start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(-60))
        let future = CourseOccurrence(id: "future", courseID: "math", title: "数学", room: "新教室",
                                      start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200))
        #expect(CourseDeepLink.occurrence(for: .init(courseID: "math", termID: nil, occurrenceID: "ended"),
                                         in: [ended, future], now: now) == ended)
        #expect(CourseDeepLink.occurrence(for: .init(courseID: "math", termID: nil), in: [ended, future], now: now) == future)
    }

    @Test func staleOrMismatchedInstanceDoesNotOpenAnotherCourse() {
        let now = Date()
        let other = CourseOccurrence(id: "shared-instance", courseID: "english", title: "英语", room: "B205",
                                     start: now, end: now.addingTimeInterval(3600))
        #expect(CourseDeepLink.occurrence(for: .init(courseID: "math", termID: nil, occurrenceID: other.id), in: [other], now: now) == nil)
        #expect(CourseDeepLink.occurrence(for: .init(courseID: "english", termID: nil, occurrenceID: "removed"), in: [other], now: now) == nil)
    }
}
