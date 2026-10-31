import SwiftUI

/// Shared by the actual ActivityKit extension and constrained native layout previews.
struct CourseLiveCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    let room: String
    let start: Date
    let end: Date
    var nextRoom: String?
    var stale = false
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                if !typeSize.isAccessibilitySize {
                    Text(stale ? "本次课程已结束" : "课程安排").font(.caption2).foregroundStyle(.secondary)
                }
                Text(title).font(.title3.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                Text(room.isEmpty ? "地点待确认" : room).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 8) {
                    Text("\(ScheduleRules.time(start))–\(ScheduleRules.time(end))").monospacedDigit()
                    if let nextRoom, ScheduleRules.needsMove(from: room, to: nextRoom) == true {
                        Text("下节换教室").lineLimit(1)
                    }
                }.font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                if !stale && !typeSize.isAccessibilitySize {
                    // System-managed range: starts at class time and clamps at the end.
                    ProgressView(timerInterval: start...max(start, end), countsDown: false)
                        .tint(.primary).labelsHidden().frame(height: 3)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if !typeSize.isAccessibilitySize { CampusWidgetFigure().frame(width: 52, height: 90) }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .foregroundStyle(.primary)
    }
}

struct CourseIslandExpanded: View {
    let title: String
    let room: String
    let start: Date
    let end: Date
    var nextTitle: String?
    var nextRoom: String?
    var body: some View {
        HStack(spacing: 12) {
            CampusWidgetFigure().frame(width: 44, height: 72)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).lineLimit(1)
                Text(room).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(ScheduleRules.time(start))–\(ScheduleRules.time(end))").font(.caption.monospacedDigit())
                if let nextTitle {
                    Text("下节 \(nextTitle) · \(nextRoom ?? "地点待确认")").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
