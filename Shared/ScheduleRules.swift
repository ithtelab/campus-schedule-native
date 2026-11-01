import Foundation

struct CourseOccurrence: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var courseID: String
    var title: String
    var room: String
    var start: Date
    var end: Date
    var nextTitle: String?
    var nextRoom: String?
    var remindersEnabled = true

    /// 这条安排相对课程原定时间发生了调整。
    ///
    /// 学生按原时间地点跑一趟才发现改了，因此界面必须显式提示。
    var wasRescheduled = false
    /// 原定教室，仅在 `wasRescheduled` 且教室变化时有值。
    var originalRoom: String?
    /// 是否属于单双周课程中的一种。用于课表角标。
    var weekPattern: WeekPattern = .everyWeek
}

/// 课程的周次规律，只用于界面提示。
enum WeekPattern: String, Codable, Sendable {
    case everyWeek
    case odd
    case even
    case custom

    /// 从周次集合推断规律。空集合视为整学期。
    static func infer(from weeks: Set<Int>, totalWeeks: Int) -> WeekPattern {
        guard !weeks.isEmpty, weeks.count < totalWeeks else { return .everyWeek }
        let odd = Set(stride(from: 1, through: totalWeeks, by: 2))
        let even = Set(stride(from: 2, through: totalWeeks, by: 2))
        if weeks == odd { return .odd }
        if weeks == even { return .even }
        return .custom
    }

    /// 角标文案，整学期课程没有角标。
    var badge: String? {
        switch self {
        case .everyWeek: nil
        case .odd: "单"
        case .even: "双"
        case .custom: "部分周"
        }
    }
}

enum ScheduleRules {
    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }
    static func week(on date: Date, semesterStart: Date) -> Int {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: semesterStart), to: calendar.startOfDay(for: date)).day ?? 0
        return days < 0 ? 0 : days / 7 + 1
    }
    static func date(day: Date, time: String) -> Date? {
        let pieces = time.split(separator: ":").compactMap { Int($0) }
        guard pieces.count == 2, (0...23).contains(pieces[0]), (0...59).contains(pieces[1]) else { return nil }
        return calendar.date(bySettingHour: pieces[0], minute: pieces[1], second: 0, of: day)
    }
    static func next(in items: [CourseOccurrence], now: Date) -> CourseOccurrence? {
        items.sorted { $0.start < $1.start }.first { $0.end > now }
    }
    static func mergeContinuous(_ items: [CourseOccurrence]) -> [CourseOccurrence] {
        var result: [CourseOccurrence] = []
        for item in items.sorted(by: { $0.start < $1.start }) {
            if let last = result.last,
               last.courseID == item.courseID,
               needsMove(from: last.room, to: item.room) == false,
               calendar.isDate(last.start, inSameDayAs: item.start),
               item.start >= last.end, item.start.timeIntervalSince(last.end) <= 15 * 60 {
                result[result.count - 1].end = item.end
            } else { result.append(item) }
        }
        return result
    }
    static func needsMove(from room: String, to nextRoom: String) -> Bool? {
        func normalized(_ text: String) -> String {
            text.filter { !$0.isWhitespace && $0 != "·" }.lowercased()
        }
        guard !room.isEmpty, !nextRoom.isEmpty, room != "地点待定", nextRoom != "地点待定" else { return nil }
        return normalized(room) != normalized(nextRoom)
    }
}
