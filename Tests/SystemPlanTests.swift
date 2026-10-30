import Foundation
import Testing
@testable import ScheduleCore

struct SystemPlanTests {
    let now = Date(timeIntervalSince1970: 1788739200)
    var course: CourseOccurrence {
        .init(id: "instance", courseID: "course", title: "英语", room: "A302",
              start: now.addingTimeInterval(1800), end: now.addingTimeInterval(7200), nextTitle: "数学", nextRoom: "B205")
    }
    func plan(_ items: [CourseOccurrence], start: Bool = true, end: Bool = true, endLead: Int = 0, limit: Int = 60) -> [CourseReminder] {
        NotificationPlan.make(courses: items, now: now, enabled: start, lead: 10, endEnabled: end, endLead: endLead, limit: limit)
    }
    @Test func reminderSwitchesAreIndependent() {
        #expect(plan([course], start: false).map(\.id) == ["instance.end"])
        #expect(plan([course], end: false).map(\.id) == ["instance.start"])
        #expect(plan([course], start: false, end: false).isEmpty)
    }
    @Test func reminderLeadTimesAreExact() {
        let events = plan([course], endLead: 3)
        #expect(events[0].date == course.start.addingTimeInterval(-600))
        #expect(events[1].date == course.end.addingTimeInterval(-180))
        #expect(events[1].body.contains("数学") && events[1].body.contains("B205"))
    }
    @Test func mutedCourseProducesNoReminders() {
        var muted = course; muted.remindersEnabled = false
        #expect(plan([muted]).isEmpty)
    }
    @Test func passedReminderAndDeletedCourseAreNotRecreated() {
        var ended = course; ended.start = now.addingTimeInterval(-7200); ended.end = now
        #expect(plan([ended]).isEmpty)
        #expect(plan([]).isEmpty)
    }
    @Test func queueKeepsOnlyEarliestEvents() {
        let all = plan([course])
        #expect(plan([course], limit: 1) == [all[0]])
        #expect(plan([course], limit: 0).isEmpty)
    }
    @Test func widgetChangesAtBoundariesAndMidnight() {
        let dates = WidgetTimelinePlan.dates(courses: [course], now: now)
        #expect(dates == dates.sorted())
        #expect(Set(dates).count == dates.count)
        #expect(dates.contains(course.start) && dates.contains(course.end))
        let tomorrow = ScheduleRules.calendar.date(byAdding: .day, value: 1, to: ScheduleRules.calendar.startOfDay(for: now))!
        #expect(dates.contains(tomorrow))
        #expect(WidgetTimelinePlan.dates(courses: [], now: now) == [now, tomorrow])
    }
}
