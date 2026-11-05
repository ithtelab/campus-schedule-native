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
        /// 组件要独立展示纪念事件，因此一并写入快照。
        /// 旧版本写出的快照没有这个键，解码时缺省为空数组。
        var milestones: [Milestone] = []
        var appearance = AppearancePreferences()

        enum CodingKeys: String, CodingKey {
            case version, generatedAt, courses, reminderLeadMinutes, termID, milestones, appearance
        }

        init(courses: [CourseOccurrence], reminderLeadMinutes: Int? = nil,
             termID: String? = nil, milestones: [Milestone] = [], appearance: AppearancePreferences = .init()) {
            self.courses = courses
            self.reminderLeadMinutes = reminderLeadMinutes
            self.termID = termID
            self.milestones = milestones
            self.appearance = appearance
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
            generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt) ?? Date()
            courses = try container.decode([CourseOccurrence].self, forKey: .courses)
            reminderLeadMinutes = try container.decodeIfPresent(Int.self, forKey: .reminderLeadMinutes)
            termID = try container.decodeIfPresent(String.self, forKey: .termID)
            milestones = try container.decodeIfPresent([Milestone].self, forKey: .milestones) ?? []
            appearance = (try? container.decode(AppearancePreferences.self, forKey: .appearance)) ?? .init()
        }
    }
    static func readPayload() -> Payload? {
        guard let url, let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data), payload.version == 1 else { return nil }
        return payload
    }
    static func read() -> [CourseOccurrence] { readPayload()?.courses ?? [] }
    static func readMilestones() -> [Milestone] { readPayload()?.milestones ?? [] }
    static func write(_ courses: [CourseOccurrence], leadMinutes: Int = 10, termID: String? = nil,
                      milestones: [Milestone] = [], appearance: AppearancePreferences = .init()) throws {
        guard let url else { return }
        try JSONEncoder().encode(Payload(courses: courses, reminderLeadMinutes: leadMinutes,
                                        termID: termID, milestones: milestones, appearance: appearance))
            .write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
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
        var blueStickers: Bool? = nil
        var decorationDensity: DecorationDensity? = nil
        var persona: CampusPersona? = nil
        var scheduledStart: Date? = nil
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
