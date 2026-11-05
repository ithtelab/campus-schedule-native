import SwiftUI
import WidgetKit

struct SmartAgendaWidgetContent: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let family: WidgetFamily
    let selection: SmartAgendaSelection
    let appearance: AppearancePreferences

    private var blue: Bool { appearance.theme == .blueStickers && renderingMode == .fullColor }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Label(selection.primary.map { "\($0.statusWithQuantity) · \($0.title)" } ?? "暂时没有安排",
                      systemImage: selection.primary.map { symbol($0.kind) } ?? "checkmark.circle")
            case .accessoryCircular:
                circular
            case .accessoryRectangular:
                lockRectangular
            default:
                desktop
            }
        }
        .privacySensitive()
        .containerBackground(for: .widget) {
            ZStack {
                Color(uiColor: .secondarySystemBackground)
                if blue { CampusStickerMark.accent.opacity(0.07) }
            }
        }
        .widgetURL(selection.primary.flatMap { deepLink($0.target) })
    }

    private var circular: some View {
        VStack(spacing: 0) {
            if let item = selection.primary {
                Image(systemName: symbol(item.kind)).font(.caption2)
                Text(item.quantity).font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .lineLimit(1).minimumScaleFactor(0.55)
            } else {
                Image(systemName: "checkmark.circle").font(.body)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selection.primary?.accessibilityText ?? "暂时没有安排")
    }

    private var lockRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let item = selection.primary {
                Text(item.statusWithQuantity).font(.caption2.weight(.medium)).lineLimit(1).minimumScaleFactor(0.85)
                Text(item.title).font(.headline).lineLimit(1).minimumScaleFactor(0.85)
                if !item.detailWithSeat.isEmpty {
                    Text(item.detailWithSeat).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
                }
            } else {
                Label("暂时没有安排", systemImage: "checkmark.circle").font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selection.primary?.accessibilityText ?? "暂时没有安排")
    }

    private var desktop: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                if let item = selection.primary { mainCard(item) }
                else { Label("暂时没有安排", systemImage: "checkmark.circle").font(.headline) }
                if family == .systemMedium {
                    Spacer(minLength: 4)
                    footer
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if family == .systemMedium && appearance.density.showsCharacter {
                CampusWidgetFigure(persona: appearance.persona, usesStickers: blue)
                    .frame(width: 52, height: 88)
            }
        }
    }

    private func mainCard(_ item: SmartAgendaItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(item.statusWithQuantity, systemImage: symbol(item.kind))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(blue ? CampusStickerMark.accent : Color.primary)
                .lineLimit(item.kind == .milestone ? 1 : 2).minimumScaleFactor(0.8)
            Text(item.title).font(.headline).lineLimit(2).minimumScaleFactor(0.85)
            if family == .systemSmall, let seat = item.examSeat {
                VStack(alignment: .leading, spacing: 2) {
                    if !item.detail.isEmpty { Text(item.detail).lineLimit(2) }
                    Text(seat).lineLimit(1)
                }
                .font(.caption.weight(.medium)).foregroundStyle(.secondary).minimumScaleFactor(0.85)
            } else if !item.detailWithSeat.isEmpty {
                Text(item.detailWithSeat).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    .lineLimit(2).minimumScaleFactor(0.85)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.accessibilityText)
    }

    @ViewBuilder private var footer: some View {
        if let item = selection.secondary, let url = deepLink(item.target) {
            Link(destination: url) {
                Label("\(item.statusWithQuantity) · \(item.title)", systemImage: symbol(item.kind))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.85)
                    .accessibilityLabel(item.accessibilityText)
            }
            .buttonStyle(.plain)
        } else if selection.overdueCount > 0 {
            Label("还有 \(selection.overdueCount) 项待办已逾期", systemImage: "exclamationmark.circle")
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
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
        case .exam(let id, let termID): ExamDeepLink.url(examID: id, termID: termID)
        case .course(let courseID, let termID, let occurrenceID):
            CourseDeepLink.url(courseID: courseID, termID: termID, occurrenceID: occurrenceID)
        case .task(let courseID, let termID): CourseDeepLink.tasksURL(courseID: courseID, termID: termID)
        case .milestone(let id): MilestoneDeepLink.url(milestoneID: id)
        }
    }
}
