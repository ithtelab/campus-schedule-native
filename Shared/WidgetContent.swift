import SwiftUI
import WidgetKit
import AppIntents

struct ScheduleEntry: TimelineEntry {
    var date: Date
    var courses: [CourseOccurrence]
    var leadMinutes: Int = 10
    var interaction: CampusWidgetInteraction? = nil
    var termID: String? = nil
}
struct ScheduleWidgetContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var family: WidgetFamily
    var entry: ScheduleEntry
    private var next: CourseOccurrence? { ScheduleRules.next(in: entry.courses, now: entry.date) }
    private var characterContext: CampusScheduleContext {
        CampusScheduleContext.make(items: entry.courses, now: entry.date, leadMinutes: entry.leadMinutes)
    }
    private var characterFrame: Int {
        CampusWidgetCharacterPlan.frame(context: characterContext, now: entry.date, interaction: entry.interaction)
    }
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
                        CampusWidgetFigure(frame: characterFrame).frame(width: 30, height: 58)
                    }
                case .systemMedium:
                    HStack(spacing: 12) {
                        primaryCourse(next, medium: true).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        interactiveFigure(width: 84, height: 128)
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
                    if family == .systemSmall || family == .systemMedium {
                        interactiveFigure(width: family == .systemMedium ? 84 : 50,
                                          height: family == .systemMedium ? 128 : 88)
                    } else {
                        CampusWidgetFigure(frame: characterFrame).frame(width: 30, height: 58)
                    }
                }
            }
        }
    }
    private func primaryCourse(_ course: CourseOccurrence, medium: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stateLabel(course)).font(.caption2.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
            HStack(alignment: .top, spacing: 4) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.title).font(medium ? .title3.weight(.bold) : .headline.weight(.bold)).lineLimit(2)
                    Text(course.room).font(medium ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !medium { interactiveFigure(width: 46, height: 78) }
            }
            Spacer(minLength: 0)
            Text("\(ScheduleRules.time(course.start <= entry.date ? course.end : course.start)) \(course.start <= entry.date ? "下课" : "上课")")
                .font(.subheadline.weight(.semibold).monospacedDigit()).lineLimit(1)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .foregroundStyle(Color(uiColor: .systemBackground))
                .background(Color.primary, in: RoundedRectangle(cornerRadius: 6))
            if medium, let following = entry.courses.filter({ $0.start >= course.end && $0.id != course.id }).min(by: { $0.start < $1.start }) {
                Text("接着 · \(dayLabel(following.start)) \(ScheduleRules.time(following.start)) \(following.title)")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func interactiveFigure(width: CGFloat, height: CGFloat) -> some View {
        Button(intent: RespondToCampusCharacterIntent()) {
            CampusWidgetFigure(frame: characterFrame)
                .id(characterFrame)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
                .frame(width: width, height: height, alignment: .bottom)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .invalidatableContent()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: characterFrame)
        .accessibilityLabel("校园人物，\(characterContext.interactionTitle)")
        .accessibilityHint("轻点回应，不会修改课程")
    }
}
