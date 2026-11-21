import Foundation
import Testing
@testable import ScheduleCore

struct SystemPlanTests {
    @Test func imminentCoursesOutrankDistantExamsAndExamsWinTies() {
        let course = CourseReminder(date: now, id: "course.a", title: "课程", body: "")
        var exam = CourseReminder(date: now.addingTimeInterval(86_400), id: "exam.a", title: "考试", body: "")
        #expect(ReminderChanges.prioritized([course, exam], limit: 1) == [course])
        exam.date = now
        #expect(ReminderChanges.prioritized([course, exam], limit: 1) == [exam])
    }

    @Test func fullQueuePlansARefillBeforeTheLastScheduledReminder() {
        let desired = (1...9).map { index in
            CourseReminder(date: now.addingTimeInterval(Double(index) * 3600), id: "course.\(index)", title: "课", body: "")
        }
        let date = ReminderChanges.refillDate(desired: desired, availableCount: 20, now: now)
        #expect(date == desired[2].date.addingTimeInterval(60))
        #expect(ReminderChanges.refillDate(desired: desired, availableCount: 9, now: now) == nil)
    }
    @Test func reminderDiffKeepsUnchangedRequestsAndReplacesOnlyEditedOnes() {
        let unchanged = CourseReminder(date: now, id: "course.a", title: "课", body: "A101")
        let original = CourseReminder(date: now, id: "course.b", title: "课", body: "B101")
        var changed = original
        changed.body = "B102"
        let deleted = CourseReminder(date: now, id: "milestone.c", title: "提醒", body: "今天")
        let diff = ReminderChanges(pending: [unchanged.id: unchanged, original.id: original, deleted.id: deleted],
                                   desired: [unchanged, changed])
        #expect(diff.obsolete == [deleted.id])
        #expect(diff.additions == [changed])
    }

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
    @Test func courseRemindersTargetTheirOwnTermAndOccurrence() throws {
        var first = course
        first.termID = "term-a"
        var second = first
        second.termID = "term-b"
        let events = plan([first, second], end: false)
        #expect(Set(events.map(\.id)).count == 2)
        let firstDestination = try #require(events.first?.destination)
        #expect(CourseDeepLink.target(firstDestination) == .init(courseID: "course", termID: "term-a", occurrenceID: "instance"))
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
