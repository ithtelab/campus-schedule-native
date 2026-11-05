import SwiftUI
import WidgetKit

struct ExamWidgetContent: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let family: WidgetFamily
    let session: ExamSession?
    let date: Date
    let appearance: AppearancePreferences

    private var blue: Bool { appearance.theme == .blueStickers && renderingMode == .fullColor }

    var body: some View {
        Group {
            if family == .accessoryInline {
                Label(session.map { "\($0.dateLabel(relativeTo: date)) \(ScheduleRules.time($0.start)) \($0.title)" } ?? "暂无考试安排",
                      systemImage: "graduationcap")
                    .privacySensitive()
            } else if family == .accessoryRectangular {
                lockCard
            } else {
                homeCard
            }
        }
        .containerBackground(for: .widget) {
            ZStack {
                Color(uiColor: .secondarySystemBackground)
                if blue { CampusStickerMark.accent.opacity(0.07) }
            }
        }
        .widgetURL(ExamDeepLink.url(examID: session?.id, termID: session?.termID))
    }

    private var lockCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let session {
                Text(session.title).font(.headline).lineLimit(1)
                Text(when(session)).font(.caption.monospacedDigit()).lineLimit(1)
                if !session.location.isEmpty {
                    Text(session.location).font(.caption2).lineLimit(1).minimumScaleFactor(0.85)
                }
            } else {
                Label("最近考试", systemImage: "graduationcap").font(.headline)
                Text("暂无考试安排").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .privacySensitive()
    }

    private var homeCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label("最近考试", systemImage: "graduationcap").font(.caption2.weight(.semibold))
                    .foregroundStyle(blue ? CampusStickerMark.accent : Color.secondary)
                if let session {
                    Text(session.title).font(.headline).lineLimit(2)
                    Text(when(session)).font(.caption.monospacedDigit().weight(.medium)).lineLimit(1)
                    Spacer(minLength: 0)
                    if !session.room.isEmpty { Text(session.room).font(.caption.weight(.semibold)).lineLimit(1) }
                    if !session.seat.isEmpty { Text("座位 \(session.seat)").font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                } else {
                    Spacer(minLength: 0)
                    Text("暂无考试安排").font(.headline)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .privacySensitive()

            if family == .systemMedium && appearance.density.showsCharacter {
                CampusWidgetFigure(persona: appearance.persona, usesStickers: blue)
                    .frame(width: 52, height: 88)
            }
        }
    }

    private func when(_ exam: ExamSession) -> String {
        if exam.start <= date { return "考试中 · \(ScheduleRules.time(exam.end)) 结束" }
        return "\(exam.dateLabel(relativeTo: date)) · \(ScheduleRules.time(exam.start))"
    }
}
