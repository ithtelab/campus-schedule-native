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
        let c = ScheduleRules.calendar
        let days = c.dateComponents([.day], from: c.startOfDay(for: entry.date), to: c.startOfDay(for: date)).day ?? 0
        return days == 0 ? "今天" : days == 1 ? "明天" : "\(c.component(.month, from: date))月\(c.component(.day, from: date))日"
    }
    private func stateLabel(_ course: CourseOccurrence) -> String {
        course.start <= entry.date ? "正在上课" : "\(dayLabel(course.start)) · 下一节"
    }
    var body: some View {
        Group {
            if let next {
                switch family {
                case .accessoryInline:
                    Text("\(dayLabel(next.start)) \(ScheduleRules.time(next.start)) \(next.title)")
                case .accessoryRectangular:
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(next.title).font(.headline).lineLimit(1)
                            Text(next.room).font(.caption).lineLimit(1)
                            Text("\(ScheduleRules.time(next.start))–\(ScheduleRules.time(next.end))").font(.caption2.monospacedDigit()).lineLimit(1)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        CampusWidgetFigure().frame(width: 26, height: 52)
                    }
                case .systemMedium:
                    HStack(spacing: 12) {
                        primaryCourse(next, medium: true).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Spacer(minLength: 0); CampusWidgetFigure().frame(width: 42, height: 56) }
                            let following = entry.courses.filter { $0.start >= next.end && $0.id != next.id }.sorted { $0.start < $1.start }.prefix(2)
                            ForEach(Array(following)) { course in
                                Text("\(ScheduleRules.time(course.start)) \(course.title)")
                                    .font(.caption2.weight(.medium)).lineLimit(1)
                                Text(course.room).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            if following.isEmpty { Text("留点时间给自己").font(.caption2).foregroundStyle(.secondary) }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                default:
                    primaryCourse(next, medium: false)
                }
            } else {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.courses.isEmpty ? "课表还空着" : "暂时没有课").font(.headline)
                        Text(entry.courses.isEmpty ? "添加第一门课程" : "把时间留给自己").font(.caption).foregroundStyle(.secondary)
                        CampusBookMark().stroke(.primary, lineWidth: 1.8).frame(width: 22, height: 24)
                    }
                    CampusWidgetFigure().frame(width: 40, height: 70)
                }
            }
        }
    }
    private func primaryCourse(_ course: CourseOccurrence, medium: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stateLabel(course)).font(.caption2.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
            HStack(alignment: .top, spacing: 4) {
                Text(course.title).font(medium ? .title3.weight(.bold) : .headline.weight(.bold)).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !medium { CampusWidgetFigure().frame(width: 32, height: 54) }
            }
            Text(course.room).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Text("\(ScheduleRules.time(course.start <= entry.date ? course.end : course.start)) \(course.start <= entry.date ? "下课" : "上课")")
                .font(.subheadline.weight(.semibold).monospacedDigit()).lineLimit(1)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .foregroundStyle(Color(uiColor: .systemBackground))
                .background(Color.primary, in: RoundedRectangle(cornerRadius: 6))
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
