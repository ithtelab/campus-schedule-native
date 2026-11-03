import Foundation

struct CampusWidgetInteraction: Codable, Equatable, Sendable {
    var contextKey: String
    var responding: Bool
}

/// 组件只保存回应状态；课程、教室和时间仍由课表决定。
enum CampusWidgetCharacterPlan {
    static func key(context: CampusScheduleContext, now: Date) -> String {
        let day = Int(ScheduleRules.calendar.startOfDay(for: now).timeIntervalSince1970)
        return "\(day)|\(context.phase.rawValue)|\(context.occurrenceID ?? "free")"
    }

    static func frame(context: CampusScheduleContext, now: Date, interaction: CampusWidgetInteraction?) -> Int {
        guard interaction?.contextKey == key(context: context, now: now), interaction?.responding == true else {
            return context.stableState.frame
        }
        switch context.phase {
        case .freeReading, .inClass: return 1
        case .preparing: return 8
        case .moving: return 10
        case .betweenClasses: return 14
        case .finished: return 15
        }
    }

    static func toggled(context: CampusScheduleContext, now: Date, previous: CampusWidgetInteraction?) -> CampusWidgetInteraction {
        let key = key(context: context, now: now)
        return .init(contextKey: key, responding: previous?.contextKey == key ? !(previous?.responding ?? false) : true)
    }
}
