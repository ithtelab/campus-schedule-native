import Foundation

enum CourseLivePlan {
    static func earliestStart(for course: CourseOccurrence, lead: Int) -> Date {
        course.start.addingTimeInterval(-Double(min(120, max(0, lead))) * 60)
    }
    static func canStartManually(_ course: CourseOccurrence, now: Date, lead: Int) -> Bool {
        now >= earliestStart(for: course, lead: lead) && now < course.end
    }
    static func schedule(items: [CourseOccurrence], now: Date, lead: Int) -> [(course: CourseOccurrence, start: Date)] {
        let upcoming = items.filter { $0.end > now }.sorted {
            $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start
        }
        guard let first = upcoming.first else { return [] }
        var plan = [(course: first, start: earliestStart(for: first, lead: lead))]
        let calendar = ScheduleRules.calendar
        let endOfTomorrow = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now)) ?? now
        var previousEnd = first.end
        for course in upcoming.dropFirst() where course.start < endOfTomorrow {
            guard plan.count < 4 else { break }
            guard course.start >= previousEnd else { continue }
            plan.append((course, max(previousEnd, earliestStart(for: course, lead: lead))))
            previousEnd = course.end
        }
        return plan
    }
    // Compact island displays a stable clock time, never a multi-hour truncated timer.
    static func compactTime(end: Date) -> String { ScheduleRules.time(end) }
}
