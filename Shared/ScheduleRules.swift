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
