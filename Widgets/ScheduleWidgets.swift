import SwiftUI
import WidgetKit
@preconcurrency import ActivityKit
import AppIntents

struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry { .init(date: Date(), courses: []) }
    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        let payload = SystemSnapshot.readPayload()
        completion(.init(date: Date(), courses: payload?.courses ?? [],
                         leadMinutes: payload?.reminderLeadMinutes ?? 10, interaction: CampusWidgetInteractionStore.read(),
                         termID: payload?.termID, appearance: payload?.appearance ?? .init()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let payload = SystemSnapshot.readPayload()
        let courses = payload?.courses ?? []
        let lead = payload?.reminderLeadMinutes ?? 10
        let interaction = CampusWidgetInteractionStore.read()
        let now = Date()
        let entries = WidgetTimelinePlan.dates(courses: courses, now: now, leadMinutes: lead).map {
            ScheduleEntry(date: $0, courses: courses, leadMinutes: lead, interaction: interaction,
                          termID: payload?.termID, appearance: payload?.appearance ?? .init())
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(3600 * 12))))
    }
}
struct ScheduleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    var entry: ScheduleEntry
    var body: some View {
        ScheduleWidgetContent(family: family, entry: entry)
            .containerBackground(for: .widget) {
                ZStack {
                    Color(uiColor: .secondarySystemBackground)
                    if entry.appearance.theme == .blueStickers && renderingMode == .fullColor {
                        CampusStickerMark.accent.opacity(0.07)
                    }
                }
            }
            .widgetURL(CourseDeepLink.url(courseID: ScheduleRules.next(in: entry.courses, now: entry.date)?.courseID,
                                         termID: entry.termID,
                                         occurrenceID: ScheduleRules.next(in: entry.courses, now: entry.date)?.id))
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
            let appearance = SystemSnapshot.readPayload()?.appearance
            CourseLiveCard(title: context.attributes.title, room: context.attributes.room,
                start: context.attributes.start, end: context.state.end,
                teacher: context.attributes.teacher,
                nextRoom: context.state.nextRoom, stale: context.isStale,
                blueStickers: appearance.map { $0.theme == .blueStickers } ?? context.state.blueStickers ?? false,
                stickerPersona: appearance?.persona ?? .girl,
                density: appearance?.density ?? context.state.decorationDensity ?? .light)
            // 不指定背景与配色：锁屏和灵动岛属于系统界面，由系统按壁纸明暗
            // 决定底色与前景色才能保证可读。此前强制深底白字，在浅色壁纸上
            // 会突兀成一块黑卡，也与 App 本身的纸色风格不连续。
            .widgetURL(CourseDeepLink.activityURL(courseID: context.attributes.courseID, termID: context.attributes.termID,
                                                  occurrenceID: context.attributes.occurrenceID))
        } dynamicIsland: { context in
            // A scheduled activity can start after the user changes themes.
            let appearance = SystemSnapshot.readPayload()?.appearance
            let blueStickers = appearance.map { $0.theme == .blueStickers } ?? context.state.blueStickers ?? false
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.isStale ? "已结束" : "课程安排").font(.caption).foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CourseIslandExpanded(title: context.attributes.title, room: context.attributes.room,
                        start: context.attributes.start, end: context.state.end,
                        teacher: context.attributes.teacher,
                        nextTitle: context.state.nextTitle, nextRoom: context.state.nextRoom,
                        blueStickers: blueStickers, stickerPersona: appearance?.persona ?? .girl,
                        density: appearance?.density ?? context.state.decorationDensity ?? .light)
                }
            } compactLeading: {
                // 课前左侧放课程名（截断显示），上课中回到书本图标。
                // 收起态总共只有约 100 点宽，所以左名右时是最有效的分工。
                if context.state.beforeClass && !context.isStale {
                    Text(context.attributes.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(blueStickers ? CampusStickerMark.blue : .white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: 56, alignment: .leading)
                        .accessibilityHidden(true)
                } else if blueStickers {
                    Image(systemName: "paperplane.fill").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    // 灵动岛内部恒为深底，这里的白色不随外观变化。
                    CampusBookMark().stroke(.white, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)).frame(width: 14, height: 17)
                }
            } compactTrailing: {
                // 收起态只容得下一个短字符串，按阶段给最有用的那一项：
                // 课前是「还有几分钟上课」，上课中是「还有几分钟下课」。
                // 用系统计时器而不是反复刷新活动，既省电也不会滞后。
                if context.isStale {
                    Image(systemName: "checkmark").font(.caption)
                } else if context.state.beforeClass {
                    Text(timerInterval: Date()...max(Date(), context.attributes.start), countsDown: true)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .lineLimit(1).minimumScaleFactor(0.85).frame(width: 40)
                        .accessibilityLabel("\(context.attributes.title)，\(ScheduleRules.time(context.attributes.start)) 上课")
                } else {
                    Text(timerInterval: Date()...max(Date(), context.state.end), countsDown: true)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .lineLimit(1).minimumScaleFactor(0.85).frame(width: 40)
                        .accessibilityLabel("\(context.attributes.title)，\(ScheduleRules.time(context.state.end)) 下课")
                }
            } minimal: {
                if blueStickers {
                    Image(systemName: "paperplane.fill").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    CampusBookMark().stroke(.white, lineWidth: 1.4).frame(width: 13, height: 16)
                }
            }
            .widgetURL(CourseDeepLink.activityURL(courseID: context.attributes.courseID, termID: context.attributes.termID,
                                                  occurrenceID: context.attributes.occurrenceID))
        }
    }

}
@main struct CampusWidgetBundle: WidgetBundle {
    var body: some Widget { TimetableWidget(); MilestoneWidget(); CourseLiveWidget() }
}
