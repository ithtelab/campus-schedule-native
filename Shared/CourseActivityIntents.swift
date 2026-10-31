import Foundation
import AppIntents
@preconcurrency import ActivityKit

struct EndCourseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "结束本次课程活动" }
    @Parameter(title: "课程实例") var occurrenceID: String
    init() {}
    init(id: String) { occurrenceID = id }
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: SystemSnapshot.group) ?? .standard
        var ended = Set(defaults.stringArray(forKey: "endedOccurrences") ?? [])
        ended.insert(occurrenceID); defaults.set(Array(ended), forKey: "endedOccurrences")
        for activity in Activity<CourseActivityAttributes>.activities where activity.attributes.occurrenceID == occurrenceID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}
