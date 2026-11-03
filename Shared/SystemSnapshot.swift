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
        var reminderLeadMinutes: Int? = nil
        var termID: String? = nil
    }
    static func readPayload() -> Payload? {
        guard let url, let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data), payload.version == 1 else { return nil }
        return payload
    }
    static func read() -> [CourseOccurrence] { readPayload()?.courses ?? [] }
    static func write(_ courses: [CourseOccurrence], leadMinutes: Int = 10, termID: String? = nil) throws {
        guard let url else { return }
        try JSONEncoder().encode(Payload(courses: courses, reminderLeadMinutes: leadMinutes, termID: termID)).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

enum CampusWidgetInteractionStore {
    private static let key = "campusWidgetCharacter-v1"
    static func read() -> CampusWidgetInteraction? {
        guard !SystemSnapshot.group.isEmpty,
              let data = UserDefaults(suiteName: SystemSnapshot.group)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CampusWidgetInteraction.self, from: data)
    }
    static func write(_ value: CampusWidgetInteraction) throws {
        guard !SystemSnapshot.group.isEmpty,
              let defaults = UserDefaults(suiteName: SystemSnapshot.group) else { return }
        defaults.set(try JSONEncoder().encode(value), forKey: key)
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
    /// 教师。收起态灵动岛在课前只放得下课程名，教师用于展开态与锁屏卡片。
    var teacher: String = ""
    var courseID: String? = nil
    var termID: String? = nil
}
