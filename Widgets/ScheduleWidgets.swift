import SwiftUI
import WidgetKit
@preconcurrency import ActivityKit
import AppIntents

struct ScheduleEntry: TimelineEntry {
    var date: Date
    var courses: [CourseOccurrence]
}
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
    private var next: CourseOccurrence? { ScheduleRules.next(in: entry.courses, now: entry.date) }
    var body: some View {
        Group {
            if let next {
                if family == .accessoryInline {
                    Text("\(ScheduleRules.time(next.start)) \(next.title) · \(next.room)")
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
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "campusschedule://course/" + (next?.courseID ?? "")))
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
struct EndCourseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "结束本次课程活动" }
    @Parameter(title: "课程实例") var occurrenceID: String
    init() {}
    init(id: String) { occurrenceID = id }
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: SystemSnapshot.group) ?? .standard
        var ended = Set(defaults.stringArray(forKey: "endedOccurrences") ?? [])
        ended.insert(occurrenceID); defaults.set(Array(ended), forKey: "endedOccurrences")
        for activity in Activity<CourseActivityAttributes>.activities where activity.attributes.occurrenceID == occurrenceID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}
struct CourseLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CourseActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                Text(context.isStale ? "课程时间已结束" : context.attributes.title).font(.headline)
                Text(context.attributes.room).font(.subheadline)
                if !context.isStale {
                    Text(context.state.beforeClass ? "距离上课" : "距离下课").font(.caption)
                    Text(timerInterval: Date()...max(Date(), context.state.beforeClass ? context.attributes.start : context.state.end), countsDown: true).monospacedDigit()
                }
                HStack {
                    Text("上课"); Text(context.attributes.start, style: .time)
                    Text("下课"); Text(context.state.end, style: .time)
                }.font(.subheadline.monospacedDigit())
                if let title = context.state.nextTitle {
                    Text("下一节 \(title) · \(context.state.nextRoom ?? "地点待确认")").font(.caption)
                }
                Button(intent: EndCourseIntent(id: context.attributes.occurrenceID)) { Text("结束本次") }
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text(context.attributes.title).font(.headline) }
                DynamicIslandExpandedRegion(.trailing) { Text(context.attributes.room).font(.caption) }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack {
                        HStack { Text("下课"); Text(context.state.end, style: .time) }.monospacedDigit()
                        if let title = context.state.nextTitle { Text("下一节：\(title) · \(context.state.nextRoom ?? "地点待确认")").font(.caption) }
                        Button(intent: EndCourseIntent(id: context.attributes.occurrenceID)) { Text("结束本次") }
                    }
                }
            } compactLeading: { Image(systemName: "book.closed") }
              compactTrailing: {
                  if context.isStale { Image(systemName: "checkmark") }
                  else { Text(timerInterval: Date()...max(Date(), context.state.beforeClass ? context.attributes.start : context.state.end), countsDown: true).monospacedDigit().frame(width: 48) }
              }
              minimal: { Image(systemName: "book.closed") }
            .widgetURL(URL(string: "campusschedule://today"))
        }
    }
}
@main struct CampusWidgetBundle: WidgetBundle {
    var body: some Widget { TimetableWidget(); CourseLiveWidget() }
}
