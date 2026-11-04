import Foundation

/// 纪念事件的提醒计划。
///
/// 与课程提醒分开：课程提醒按上课时间逐次生成，纪念事件只有「某天早上」一个点，
/// 并且每年重复的事件每次只需排最近的一次，跨年后再由应用重新排。
public struct MilestoneReminder: Equatable, Sendable {
    public var date: Date
    public var id: String
    public var title: String
    public var body: String
}

public enum MilestoneReminderPlan {
    /// 提醒发送的钟点。太早会吵到人，太晚一天就过半了。
    public static let hour = 9

    /// 为每条纪念事件生成提醒。
    ///
    /// - 提前 N 天：在到期日减去 N 天的早上提醒一次。
    /// - 到期当天：同样在早上提醒一次，文案是「就是今天」。
    /// - 已经过去或已归档的事件不排提醒。
    /// - 每年重复的事件只排最近一次；应用每次启动重排即可，不需要系统级年重复。
    ///
    /// - Parameters:
    ///   - milestones: 全部纪念事件。
    ///   - now: 参考时刻，早于它的提醒会被丢弃。
    ///   - limit: 最多生成多少条，避免一次写入过多通知（系统上限 64 条）。
    public static func make(_ milestones: [Milestone], now: Date,
                            calendar: Calendar = MilestoneCounter.calendar,
                            limit: Int = 40) -> [MilestoneReminder] {
        var events: [MilestoneReminder] = []
        for milestone in milestones {
            guard milestone.reminderDaysBefore > 0 else { continue }
            let reading = MilestoneCounter.read(milestone, now: now, calendar: calendar)
            guard reading.effectiveDate >= calendar.startOfDay(for: now) else { continue }

            let day = calendar.startOfDay(for: reading.effectiveDate)
            if milestone.reminderDaysBefore > 0,
               let lead = calendar.date(byAdding: .day, value: -milestone.reminderDaysBefore, to: day),
               let at = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: lead),
               at > now {
                events.append(MilestoneReminder(
                    date: at, id: "milestone.\(milestone.id).lead",
                    title: "还有 \(milestone.reminderDaysBefore) 天 · \(milestone.title)",
                    body: "\(dateText(reading.effectiveDate, calendar: calendar)) 就是这一天。"))
            }
            if let at = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day), at > now {
                events.append(MilestoneReminder(
                    date: at, id: "milestone.\(milestone.id).today",
                    title: "就是今天 · \(milestone.title)",
                    body: milestone.direction == .countUp ? "从今天开始累计。" : "别忘了今天。"))
            }
        }
        return Array(events.sorted {
            $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date
        }.prefix(max(0, limit)))
    }

    static func dateText(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 0) 月 \(parts.day ?? 0) 日"
    }
}
