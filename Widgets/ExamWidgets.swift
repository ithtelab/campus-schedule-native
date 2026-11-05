import SwiftUI
import WidgetKit

private struct ExamEntry: TimelineEntry {
    let date: Date
    var session: ExamSession? = nil
    var appearance = AppearancePreferences()
}

private struct ExamProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExamEntry { .init(date: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (ExamEntry) -> Void) {
        completion(entry(at: Date(), payload: SystemSnapshot.readPayload()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExamEntry>) -> Void) {
        let payload = SystemSnapshot.readPayload()
        let now = Date()
        let calendar = ScheduleRules.calendar
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(3600)
        let examDates = (payload?.exams ?? []).flatMap { [$0.start, $0.end] }
        let dates = Set([now, midnight] + examDates.filter { $0 > now && $0 < midnight }).sorted()
        completion(Timeline(entries: dates.map { entry(at: $0, payload: payload) }, policy: .atEnd))
    }

    private func entry(at date: Date, payload: SystemSnapshot.Payload?) -> ExamEntry {
        ExamEntry(date: date, session: ExamPlan.nextSession(payload?.exams ?? [], now: date), appearance: payload?.appearance ?? .init())
    }
}

struct UpcomingExamWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UpcomingExamWidget", provider: ExamProvider()) {
            ExamWidgetView(entry: $0)
        }
        .configurationDisplayName("最近考试")
        .description("查看最近一场考试的时间、考场与座位。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

private struct ExamWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ExamEntry

    var body: some View {
        ExamWidgetContent(family: family, session: entry.session, date: entry.date, appearance: entry.appearance)
    }
}
