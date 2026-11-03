import Foundation
import AppIntents
@preconcurrency import ActivityKit

struct RespondToCampusCharacterIntent: AppIntent {
    static var title: LocalizedStringResource { "回应校园人物" }
    static var openAppWhenRun: Bool { false }
    func perform() async throws -> some IntentResult {
        let payload = SystemSnapshot.readPayload()
        let now = Date()
        let context = CampusScheduleContext.make(items: payload?.courses ?? [], now: now,
                                                leadMinutes: payload?.reminderLeadMinutes ?? 10)
        let next = CampusWidgetCharacterPlan.toggled(context: context, now: now,
                                                    previous: CampusWidgetInteractionStore.read())
        try CampusWidgetInteractionStore.write(next)
        // Button(intent:) 在 perform 返回后由系统刷新时间线，不使用定时器或逐帧 reload。
        return .result()
    }
}

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
