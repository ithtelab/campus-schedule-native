import Foundation

enum CourseLivePlan {
    static func earliestStart(for course: CourseOccurrence, lead: Int) -> Date {
        course.start.addingTimeInterval(-Double(min(120, max(0, lead))) * 60)
    }
    static func canStartManually(_ course: CourseOccurrence, now: Date, lead: Int) -> Bool {
        now >= earliestStart(for: course, lead: lead) && now < course.end
    }
    static func schedule(items: [CourseOccurrence], now: Date, lead: Int) -> [(course: CourseOccurrence, start: Date)] {
        guard let first = ScheduleRules.next(in: items, now: now) else { return [] }
        var plan = [(course: first, start: earliestStart(for: first, lead: lead))]
        if let following = ScheduleRules.next(in: items.filter {
            $0.start >= first.end && ScheduleRules.calendar.isDate($0.start, inSameDayAs: first.start)
        }, now: now) {
            plan.append((following, max(first.end, earliestStart(for: following, lead: lead))))
        }
        return plan
    }
    // Compact island displays a stable clock time, never a multi-hour truncated timer.
    static func compactTime(end: Date) -> String { ScheduleRules.time(end) }
}
