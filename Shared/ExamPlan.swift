import Foundation

/// 一场考试。与课程分开存储：考试是一次性的，没有周次概念，
/// 但需要考试日期、时间段、考场与座位号。
public struct Exam: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var courseTitle: String
    public var date: Date
    /// 开始时间，仅取时分；具体日期由 `date` 决定。
    public var startTime: String
    public var endTime: String
    public var room: String
    public var seatNumber: String
    public var notes: String
    public var reminders: ExamReminders?

    public init(id: String = UUID().uuidString, courseTitle: String, date: Date,
                startTime: String, endTime: String, room: String = "",
                seatNumber: String = "", notes: String = "", reminders: ExamReminders? = nil) {
        self.id = id
        self.courseTitle = courseTitle
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.room = room
        self.seatNumber = seatNumber
        self.notes = notes
        self.reminders = reminders
    }
}

public struct ExamReminders: Codable, Equatable, Sendable {
    public var dayBefore = false
    public var beforeStart = false
    var isEnabled: Bool { dayBefore || beforeStart }
}

/// The shared widget receives only the fields needed to show an exam and open it.
struct ExamSession: Codable, Equatable, Sendable {
    let id: String
    let termID: String
    let title: String
    let start: Date
    let end: Date
    let room: String
    let seat: String

    init?(exam: Exam, termID: String) {
        guard let start = ExamPlan.startDate(exam), let end = ExamPlan.endDate(exam), end > start else { return nil }
        id = exam.id
        self.termID = termID
        title = exam.courseTitle
        self.start = start
        self.end = end
        room = exam.room
        seat = exam.seatNumber
    }

    var location: String {
        [room, seat.isEmpty ? "" : "座位 \(seat)"].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    func dateLabel(relativeTo now: Date) -> String {
        let calendar = ScheduleRules.calendar
        let day = calendar.startOfDay(for: start)
        let today = calendar.startOfDay(for: now)
        if day == today { return "今天" }
        if day == calendar.date(byAdding: .day, value: 1, to: today) { return "明天" }
        return "\(calendar.component(.month, from: start))月\(calendar.component(.day, from: start))日"
    }
}

public enum ExamPlan {
    static func nextSession(_ sessions: [ExamSession], now: Date) -> ExamSession? {
        sessions.filter { $0.end > now }.min {
            if $0.start != $1.start { return $0.start < $1.start }
            if $0.termID != $1.termID { return $0.termID < $1.termID }
            return $0.id < $1.id
        }
    }

    static func reminders(for exam: Exam, termID: String, now: Date) -> [CourseReminder] {
        guard let options = exam.reminders, options.isEnabled,
              let session = ExamSession(exam: exam, termID: termID), session.start > now else { return [] }
        let id = "exam.\(termID.utf8.count):\(termID).\(exam.id)"
        let startText = "\(ScheduleRules.time(session.start)) 开考"
        let details = session.location.isEmpty ? startText : "\(startText) · \(session.location)"
        var result: [CourseReminder] = []
        if options.dayBefore, let date = ScheduleRules.calendar.date(byAdding: .day, value: -1, to: session.start), date > now {
            result.append(.init(date: date, id: id + ".day", title: "明天考试 · \(session.title)", body: details))
        }
        let beforeStart = session.start.addingTimeInterval(-30 * 60)
        if options.beforeStart, beforeStart > now {
            result.append(.init(date: beforeStart, id: id + ".soon", title: "30 分钟后开考 · \(session.title)", body: details))
        }
        return result
    }
    /// 即将到来的考试，按开始时间从近到远。已结束的不返回。
    public static func upcoming(_ exams: [Exam], now: Date) -> [Exam] {
        exams.compactMap { exam -> (Exam, Date)? in
            guard let start = startDate(exam) else { return nil }
            return start > now ? (exam, start) : nil
        }
        .sorted { $0.1 < $1.1 }
        .map(\.0)
    }

    /// 全部考试按时间倒序，包含已结束的，用于列表展示。
    public static func chronological(_ exams: [Exam]) -> [Exam] {
        exams.sorted { lhs, rhs in
            let left = startDate(lhs) ?? .distantPast
            let right = startDate(rhs) ?? .distantPast
            return left < right
        }
    }

    /// 距离最近一场考试还有多少天。没有未来考试时返回 nil。
    public static func daysUntilNext(_ exams: [Exam], now: Date) -> Int? {
        guard let next = upcoming(exams, now: now).first, let start = startDate(next) else { return nil }
        let calendar = ScheduleRules.calendar
        let from = calendar.startOfDay(for: now)
        let to = calendar.startOfDay(for: start)
        return calendar.dateComponents([.day], from: from, to: to).day
    }

    /// 考试开始时刻。时分非法时返回 nil，避免显示错误时间。
    ///
    /// 刻意不复用 `ScheduleRules.date`：它接受 `9:00` 这类省略前导零的写法，
    /// 而考试时间需要与导出格式一致，统一要求 HH:mm。
    public static func startDate(_ exam: Exam) -> Date? {
        guard ScheduleArchive.isClockTime(exam.startTime) else { return nil }
        return ScheduleRules.date(day: exam.date, time: exam.startTime)
    }

    public static func endDate(_ exam: Exam) -> Date? {
        guard ScheduleArchive.isClockTime(exam.endTime) else { return nil }
        return ScheduleRules.date(day: exam.date, time: exam.endTime)
    }

    /// 是否已经考完。
    public static func isFinished(_ exam: Exam, now: Date) -> Bool {
        guard let end = endDate(exam) else { return false }
        return end <= now
    }

    /// 校验一场考试是否可以保存。
    public static func validate(_ exam: Exam) -> ExamValidation {
        guard !exam.courseTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .missingTitle
        }
        guard ScheduleArchive.isClockTime(exam.startTime) else { return .malformedTime(exam.startTime) }
        guard ScheduleArchive.isClockTime(exam.endTime) else { return .malformedTime(exam.endTime) }
        guard let start = startDate(exam), let end = endDate(exam) else { return .malformedTime(exam.startTime) }
        guard end > start else { return .endBeforeStart }
        return .valid
    }

    /// 同一天时间重叠的考试，通常意味着录入有误。
    public static func conflicts(in exams: [Exam]) -> [(String, String)] {
        var result: [(String, String)] = []
        let sorted = chronological(exams)
        for index in sorted.indices {
            for other in sorted[(index + 1)...] {
                guard let aStart = startDate(sorted[index]), let aEnd = endDate(sorted[index]),
                      let bStart = startDate(other), let bEnd = endDate(other) else { continue }
                guard ScheduleRules.calendar.isDate(aStart, inSameDayAs: bStart) else { continue }
                if aStart < bEnd && bStart < aEnd {
                    result.append((sorted[index].id, other.id))
                }
            }
        }
        return result
    }
}

public enum ExamValidation: Equatable {
    case valid
    case missingTitle
    case malformedTime(String)
    case endBeforeStart

    public var errorDescription: String? {
        switch self {
        case .valid: nil
        case .missingTitle: "请填写考试科目。"
        case .malformedTime(let value): "时间「\(value)」格式不正确，应为 HH:mm。"
        case .endBeforeStart: "结束时间必须晚于开始时间。"
        }
    }
}
