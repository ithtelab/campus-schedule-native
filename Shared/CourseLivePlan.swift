import Foundation

enum CourseLivePlan {
    static func earliestStart(for course: CourseOccurrence, lead: Int) -> Date {
        course.start.addingTimeInterval(-Double(min(120, max(0, lead))) * 60)
    }
    static func canStartManually(_ course: CourseOccurrence, now: Date, lead: Int) -> Bool {
        now >= earliestStart(for: course, lead: lead) && now < course.end
    }
    // Compact island displays a stable clock time, never a multi-hour truncated timer.
    static func compactTime(end: Date) -> String { ScheduleRules.time(end) }
}
