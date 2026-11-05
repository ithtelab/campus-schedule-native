@preconcurrency import ActivityKit
import UIKit

@MainActor final class CourseLiveActivities {
    static let shared = CourseLiveActivities()
    private typealias CourseActivity = Activity<CourseActivityAttributes>

    private var boundaryTask: Task<Void, Never>?
    private var watchTasks: [String: Task<Void, Never>] = [:]
    private var pending: [String: CourseActivity] = [:]
    private var revision = 0
    private(set) var cleanupDeadline: Date?

    private var defaults: UserDefaults { UserDefaults(suiteName: SystemSnapshot.group) ?? .standard }
    private var suppressed: Set<String> {
        get { Set(defaults.stringArray(forKey: "endedOccurrences") ?? []) }
        set { defaults.set(Array(newValue), forKey: "endedOccurrences") }
    }

    private var activities: [CourseActivity] {
        let current = CourseActivity.activities
        let ids = Set(current.map(\.id))
        return (current + pending.values.filter { !ids.contains($0.id) }).filter {
            $0.activityState != .ended && $0.activityState != .dismissed
        }
    }

    func finish(_ activity: Activity<CourseActivityAttributes>, suppress: Bool) async {
        if suppress { suppressed.insert(activity.attributes.occurrenceID) }
        watchTasks.removeValue(forKey: activity.id)?.cancel()
        pending.removeValue(forKey: activity.id)
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    enum StartError: LocalizedError {
        case outsideWindow, notAllowed, dismissed
        var errorDescription: String? {
            switch self {
            case .outsideWindow: "实时活动仅在设置的课前提前量内或上课中开启。"
            case .notAllowed: "请在系统设置中允许此 App 使用实时活动。"
            case .dismissed: "本次课程活动已结束，不会自动重新开启。"
            }
        }
    }

    func start(_ item: CourseOccurrence, scheduledAt: Date? = nil, lead: Int = 10, termID: String? = nil,
               appearance: AppearancePreferences? = nil) throws {
        let now = Date()
        guard item.end > now else { throw StartError.outsideWindow }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw StartError.notAllowed }
        guard !suppressed.contains(item.id) else { throw StartError.dismissed }
        if activities.contains(where: { $0.attributes.occurrenceID == item.id }) { return }
        let attributes = CourseActivityAttributes(occurrenceID: item.id, title: item.title, room: item.room, start: item.start,
                                                  teacher: item.teacher, courseID: item.courseID, termID: termID)
        let appearance = appearance ?? SystemSnapshot.readPayload()?.appearance
        let activity: CourseActivity
        if let scheduledAt, scheduledAt > now, #available(iOS 26.0, *) {
            let content = activityContent(for: item, appearance: appearance, scheduledAt: scheduledAt)
            activity = try CourseActivity.request(attributes: attributes, content: content, pushType: nil, style: .standard,
                alertConfiguration: AlertConfiguration(title: "即将上课", body: "请查看课程安排", sound: .default), start: scheduledAt)
            pending[activity.id] = activity
        } else {
            guard scheduledAt.map({ $0 <= now }) ?? true,
                  CourseLivePlan.canStartManually(item, now: now, lead: lead) else { throw StartError.outsideWindow }
            activity = try CourseActivity.request(attributes: attributes, content: activityContent(for: item, appearance: appearance),
                                                   pushType: nil)
        }
        observe(activity)
        updateCleanupSchedule()
    }

    private func activityContent(for item: CourseOccurrence, appearance: AppearancePreferences?,
                                 scheduledAt: Date? = nil) -> ActivityContent<CourseActivityAttributes.ContentState> {
        ActivityContent(state: .init(end: item.end, nextTitle: item.nextTitle, nextRoom: item.nextRoom,
                                     blueStickers: appearance.map { $0.theme == .blueStickers },
                                     decorationDensity: appearance?.density, persona: appearance?.persona,
                                     scheduledStart: scheduledAt), staleDate: item.end)
    }

    private func observe(_ activity: CourseActivity) {
        guard watchTasks[activity.id] == nil else { return }
        watchTasks[activity.id] = Task { @MainActor in
            defer {
                watchTasks[activity.id] = nil
                pending.removeValue(forKey: activity.id)
                updateCleanupSchedule()
            }
            for await state in activity.activityStateUpdates {
                if Task.isCancelled { break }
                if state == .dismissed { suppressed.insert(activity.attributes.occurrenceID); break }
                if state == .ended { break }
            }
        }
    }

    private func updateCleanupSchedule(force: Bool = false) {
        let deadline = activities.map(\.content.state.end).min()
        guard force || deadline != cleanupDeadline else { return }
        cleanupDeadline = deadline
        let refresh = AcademicRefreshService.shared
        refresh.restore()
        refresh.scheduleNext()
    }

    func cleanUpAfterBackgroundWake() async {
        for activity in activities where activity.content.state.end <= Date() {
            guard !Task.isCancelled else { return }
            await finish(activity, suppress: false)
        }
        updateCleanupSchedule(force: true)
    }

    func reconcile(items: [CourseOccurrence], enabled: Bool, lead: Int, termID: String? = nil,
                   appearance: AppearancePreferences? = nil) async {
        guard !Task.isCancelled else { return }
        revision += 1
        let currentRevision = revision
        boundaryTask?.cancel()
        let appearance = appearance ?? SystemSnapshot.readPayload()?.appearance
        let allowed = enabled && ActivityAuthorizationInfo().areActivitiesEnabled
        let excluded = suppressed
        let planningTime = Date()
        let plan = allowed ? CourseLivePlan.schedule(items: items.filter { !excluded.contains($0.id) }, now: planningTime, lead: lead) : []
        var seen: Set<String> = []
        for activity in activities {
            guard revision == currentRevision, !Task.isCancelled else { return }
            let attributes = activity.attributes
            let state = activity.content.state
            guard allowed, let item = items.first(where: { $0.id == attributes.occurrenceID }), item.end > Date(),
                  !excluded.contains(item.id), attributes.title == item.title, attributes.room == item.room,
                  attributes.start == item.start, attributes.teacher == item.teacher,
                  attributes.termID == termID else {
                await finish(activity, suppress: false)
                continue
            }
            if #available(iOS 26.0, *), activity.activityState == .pending,
               !plan.contains(where: { entry in
                   guard entry.course.id == item.id, let scheduledStart = state.scheduledStart else { return false }
                   return entry.start == scheduledStart || max(entry.start, scheduledStart) <= planningTime
               }) {
                await finish(activity, suppress: false)
                continue
            }
            guard seen.insert(item.id).inserted else {
                await finish(activity, suppress: false)
                continue
            }
            observe(activity)
            let content = activityContent(for: item, appearance: appearance, scheduledAt: state.scheduledStart)
            if content.state != state || activity.content.staleDate != content.staleDate {
                await activity.update(content)
            }
        }
        guard revision == currentRevision, !Task.isCancelled else { return }
        let active = UIApplication.shared.applicationState == .active
        if active {
            for entry in plan where !seen.contains(entry.course.id) {
                try? start(entry.course, scheduledAt: entry.start, lead: lead, termID: termID, appearance: appearance)
            }
        }
        updateCleanupSchedule()
        let now = Date()
        let nextBoundary = (plan.map(\.start) + activities.map(\.content.state.end)).filter { $0 > now }.min()
        guard active, let nextBoundary else { return }
        boundaryTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(max(0, nextBoundary.timeIntervalSinceNow)))
                try Task.checkCancellation()
                boundaryTask = nil
                await reconcile(items: items, enabled: enabled, lead: lead, termID: termID, appearance: appearance)
            } catch {}
        }
    }
}
