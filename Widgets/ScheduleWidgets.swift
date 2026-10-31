import SwiftUI
import WidgetKit
@preconcurrency import ActivityKit
import AppIntents

struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry { .init(date: Date(), courses: []) }
    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        completion(.init(date: Date(), courses: SystemSnapshot.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let courses = SystemSnapshot.read()
        let now = Date()
        let entries = WidgetTimelinePlan.dates(courses: courses, now: now).map { ScheduleEntry(date: $0, courses: courses) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(3600 * 12))))
    }
}
struct ScheduleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ScheduleEntry
    var body: some View {
        ScheduleWidgetContent(family: family, entry: entry)
            .containerBackground(Color(uiColor: .secondarySystemBackground), for: .widget)
            .widgetURL(URL(string: "campusschedule://course/" + (ScheduleRules.next(in: entry.courses, now: entry.date)?.courseID ?? "")))
    }
}
struct TimetableWidget: Widget {
    let kind = "TimetableWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleProvider()) { ScheduleWidgetView(entry: $0) }
            .configurationDisplayName("当前与下一节课")
            .description("查看上课时间和地点")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}
struct CourseLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CourseActivityAttributes.self) { context in
            CourseLiveCard(title: context.attributes.title, room: context.attributes.room,
                start: context.attributes.start, end: context.state.end, nextRoom: context.state.nextRoom, stale: context.isStale)
            .environment(\.colorScheme, .dark)
            .activityBackgroundTint(Color(white: 0.07))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.isStale ? "已结束" : "课程安排").font(.caption).foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CourseIslandExpanded(title: context.attributes.title, room: context.attributes.room,
                        start: context.attributes.start, end: context.state.end, nextTitle: context.state.nextTitle, nextRoom: context.state.nextRoom)
                }
            } compactLeading: {
                CampusBookMark().stroke(.white, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)).frame(width: 14, height: 17)
            } compactTrailing: {
                if context.isStale { Image(systemName: "checkmark").font(.caption) }
                else {
                    Text(CourseLivePlan.compactTime(end: context.state.end))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .lineLimit(1).minimumScaleFactor(0.9).frame(width: 36)
                        .accessibilityLabel("下课 \(ScheduleRules.time(context.state.end))")
                }
            } minimal: {
                CampusBookMark().stroke(.white, lineWidth: 1.4).frame(width: 13, height: 16)
            }
            .widgetURL(URL(string: "campusschedule://today"))
            .keylineTint(.white)
        }
    }
}
@main struct CampusWidgetBundle: WidgetBundle {
    var body: some Widget { TimetableWidget(); CourseLiveWidget() }
}
