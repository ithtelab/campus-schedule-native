import Foundation

/// 课表汇总统计，用于今日页底部的收尾卡片。
///
/// 只统计已排定的课程次数，不声称「出勤」—— App 无法知道学生是否真的到过教室，
/// 因此文案一律用「节课」而不是「出勤」。
public struct ScheduleSummary: Equatable, Sendable {
    /// 本周课程次数。
    public var weekSessions: Int
    /// 本月课程次数。
    public var monthSessions: Int
    /// 本月已经上完的次数。
    public var monthCompleted: Int
    /// 今天还有几节。
    public var todayRemaining: Int
    /// 今天已上完几节。
    public var todayCompleted: Int

    public init(weekSessions: Int = 0, monthSessions: Int = 0, monthCompleted: Int = 0,
                todayRemaining: Int = 0, todayCompleted: Int = 0) {
        self.weekSessions = weekSessions
        self.monthSessions = monthSessions
        self.monthCompleted = monthCompleted
        self.todayRemaining = todayRemaining
        self.todayCompleted = todayCompleted
    }

    /// 汇总一批课程实例。
    ///
    /// - Parameters:
    ///   - occurrences: 学期全部课程实例（已按周次展开）。
    ///   - now: 参考时刻。
    ///   - semesterStart: 学期第一周周一，用于定位「本周」。
    static func make(occurrences: [CourseOccurrence], now: Date,
                            semesterStart: Date) -> ScheduleSummary {
        let calendar = ScheduleRules.calendar
        let currentWeek = max(1, ScheduleRules.week(on: now, semesterStart: semesterStart))
        let today = calendar.startOfDay(for: now)
        var result = ScheduleSummary()

        // 第 n 周从开学日往后 (n-1)*7 天开始。
        let weekStart = calendar.date(byAdding: .day, value: (currentWeek - 1) * 7,
                                      to: calendar.startOfDay(for: semesterStart))
        let weekEnd = weekStart.flatMap { calendar.date(byAdding: .day, value: 7, to: $0) }

        for item in occurrences {
            if let weekStart, let weekEnd, item.start >= weekStart, item.start < weekEnd {
                result.weekSessions += 1
            }
            // 本月：以课程开始时刻所在月份为准。
            if calendar.isDate(item.start, equalTo: now, toGranularity: .month) {
                result.monthSessions += 1
                if item.end <= now { result.monthCompleted += 1 }
            }
            if calendar.isDate(item.start, inSameDayAs: today) {
                if item.end <= now { result.todayCompleted += 1 }
                else if item.start > now { result.todayRemaining += 1 }
            }
        }
        return result
    }

    /// 本月完成比例，用于进度条。本月无课返回 nil，避免显示 0/0。
    public var monthProgress: Double? {
        guard monthSessions > 0 else { return nil }
        return Double(monthCompleted) / Double(monthSessions)
    }
}
