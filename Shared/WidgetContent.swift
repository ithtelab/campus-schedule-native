import SwiftUI
import WidgetKit

struct ScheduleEntry: TimelineEntry {
    var date: Date
    var courses: [CourseOccurrence]
}
struct ScheduleWidgetContent: View {
    var family: WidgetFamily
    var entry: ScheduleEntry
    private var next: CourseOccurrence? { ScheduleRules.next(in: entry.courses, now: entry.date) }
    var body: some View {
        Group {
            if let next {
                if family == .accessoryInline {
                    Text("\(ScheduleRules.time(next.start)) \(next.title) · \(next.room)")
                } else if family == .accessoryRectangular {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(next.title).font(.headline).lineLimit(1)
                        Text(next.room).font(.caption).lineLimit(1)
                        Text(ScheduleRules.time(next.start <= entry.date ? next.end : next.start)).font(.caption.monospacedDigit())
                    }.frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(next.start <= entry.date ? "正在上课" : ScheduleRules.calendar.isDate(next.start, inSameDayAs: entry.date) ? "下一节课" : next.start.formatted(.dateTime.month().day())).font(.caption).foregroundStyle(.secondary)
                        Text(next.title).font(.headline).lineLimit(2)
                        Text(next.room).font(.caption).lineLimit(1)
                        Text(next.start <= entry.date ? next.end : next.start, style: .time).font(.subheadline.monospacedDigit())
                        if family == .systemMedium {
                            ForEach(entry.courses.filter { $0.start > next.start }.prefix(2)) { course in
                                Text("\(ScheduleRules.time(course.start))  \(course.title)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Label(entry.courses.isEmpty ? "添加你的课程" : "暂无后续课程", systemImage: "calendar")
            }
        }

    }
}
