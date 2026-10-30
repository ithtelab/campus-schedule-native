import Foundation

enum CampusSchedulePhase: String, Sendable {
    case freeReading, preparing, moving, inClass, betweenClasses, finished
}

struct CampusScheduleContext: Equatable, Sendable {
    var phase: CampusSchedulePhase
    var occurrenceID: String?
    var room: String?

    var stableState: CampusCharacterState {
        switch phase {
        case .freeReading, .inClass: .seatedReading
        case .preparing: .standingReading
        case .moving: .standingEmpty
        case .betweenClasses, .finished: .seatedEmpty
        }
    }
    var response: CampusCharacterAction {
        switch phase {
        case .freeReading, .inClass: .turnPage
        case .preparing: .prepareCourse
        case .moving: .walk
        case .betweenClasses: .rest
        case .finished: .stretch
        }
    }
    var interactionTitle: String {
        switch phase {
        case .freeReading: "翻一页"
        case .preparing: "准备上课"
        case .moving: "准备换教室"
        case .inClass: "翻一页"
        case .betweenClasses: "歇一歇"
        case .finished: "放松一下"
        }
    }

    static func make(items: [CourseOccurrence], now: Date, leadMinutes: Int) -> Self {
        let today = items.filter { ScheduleRules.calendar.isDate($0.start, inSameDayAs: now) }.sorted { $0.start < $1.start }
        if let active = today.first(where: { $0.start <= now && $0.end > now }) {
            return .init(phase: .inClass, occurrenceID: active.id, room: active.room)
        }
        let previous = today.last { $0.end <= now }
        guard let next = today.first(where: { $0.start > now }) else {
            return .init(phase: today.isEmpty ? .freeReading : .finished, occurrenceID: previous?.id, room: previous?.room)
        }
        let lead = TimeInterval(min(120, max(0, leadMinutes)) * 60)
        if now >= next.start.addingTimeInterval(-lead) {
            let moves = previous.map { ScheduleRules.needsMove(from: $0.room, to: next.room) == true } ?? false
            return .init(phase: moves ? .moving : .preparing, occurrenceID: next.id, room: next.room)
        }
        return .init(phase: previous == nil ? .freeReading : .betweenClasses, occurrenceID: next.id, room: next.room)
    }
}
