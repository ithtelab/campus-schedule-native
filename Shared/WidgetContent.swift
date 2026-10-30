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
    private func dayLabel(_ date: Date) -> String {
        let calendar = ScheduleRules.calendar
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: entry.date), to: calendar.startOfDay(for: date)).day ?? 0
        if days == 0 { return "今天" }
        if days == 1 { return "明天" }
        let parts = calendar.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 1)月\(parts.day ?? 1)日"
    }
    private func stateLabel(_ course: CourseOccurrence) -> String {
        if course.start <= entry.date { return "正在上课" }
        return ScheduleRules.calendar.isDate(course.start, inSameDayAs: entry.date) ? "下一节课" : "\(dayLabel(course.start))第一节"
    }
    var body: some View {
        Group {
            if let next {
                if family == .accessoryInline {
                    Text("\(dayLabel(next.start)) \(ScheduleRules.time(next.start)) \(next.title)")
                } else if family == .accessoryRectangular {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(dayLabel(next.start)) \(ScheduleRules.time(next.start <= entry.date ? next.end : next.start))\(next.start <= entry.date ? " 下课" : "")")
                            .font(.caption.monospacedDigit()).lineLimit(1)
                        Text(next.title).font(.headline).lineLimit(1)
                        Text(next.room).font(.caption).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                } else if family == .systemMedium {
                    HStack(alignment: .top, spacing: 14) {
                        primaryCourse(next)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        Divider()
                        VStack(alignment: .leading, spacing: 10) {
                            Text("后续安排").font(.caption).foregroundStyle(.secondary)
                            let following = entry.courses.filter { $0.start >= next.end && $0.id != next.id }.sorted { $0.start < $1.start }.prefix(2)
                            if following.isEmpty {
                                Text("暂无后续课程").font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(Array(following)) { course in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(ScheduleRules.calendar.isDate(course.start, inSameDayAs: entry.date) ? "" : dayLabel(course.start) + " ")\(ScheduleRules.time(course.start))  \(course.title)")
                                        .font(.caption.weight(.medium)).lineLimit(1)
                                    Text(course.room).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                } else {
                    primaryCourse(next).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else {
                Label(entry.courses.isEmpty ? "添加你的课程" : "暂无后续课程", systemImage: "calendar")
            }
        }

    }

    private func primaryCourse(_ course: CourseOccurrence) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stateLabel(course)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(course.title).font(.caption.weight(.semibold)).lineLimit(2)
            Text(course.room).font(.title3.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Text("\(ScheduleRules.time(course.start <= entry.date ? course.end : course.start)) \(course.start <= entry.date ? "下课" : "上课")")
                .font(.title3.weight(.bold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}
