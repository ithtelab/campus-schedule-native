import Foundation
@preconcurrency import ActivityKit

enum SystemSnapshot {
    static let group = Bundle.main.object(forInfoDictionaryKey: "CampusAppGroup") as? String ?? ""
    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("schedule-v1.json")
    }
    struct Payload: Codable {
        var version = 1
        var generatedAt = Date()
        var courses: [CourseOccurrence]
    }
    static func read() -> [CourseOccurrence] {
        guard let url, let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data), payload.version == 1 else { return [] }
        return payload.courses
    }
    static func write(_ courses: [CourseOccurrence]) throws {
        guard let url else { return }
        try JSONEncoder().encode(Payload(courses: courses)).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

struct CourseActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var end: Date
        var nextTitle: String?
        var nextRoom: String?
        var beforeClass: Bool
    }
    var occurrenceID: String
    var title: String
    var room: String
    var start: Date
}
