import Foundation

struct CourseReminder: Equatable, Sendable {
    var date: Date
    var id: String
    var title: String
    var body: String
}

enum NotificationPlan {
    static func make(courses: [CourseOccurrence], now: Date, enabled: Bool, lead: Int,
                     endEnabled: Bool, endLead: Int, limit: Int = 60) -> [CourseReminder] {
        var events: [CourseReminder] = []
        for course in courses where course.remindersEnabled {
            if enabled {
                events.append(.init(date: course.start.addingTimeInterval(-Double(max(0, lead) * 60)),
                    id: course.id + ".start", title: "即将上课 · " + course.title, body: course.room))
            }
            if endEnabled {
                let next = course.nextTitle.map { "下一节：\($0) · \(course.nextRoom ?? "地点待确认")" }
                events.append(.init(date: course.end.addingTimeInterval(-Double(max(0, endLead) * 60)),
                    id: course.id + ".end", title: endLead == 0 ? "下课了 · " + course.title : "即将下课 · " + course.title,
                    body: next ?? "本次课程即将结束"))
            }
        }
        return Array(events.filter { $0.date > now }.sorted {
            $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date
        }.prefix(max(0, limit)))
    }
}

enum WidgetTimelinePlan {
    static func dates(courses: [CourseOccurrence], now: Date) -> [Date] {
        let tomorrow = ScheduleRules.calendar.date(byAdding: .day, value: 1, to: ScheduleRules.calendar.startOfDay(for: now))!
        let horizon = tomorrow.addingTimeInterval(86400)
        var dates: Set<Date> = [now, tomorrow]
        for course in courses where course.end > now && course.start < horizon {
            if course.start > now { dates.insert(course.start) }
            dates.insert(course.end)
        }
        return dates.sorted()
    }
}
