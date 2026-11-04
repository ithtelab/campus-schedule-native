import SwiftUI
import WidgetKit
import AppIntents

/// 组件配置里可选的一个事件。
///
/// 用实体而不是裸标识符：长按配置时能直接看到事件名，而不是手输一个 UUID。
/// 候选从 App Group 快照里读，与 App 内的顺序保持一致。
struct MilestoneEntity: AppEntity, Identifiable, Codable, Hashable, Sendable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "纪念事件" }
    static var defaultQuery = MilestoneEntityQuery()

    var id: String
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct MilestoneEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [MilestoneEntity] {
        let all = SystemSnapshot.readMilestones()
        return identifiers.compactMap { id in
            all.first { $0.id == id }.map { MilestoneEntity(id: $0.id, title: $0.title) }
        }
    }

    func suggestedEntities() async throws -> [MilestoneEntity] {
        let now = Date()
        return MilestoneCounter.sorted(SystemSnapshot.readMilestones(), now: now)
            .filter { !MilestoneCounter.read($0, now: now).isHidden(expiry: $0.expiry) }
            .map { MilestoneEntity(id: $0.id, title: $0.title) }
    }
}

/// 纪念事件组件的配置。每个组件可以单独选一个事件，
/// 不必先置顶到今日页，也不必和课程组件绑在一起。
struct MilestoneWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "纪念事件" }
    static var description: IntentDescription { IntentDescription("选择一个纪念日或倒数日。") }

    @Parameter(title: "事件")
    var milestone: MilestoneEntity?
}

/// 组件展示的单个事件投影。
enum MilestoneWidgetSelection {
    /// 未指定事件时取最近的一个；指定的事件已被删除时返回 nil，
    /// 让组件显示空状态，而不是继续展示一个打不开的旧链接。
    static func pick(from milestones: [Milestone], id: String?, now: Date) -> Milestone? {
        let visible = MilestoneCounter.sorted(milestones, now: now)
            .filter { !MilestoneCounter.read($0, now: now).isHidden(expiry: $0.expiry) }
        if let id { return visible.first { $0.id == id } }
        return visible.first
    }
}

struct MilestoneEntry: TimelineEntry {
    var date: Date
    var milestone: Milestone?
    /// 用户配置过事件，但那条事件已被删除或归档。
    var configuredID: String?
}

struct MilestoneProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MilestoneEntry {
        MilestoneEntry(date: Date(), milestone: nil, configuredID: nil)
    }

    func snapshot(for configuration: MilestoneWidgetConfiguration, in context: Context) async -> MilestoneEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: MilestoneWidgetConfiguration, in context: Context) async -> Timeline<MilestoneEntry> {
        let entry = entry(for: configuration)
        // 天数按日历日变化，下一个零点刷新一次即可，不必每小时重建。
        let calendar = MilestoneCounter.calendar
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: entry.date))
            ?? entry.date.addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(nextMidnight))
    }

    private func entry(for configuration: MilestoneWidgetConfiguration) -> MilestoneEntry {
        let now = Date()
        let all = SystemSnapshot.readMilestones()
        return MilestoneEntry(date: now,
                              milestone: MilestoneWidgetSelection.pick(from: all, id: configuration.milestone?.id, now: now),
                              configuredID: configuration.milestone?.id)
    }
}

struct MilestoneWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: MilestoneEntry

    var body: some View {
        Group {
            if let item = entry.milestone {
                let reading = MilestoneCounter.read(item, now: entry.date)
                switch family {
                case .accessoryInline:
                    Text(MilestoneFormat.sentence(item, reading: reading))
                case .accessoryCircular:
                    VStack(spacing: 0) {
                        Image(systemName: item.category.symbol).font(.caption2)
                        Text(MilestoneFormat.number(reading))
                            .font(.system(size: 15, weight: .semibold).monospacedDigit())
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                case .accessoryRectangular:
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title).font(.caption.weight(.semibold)).lineLimit(1)
                        Text(MilestoneFormat.number(reading))
                            .font(.system(size: 20, weight: .bold).monospacedDigit())
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text(MilestoneFormat.dateText(reading.effectiveDate, relativeTo: entry.date))
                            .font(.caption2).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                default:
                    desktop(item, reading: reading)
                }
            } else {
                empty
            }
        }
        .widgetURL(MilestoneDeepLink.url(milestoneID: entry.milestone?.id))
    }

    /// 桌面尺寸。小号只放一个事件，中号把人物放在右侧。
    private func desktop(_ item: Milestone, reading: MilestoneReading) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: item.category.symbol).font(.caption2).foregroundStyle(.secondary)
                    Text(item.title).font(.caption.weight(.medium)).lineLimit(1)
                }
                Text(MilestoneFormat.number(reading))
                    .font(.system(size: family == .systemMedium ? 40 : 32, weight: .bold).monospacedDigit())
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text(MilestoneFormat.primary(item, reading: reading))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if family == .systemMedium {
                CampusWidgetFigure(frame: 0)
                    .frame(width: 62, height: 108, alignment: .bottom)
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "flag").font(.caption).foregroundStyle(.secondary)
            Text(entry.configuredID == nil ? "添加纪念事件" : "事件已删除")
                .font(.caption.weight(.medium)).lineLimit(2)
            Text(entry.configuredID == nil ? "在设置里记录毕业、生日这类日期。" : "长按组件重新选择事件。")
                .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct MilestoneWidget: Widget {
    let kind = "MilestoneWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: MilestoneWidgetConfiguration.self,
                               provider: MilestoneProvider()) { entry in
            MilestoneWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("纪念事件")
        .description("倒数日或累计日，独立于课程组件")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}
