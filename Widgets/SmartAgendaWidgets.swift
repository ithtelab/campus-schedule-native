import SwiftUI
import WidgetKit
import AppIntents

/// 智能课间的组件配置。
///
/// 桌面默认开启待办与纪念事件；锁屏只开启课程与考试，因为那里只有一行，
/// 不该被一条不紧急的作业占住。用户可在长按编辑里单独调整。
struct SmartAgendaConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "智能课间" }
    static var description: IntentDescription {
        IntentDescription("根据课表、考试、待办与纪念事件自动挑出现在最该看的一条。")
    }

    @Parameter(title: "显示待办")
    var allowTasks: Bool?

    @Parameter(title: "显示纪念事件")
    var allowMilestones: Bool?

    @Parameter(title: "纪念事件")
    var milestone: MilestoneEntity?
}

/// 一条主信息 + 至多一条不同类别的补充。
struct SmartAgendaEntry: TimelineEntry {
    var date: Date
    var selection: SmartAgendaSelection
    var appearance = AppearancePreferences()
}

/// 锁屏（accessory）只有一行，默认不该放待办。
///
/// `WidgetFamily` 没有 `isAccessory` 之类的便利属性，必须逐个列举；
/// 写成独立函数也便于将来新增 family 时只改一处。
private func isLockScreenFamily(_ family: WidgetFamily) -> Bool {
    switch family {
    case .accessoryCircular, .accessoryRectangular, .accessoryInline: true
    default: false
    }
}

struct SmartAgendaProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SmartAgendaEntry {
        let now = Date()
        return SmartAgendaEntry(date: now, selection: Self.placeholderSelection())
    }

    func snapshot(for configuration: SmartAgendaConfiguration, in context: Context) async -> SmartAgendaEntry {
        let now = Date()
        let payload = SystemSnapshot.readPayload()
        let options = resolveOptions(configuration, lockScreen: isLockScreenFamily(context.family))
        let snapshot = entry(at: now, payload: payload, options: options)
        if context.isPreview && snapshot.selection.isEmpty && snapshot.selection.secondary == nil {
            return placeholder(in: context)
        }
        return snapshot
    }

    func timeline(for configuration: SmartAgendaConfiguration, in context: Context) async -> Timeline<SmartAgendaEntry> {
        let now = Date()
        let payload = SystemSnapshot.readPayload()
        let options = resolveOptions(configuration, lockScreen: isLockScreenFamily(context.family))
        let dates = SmartAgenda.switchDates(
            courses: payload?.courses ?? [], exams: payload?.exams ?? [],
            tasks: payload?.tasks ?? [], milestones: payload?.milestones ?? [],
            now: now, leadMinutes: payload?.reminderLeadMinutes ?? 10,
            options: options, limit: 20)
        // 每次求值都用同一个配置与快照，保证切换点之间状态连续。
        let entries = dates.map { entry(at: $0, payload: payload, options: options) }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func resolveOptions(_ configuration: SmartAgendaConfiguration, lockScreen: Bool) -> SmartAgendaOptions {
        let defaults = SmartAgendaOptions.defaults(forLockScreen: lockScreen)
        return SmartAgendaOptions(
            allowTasks: configuration.allowTasks ?? defaults.allowTasks,
            allowMilestones: configuration.allowMilestones ?? defaults.allowMilestones,
            milestoneID: configuration.milestone?.id)
    }

    private func entry(at date: Date, payload: SystemSnapshot.Payload?, options: SmartAgendaOptions) -> SmartAgendaEntry {
        let selection = SmartAgenda.select(
            courses: payload?.courses ?? [], exams: payload?.exams ?? [],
            tasks: payload?.tasks ?? [], milestones: payload?.milestones ?? [],
            now: date, leadMinutes: payload?.reminderLeadMinutes ?? 10,
            options: options, courseTermID: payload?.termID)
        return SmartAgendaEntry(date: date, selection: selection, appearance: payload?.appearance ?? .init())
    }

    /// 编辑预览用。没有真实数据时也要能看出排版，不能只显示空状态。
    static func placeholderSelection() -> SmartAgendaSelection {
        return SmartAgendaSelection(
            primary: SmartAgendaItem(
                id: "placeholder-course", kind: .course, status: "今天 10:00",
                title: "大学英语", detail: "B 205", value: "10:00",
                urgency: .upcoming, target: .task(courseID: "", termID: nil)),
            secondary: SmartAgendaItem(
                id: "placeholder-task", kind: .task, status: "22:00 截止",
                title: "交实验报告", detail: "物理实验", value: "22:00",
                urgency: .imminent, target: .task(courseID: "", termID: nil)),
            overdueCount: 0)
    }
}

private struct SmartAgendaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SmartAgendaEntry

    var body: some View {
        SmartAgendaWidgetContent(family: family, selection: entry.selection, appearance: entry.appearance)
    }
}

struct SmartAgendaWidget: Widget {
    let kind = "SmartAgendaWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SmartAgendaConfiguration.self,
                               provider: SmartAgendaProvider()) { entry in
            SmartAgendaWidgetView(entry: entry)
        }
        .configurationDisplayName("智能课间")
        .description("自动挑出最该看的一条：考试、上课、待办或纪念日。")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}
