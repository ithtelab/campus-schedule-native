import Foundation

/// 纪念事件的展示文案。
///
/// 放在 Shared 里是因为 App 页面、通知和组件需要同一套写法：组件不能引用
/// App 层的视图文件，把文案拆到这里才不会出现「App 说第 365 天、组件说 365 天」
/// 这类不一致。
public enum MilestoneFormat {
    /// 紧凑主文案，用于列表右侧与组件：天数或「就是今天」。
    public static func primary(_ item: Milestone, reading: MilestoneReading) -> String {
        switch reading.state {
        case .today:
            return "就是今天"
        case .upcoming(let days):
            return "\(days) 天"
        case .past(let days):
            switch item.direction {
            case .countdown: return "已过 \(days) 天"
            case .countUp: return "第 \(days) 天"
            }
        }
    }

    /// 完整一句，用于无障碍朗读与详情卡片。
    public static func sentence(_ item: Milestone, reading: MilestoneReading) -> String {
        let title = item.title.isEmpty ? "这件事" : item.title
        switch reading.state {
        case .today:
            return "\(title)就是今天"
        case .upcoming(let days):
            switch item.direction {
            case .countdown: return "距\(title)还有 \(days) 天"
            case .countUp: return "距\(title)开始还有 \(days) 天"
            }
        case .past(let days):
            switch item.direction {
            case .countdown: return "\(title)已过去 \(days) 天"
            case .countUp: return "\(title)第 \(days) 天"
            }
        }
    }

    /// 大号数字。组件里天数与单位分开排版，因此只取数字部分。
    public static func number(_ reading: MilestoneReading) -> String {
        reading.state == .today ? "今天" : String(reading.dayCount)
    }

    public static func counterCaption(_ item: Milestone, reading: MilestoneReading) -> String {
        if item.countsRelationshipDays {
            switch reading.state {
            case .today: return "故事从今天开始"
            case .past: return "一起走过 · 天"
            case .upcoming: return "距离故事开始 · 天"
            }
        }
        return switch reading.state {
        case .today: "就是这一天"
        case .upcoming: item.direction == .countUp ? "距离开始 · 天" : "还有 · 天"
        case .past: item.direction == .countUp ? "累计 · 天" : "已过 · 天"
        }
    }

    public static func relationshipHighlight(_ item: Milestone, reading: MilestoneReading) -> String? {
        guard item.countsRelationshipDays else { return nil }
        let elapsed: Int
        switch reading.state {
        case .upcoming: return nil
        case .today: elapsed = 0
        case .past(let days): elapsed = days
        }

        let markers = [(100, "百日纪念"), (365, "365 天纪念"), (520, "520 天纪念"),
                       (1000, "千日纪念"), (1314, "1314 天纪念")]
        guard let (day, title) = markers.first(where: { $0.0 >= elapsed }) else { return nil }
        if day == elapsed { return "今天是\(title)" }
        return "距离\(title)还有 \(day - elapsed) 天"
    }

    /// 日期文案。非今年的日期带上年份，否则「3 月 15 日」看不出是哪一年。
    public static func dateText(_ date: Date, relativeTo now: Date = Date(),
                                calendar: Calendar = MilestoneCounter.calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let thisYear = calendar.component(.year, from: now)
        let text = "\(parts.month ?? 0) 月 \(parts.day ?? 0) 日"
        guard let year = parts.year, year != thisYear else { return text }
        return "\(year) 年 \(text)"
    }
}
