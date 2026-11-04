import SwiftUI
import WidgetKit
import AppIntents

/// 组件配置里可选的一个事件。
///
/// 用实体而不是裸标识符：长按配置时能直接看到事件名，而不是手输一个 UUID。
/// 候选从 App Group 快照里读，与 App 内的顺序保持一致。
struct MilestoneEntity: AppEntity, Identifiable, Codable, Hashable, Sendable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "纪念事件" }
    /// 计算属性而不是存储属性：`defaultQuery` 是协议要求的静态属性，
    /// 存成 `static var` 会成为非 Sendable 的全局可变状态，在 Swift 6 下编译不过。
    static var defaultQuery: MilestoneEntityQuery { MilestoneEntityQuery() }

    var id: String
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: title))
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
    var appearance = AppearancePreferences()
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
        let payload = SystemSnapshot.readPayload()
        let all = payload?.milestones ?? []
        return MilestoneEntry(date: now,
                              milestone: MilestoneWidgetSelection.pick(from: all, id: configuration.milestone?.id, now: now),
                              configuredID: configuration.milestone?.id,
                              appearance: payload?.appearance ?? .init())
    }
}

struct MilestoneWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    var entry: MilestoneEntry
    private var usesBlueInk: Bool { entry.appearance.showsBlueStickers && renderingMode == .fullColor }

    var body: some View {
        Group {
            if let item = entry.milestone {
                let reading = MilestoneCounter.read(item, now: entry.date)
                switch family {
                case .accessoryInline:
                    if entry.appearance.showsBlueStickers {
                        Label(MilestoneFormat.sentence(item, reading: reading), systemImage: "paperplane.fill")
                    } else {
                        Text(MilestoneFormat.sentence(item, reading: reading))
                    }
                case .accessoryCircular:
                    VStack(spacing: 0) {
                        if entry.appearance.showsBlueStickers {
                            CampusStickerMark(symbol: item.category.symbol, size: 11, fullColor: false)
                        } else {
                            Image(systemName: item.category.symbol).font(.caption2)
                        }
                        Text(MilestoneFormat.number(reading))
                            .font(.system(size: 15, weight: .semibold).monospacedDigit())
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .accessibilityLabel(MilestoneFormat.sentence(item, reading: reading))
                case .accessoryRectangular:
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title).font(.caption.weight(.semibold)).lineLimit(1)
                        Text(MilestoneFormat.number(reading))
                            .font(.system(size: 20, weight: .bold).monospacedDigit())
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text(MilestoneFormat.counterCaption(item, reading: reading))
                            .font(.caption2).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, entry.appearance.showsBlueStickers ? 19 : 0)
                    .overlay(alignment: .trailing) {
                        if entry.appearance.showsBlueStickers {
                            CampusStickerMark(size: 14, fullColor: false)
                        }
                    }
                default:
                    desktop(item, reading: reading)
                }
            } else {
                empty
            }
        }
        .widgetURL(MilestoneDeepLink.url(milestoneID: entry.milestone?.id))
    }

    /// 中号以分类邮戳呼应 App 的日期卡，小号留给名称、数字和日期。
    private func desktop(_ item: Milestone, reading: MilestoneReading) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if entry.appearance.showsBlueStickers {
                        CampusStickerMark(symbol: item.category.symbol, size: 11, fullColor: usesBlueInk)
                    } else {
                        Image(systemName: item.category.symbol).font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(item.title).font(.caption.weight(.medium)).lineLimit(1)
                }
                Text(MilestoneFormat.number(reading))
                    .font(.system(size: family == .systemMedium ? 40 : 32, weight: .bold).monospacedDigit())
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text(MilestoneFormat.counterCaption(item, reading: reading))
                    .font(.caption.weight(.medium)).lineLimit(1)
                Text(MilestoneFormat.dateText(reading.effectiveDate, relativeTo: entry.date))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if family == .systemMedium {
                Image(systemName: item.category.symbol)
                    .font(.system(size: 32, weight: .light))
                    .frame(width: 76, height: 76)
                    .overlay { Circle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [2, 3])) }
                    .foregroundStyle(usesBlueInk ? CampusStickerMark.ink : .secondary)
                    .rotationEffect(.degrees(-12))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MilestoneFormat.sentence(item, reading: reading))
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 4) {
            if entry.appearance.showsBlueStickers {
                CampusStickerMark(size: 13, fullColor: usesBlueInk)
            } else {
                Image(systemName: "flag").font(.caption).foregroundStyle(.secondary)
            }
            Text(entry.configuredID == nil ? "添加纪念事件" : "事件已归档或移除")
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
