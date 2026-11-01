import Foundation

/// 课表顶部的「现在该做什么」提示。
///
/// 学生最高频的问题是「我现在在哪、还有多久下课」。这类信息应当在打开课表时
/// 立刻可见，而不是切到今日页去找。
public enum NowStatus {

    public enum Phase: Equatable, Sendable {
        /// 正在上课。
        case inClass(title: String, room: String, minutesLeft: Int)
        /// 距离下一节还有一段时间。
        case upcoming(title: String, room: String, minutesUntil: Int, startsAt: String)
        /// 今天的课已全部结束。
        case finished(classesToday: Int)
        /// 今天没有课。
        case none
    }

    /// 「即将开始」的提前量（分钟）。仅用于决定文案措辞，不影响功能。
    public static let soonWindowMinutes = 30

    /// 由当天的课程实例推导状态。
    ///
    /// - Parameters:
    ///   - occurrences: 课程实例，函数内部按当天与开始时间筛选排序。
    ///   - now: 当前时刻。
    static func phase(for occurrences: [CourseOccurrence], now: Date) -> Phase {
        let calendar = ScheduleRules.calendar
        let today = occurrences
            .filter { calendar.isDate($0.start, inSameDayAs: now) }
            .sorted { $0.start < $1.start }
        guard !today.isEmpty else { return .none }

        // 正在上课：开始已到、结束未到。若有多节重叠，取最早开始的那节。
        if let current = today.first(where: { $0.start <= now && $0.end > now }) {
            let minutes = Int(ceil(current.end.timeIntervalSince(now) / 60))
            return .inClass(title: current.title, room: current.room, minutesLeft: max(0, minutes))
        }
        // 下一节还没开始。
        if let next = today.first(where: { $0.start > now }) {
            let minutes = Int(ceil(next.start.timeIntervalSince(now) / 60))
            return .upcoming(title: next.title, room: next.room,
                             minutesUntil: max(0, minutes), startsAt: clock(next.start))
        }
        // 全部结束。
        return .finished(classesToday: today.count)
    }

    /// 状态条的主文案。没有当天课程时返回 nil，由调用方决定不显示。
    public static func title(_ phase: Phase) -> String? {
        switch phase {
        case .inClass(let title, _, _), .upcoming(let title, _, _, _): title
        case .finished, .none: nil
        }
    }

    /// 状态条的副文案：地点与时间信息。
    public static func detail(_ phase: Phase) -> String? {
        switch phase {
        case .inClass(_, let room, let minutes):
            let left = minutes <= 0 ? "即将下课" : "还有 \(minutes) 分钟下课"
            let place = shorten(room)
            return place.isEmpty ? left : "\(place) · \(left)"
        case .upcoming(_, let room, let minutes, let startsAt):
            // 半小时内用「N 分钟后」更直观，更远时给出具体时间。
            let until = minutes <= soonWindowMinutes ? "\(minutes) 分钟后" : "\(startsAt) 开始"
            let place = shorten(room)
            return place.isEmpty ? until : "\(place) · \(until)"
        case .finished, .none:
            return nil
        }
    }

    /// 是否处于「正在上课」状态，用于决定强调配色。
    public static func isUrgent(_ phase: Phase) -> Bool {
        if case .inClass = phase { return true }
        return false
    }

    /// 一周的进度摘要：「已上 3/8 次」。
    ///
    /// 学生关心的是这周还剩多少，而不是总共有多少。已上的课用结束时刻判断，
    /// 正在上的那节算作未完成，因为还没下课。
    public struct WeekProgress: Equatable, Sendable {
        public var completed: Int
        public var total: Int

        public init(completed: Int, total: Int) {
            self.completed = completed
            self.total = total
        }

        public var remaining: Int { max(0, total - completed) }

        /// 全部上完时给出明确文案，否则显示进度。
        public var text: String {
            guard total > 0 else { return "本周无课" }
            return completed >= total ? "本周 \(total) 次课已上完" : "本周 \(completed)/\(total) 次课"
        }
    }

    /// 统计某一周的完成情况。
    static func weekProgress(for occurrences: [CourseOccurrence],
                                    week: Int, semesterStart: Date, now: Date) -> WeekProgress {
        let calendar = ScheduleRules.calendar
        let inWeek = occurrences.filter {
            ScheduleRules.week(on: $0.start, semesterStart: semesterStart) == week
        }
        let completed = inWeek.filter { $0.end <= now }.count
        return WeekProgress(completed: completed, total: inWeek.count)
    }

    /// 教室名缩写。课表卡片与状态条共用同一份规则，避免两处写法不一致。
    public static func shorten(_ room: String) -> String {
        room.replacingOccurrences(of: "教学楼 ", with: "")
            .replacingOccurrences(of: "实验楼 · ", with: "实验 ")
            .replacingOccurrences(of: "艺术楼 · ", with: "艺术 ")
            .replacingOccurrences(of: " · ", with: " ")
    }

    /// 当天课程的起始时间文案，状态条外也可能用到。
    public static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = ScheduleRules.calendar.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
