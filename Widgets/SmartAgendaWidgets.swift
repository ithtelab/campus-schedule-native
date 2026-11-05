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
    var options = SmartAgendaOptions()
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
        return SmartAgendaEntry(date: now, selection: Self.placeholderSelection(now: now))
    }

    func snapshot(for configuration: SmartAgendaConfiguration, in context: Context) async -> SmartAgendaEntry {
        // 占位与快照都必须有内容，否则组件在编辑预览里显示空白表格。
        entry(for: configuration, at: Date(), lockScreen: isLockScreenFamily(context.family))
    }

    func timeline(for configuration: SmartAgendaConfiguration, in context: Context) async -> Timeline<SmartAgendaEntry> {
        let now = Date()
        let payload = SystemSnapshot.readPayload()
        let options = resolveOptions(configuration, lockScreen: isLockScreenFamily(context.family))
        let first = entry(for: configuration, at: now, lockScreen: isLockScreenFamily(context.family))
        let dates = SmartAgenda.switchDates(
            courses: payload?.courses ?? [], exams: payload?.exams ?? [],
            tasks: payload?.tasks ?? [], milestones: payload?.milestones ?? [],
            now: now, leadMinutes: payload?.reminderLeadMinutes ?? 10,
            options: options, limit: 20)
        // 每次求值都用同一个配置与快照，保证切换点之间状态连续。
        let entries = dates.map { entry(for: configuration, at: $0, lockScreen: isLockScreenFamily(context.family)) }
        return Timeline(entries: entries.isEmpty ? [first] : entries, policy: .atEnd)
    }

    private func resolveOptions(_ configuration: SmartAgendaConfiguration, lockScreen: Bool) -> SmartAgendaOptions {
        let defaults = SmartAgendaOptions.defaults(forLockScreen: lockScreen)
        return SmartAgendaOptions(
            allowTasks: configuration.allowTasks ?? defaults.allowTasks,
            allowMilestones: configuration.allowMilestones ?? defaults.allowMilestones,
            milestoneID: configuration.milestone?.id)
    }

    private func entry(for configuration: SmartAgendaConfiguration, at date: Date, lockScreen: Bool) -> SmartAgendaEntry {
        let payload = SystemSnapshot.readPayload()
        let options = resolveOptions(configuration, lockScreen: lockScreen)
        let selection = SmartAgenda.select(
            courses: payload?.courses ?? [], exams: payload?.exams ?? [],
            tasks: payload?.tasks ?? [], milestones: payload?.milestones ?? [],
            now: date, leadMinutes: payload?.reminderLeadMinutes ?? 10, options: options)
        return SmartAgendaEntry(date: date, selection: selection,
                                appearance: payload?.appearance ?? .init(), options: options)
    }

    /// 编辑预览用。没有真实数据时也要能看出排版，不能只显示空状态。
    static func placeholderSelection(now: Date) -> SmartAgendaSelection {
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

struct SmartAgendaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SmartAgendaEntry

    private var blue: Bool { entry.appearance.theme == .blueStickers }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                inline
            case .accessoryCircular:
                circular
            case .accessoryRectangular:
                lockRectangular
            case .systemSmall:
                small
            default:
                medium
            }
        }
        .containerBackground(for: .widget) {
            ZStack {
                Color(uiColor: .secondarySystemBackground)
                if blue { CampusStickerMark.accent.opacity(0.07) }
            }
        }
        .widgetURL(entry.selection.primary.map { deepLink($0.target) } ?? nil)
    }

    // MARK: 锁屏

    private var inline: some View {
        Group {
            if let item = entry.selection.primary {
                Label(inlineText(item), systemImage: symbol(item.kind))
            } else {
                Label("暂时没有安排", systemImage: "checkmark.circle")
            }
        }
        .privacySensitive()
    }

    private var circular: some View {
        VStack(spacing: 0) {
            if let item = entry.selection.primary {
                Image(systemName: symbol(item.kind)).font(.caption2)
                Text(item.value.isEmpty ? item.status : item.value)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .lineLimit(1).minimumScaleFactor(0.55)
            } else {
                Image(systemName: "checkmark.circle").font(.body)
            }
        }
        .privacySensitive()
    }

    private var lockRectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let item = entry.selection.primary {
                Text(item.status).font(.caption2).lineLimit(1)
                HStack(spacing: 4) {
                    Text(item.title).font(.headline).lineLimit(1)
                    if !item.detail.isEmpty {
                        Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            } else {
                Label("暂时没有安排", systemImage: "checkmark.circle").font(.headline)
                Text("今天没有紧急事项").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .privacySensitive()
    }

    // MARK: 桌面

    private var small: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let item = entry.selection.primary {
                header(item)
                titleRow(item, size: 17)
                Spacer(minLength: 0)
                valueLine(item)
            } else {
                emptyHome
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .privacySensitive()
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                if let item = entry.selection.primary {
                    header(item)
                    titleRow(item, size: 20)
                    if !item.detail.isEmpty {
                        Text(item.detail).font(.subheadline.weight(.medium)).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    valueLine(item)
                } else {
                    emptyHome
                }
                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if entry.appearance.density.showsCharacter {
                CampusWidgetFigure(persona: entry.appearance.persona, usesStickers: blue)
                    .frame(width: 56, height: 96, alignment: .bottom)
            }
        }
        .privacySensitive()
    }

    /// 中号底部：一条不同类别的补充，以及逾期待办的提示。
    @ViewBuilder private var footer: some View {
        if let secondary = entry.selection.secondary {
            HStack(spacing: 5) {
                Image(systemName: symbol(secondary.kind)).font(.caption2)
                Text("\(secondary.status) · \(secondary.title)")
                    .font(.caption2).lineLimit(1).minimumScaleFactor(0.85)
            }
            .foregroundStyle(.secondary)
        } else if entry.selection.overdueCount > 0 {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.circle").font(.caption2)
                Text("还有 \(entry.selection.overdueCount) 项待办已逾期").font(.caption2).lineLimit(1)
            }
            .foregroundStyle(.secondary)
        }
    }

    private func header(_ item: SmartAgendaItem) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol(item.kind)).font(.caption2)
            Text(item.status).font(.caption2.weight(.semibold)).lineLimit(1)
        }
        .foregroundStyle(blue ? CampusStickerMark.accent : Color.secondary)
    }

    private func titleRow(_ item: SmartAgendaItem, size: CGFloat) -> some View {
        Text(item.title)
            .font(.system(size: size, weight: .bold))
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }

    /// 主数值：课程与考试是时刻，纪念事件是「数字 + 单位」。
    @ViewBuilder private func valueLine(_ item: SmartAgendaItem) -> some View {
        if item.unit.isEmpty {
            Text(item.value).font(.title3.weight(.semibold).monospacedDigit()).lineLimit(1)
                .minimumScaleFactor(0.8)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(item.value).font(.title.weight(.bold).monospacedDigit()).lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(item.unit).font(.caption.weight(.medium))
            }
        }
    }

    private var emptyHome: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: "checkmark.circle").font(.caption).foregroundStyle(.secondary)
            Text("暂时没有安排").font(.headline).lineLimit(2)
            Text("添加课程或考试后会显示在这里").font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 文案

    private func inlineText(_ item: SmartAgendaItem) -> String {
        let body = item.unit.isEmpty ? item.value : "\(item.value)\(item.unit)"
        return [item.status, item.title, body].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func symbol(_ kind: SmartAgendaItem.Kind) -> String {
        switch kind {
        case .exam: "graduationcap"
        case .course: "book.closed"
        case .task: "checklist"
        case .milestone: "flag"
        }
    }

    private func deepLink(_ target: SmartAgendaItem.Target) -> URL? {
        switch target {
        case .exam(let id, let termID):
            return ExamDeepLink.url(examID: id, termID: termID)
        case .course(let courseID, let termID, let occurrenceID):
            return CourseDeepLink.url(courseID: courseID, termID: termID, occurrenceID: occurrenceID)
        case .task(let courseID, let termID):
            // 待办没有独立页面，打开所属课程后即可看到该课程的清单。
            return CourseDeepLink.url(courseID: courseID, termID: termID)
        case .milestone(let id):
            return MilestoneDeepLink.url(milestoneID: id)
        }
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
