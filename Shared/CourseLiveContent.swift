import SwiftUI

/// Shared by the actual ActivityKit extension and constrained native layout previews.
struct CourseLiveCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    let room: String
    let start: Date
    let end: Date
    var teacher: String = ""
    var nextRoom: String?
    var stale = false
    var blueStickers = false
    var stickerPersona: CampusPersona = .girl
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                if !typeSize.isAccessibilitySize {
                    Text(stale ? "本次课程已结束" : "课程安排").font(.caption2).foregroundStyle(.secondary)
                }
                Text(title).font(.title3.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                // 锁屏卡片是用户最常看的一屏，教师与教室一起给出。
                Text(teacherAndRoom).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
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
            if !typeSize.isAccessibilitySize {
                Group {
                    if blueStickers {
                        CampusStickerStudent(frame: stale ? 3 : 0, wearsCap: stickerPersona != .boy)
                            .frame(width: 49, height: 76)
                    } else {
                        CampusWidgetFigure()
                    }
                }
                .frame(width: 52, height: 90)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .foregroundStyle(.primary)
    }

    /// 教师与教室合并成一行，缺任一项时不留多余分隔符。
    private var teacherAndRoom: String {
        let place = room.isEmpty ? "地点待确认" : room
        guard !teacher.isEmpty else { return place }
        return "\(teacher) · \(place)"
    }
}

struct CourseIslandExpanded: View {
    let title: String
    let room: String
    let start: Date
    let end: Date
    var teacher: String = ""
    var nextTitle: String?
    var nextRoom: String?
    var blueStickers = false
    var stickerPersona: CampusPersona = .girl
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).lineLimit(1).minimumScaleFactor(0.85)
                // 长按展开时空间充裕，把教师、地点、时间一次给全。
                HStack(spacing: 6) {
                    if !teacher.isEmpty {
                        Text(teacher).lineLimit(1)
                        Text("·").foregroundStyle(.tertiary)
                    }
                    Text(room.isEmpty ? "地点待确认" : room).lineLimit(1)
                }
                .font(.subheadline.weight(.semibold)).minimumScaleFactor(0.8)
                HStack(spacing: 6) {
                    Text("\(ScheduleRules.time(start))–\(ScheduleRules.time(end))").monospacedDigit()
                    if let nextTitle {
                        Text("·").foregroundStyle(.tertiary)
                        Text("下节 \(nextTitle) \(nextRoom ?? "")").lineLimit(1)
                    }
                }
                .font(.caption).foregroundStyle(.secondary).minimumScaleFactor(0.8)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if blueStickers {
                    CampusStickerStudent(frame: 0, wearsCap: stickerPersona != .boy)
                } else {
                    CampusWidgetFigure()
                }
            }
            .frame(width: 40, height: 66)
        }
    }
}
