import Foundation

public struct CourseTask: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public let courseID: String
    public var title = ""
    public var due: Date?
    public var isCompleted = false

    var isValid: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    static func isValid(_ tasks: [Self], courseIDs: Set<String>) -> Bool {
        Set(tasks.map(\.id)).count == tasks.count && tasks.allSatisfy { $0.isValid && courseIDs.contains($0.courseID) }
    }

    static func ordered(_ tasks: [Self]) -> [Self] {
        tasks.sorted {
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            return ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture)
        }
    }

    static func dueSoon(_ tasks: [Self], now: Date) -> [Self] {
        let horizon = ScheduleRules.calendar.date(byAdding: .day, value: 7, to: now) ?? now
        return Array(ordered(tasks.filter { task in
            !task.isCompleted && task.due.map { $0 <= horizon } == true
        }).prefix(3))
    }
}
