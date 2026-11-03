@preconcurrency import ActivityKit
import Foundation

@MainActor final class CourseLiveActivities {
    static let shared = CourseLiveActivities()
    private var endTask: Task<Void, Never>?
    private var watchTasks: [String: Task<Void, Never>] = [:]
    private var defaults: UserDefaults { UserDefaults(suiteName: SystemSnapshot.group) ?? .standard }
    private var suppressed: Set<String> {
        get { Set(defaults.stringArray(forKey: "endedOccurrences") ?? []) }
        set { defaults.set(Array(newValue), forKey: "endedOccurrences") }
    }
    func finish(_ activity: Activity<CourseActivityAttributes>, suppress: Bool) async {
        if suppress { suppressed.insert(activity.attributes.occurrenceID) }
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
    func start(_ item: CourseOccurrence, scheduledAt: Date? = nil, lead: Int = 10, termID: String? = nil) throws {
        guard item.end > Date() else { throw StartError.outsideWindow }
        if scheduledAt == nil && !CourseLivePlan.canStartManually(item, now: Date(), lead: lead) { throw StartError.outsideWindow }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw StartError.notAllowed }
        guard !suppressed.contains(item.id) else { throw StartError.dismissed }
        let attributes = CourseActivityAttributes(occurrenceID: item.id, title: item.title, room: item.room, start: item.start,
                                                  teacher: item.teacher, courseID: item.courseID, termID: termID)
        let content = ActivityContent(state: CourseActivityAttributes.ContentState(end: item.end, nextTitle: item.nextTitle, nextRoom: item.nextRoom, beforeClass: Date() < item.start), staleDate: item.end)
        let activity: Activity<CourseActivityAttributes>
        if let scheduledAt, scheduledAt > Date(), #available(iOS 26.0, *) {
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil, style: .standard,
                alertConfiguration: AlertConfiguration(title: "即将上课", body: "请查看课程安排", sound: .default), start: scheduledAt)
        } else {
            // Before iOS 26 the starting date cannot be handed to the system, so the activity
            // starts immediately and the local notification still carries the class reminder.
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        }
        observe(activity)
    }
    private func observe(_ activity: Activity<CourseActivityAttributes>) {
        guard watchTasks[activity.id] == nil else { return }
        watchTasks[activity.id] = Task { @MainActor in
            defer { watchTasks[activity.id] = nil }
            for await state in activity.activityStateUpdates {
                if state == .dismissed { suppressed.insert(activity.attributes.occurrenceID); break }
                if state == .ended { break }
            }
        }
    }
    /// 记录已经请求过、但还没真正开始的活动。
    ///
    /// 定时启动的活动在开始前不出现在 `Activity.activities` 里，所以只靠那里做
    /// 幂等判断会每次都重新请求一次，最终在到点时同时冒出多条一模一样的活动。
    private var scheduled: Set<String> {
        get { Set(defaults.stringArray(forKey: "scheduledOccurrences") ?? []) }
        set { defaults.set(Array(newValue), forKey: "scheduledOccurrences") }
    }

    /// 同一次课程只保留最新的一条活动，其余立即结束。
    ///
    /// 历史版本可能已经累积了多条重复活动，这里在每次协调时清理，
    /// 用户不必逐条手动移除。
    private func deduplicateActivities() async {
        var seen: [String: String] = [:]   // occurrenceID -> 保留的活动 id
        for activity in Activity<CourseActivityAttributes>.activities {
            let key = activity.attributes.occurrenceID
            if let kept = seen[key] {
                // 保留先出现的那条，后来的都结束。
                _ = kept
                await finish(activity, suppress: false)
            } else {
                seen[key] = activity.id
            }
        }
    }

    func reconcile(items: [CourseOccurrence], enabled: Bool, lead: Int, termID: String? = nil) async {
        endTask?.cancel()
        await deduplicateActivities()
        for activity in Activity<CourseActivityAttributes>.activities {
            observe(activity)
            guard enabled, let item = items.first(where: { $0.id == activity.attributes.occurrenceID }), item.end > Date(), !suppressed.contains(item.id) else {
                await finish(activity, suppress: false); continue
            }
            if activity.attributes.room != item.room || activity.attributes.start != item.start || activity.attributes.title != item.title {
                await finish(activity, suppress: false)
            } else {
                await activity.update(ActivityContent(state: .init(end: item.end, nextTitle: item.nextTitle, nextRoom: item.nextRoom, beforeClass: Date() < item.start), staleDate: item.end))
            }
        }
        guard enabled else { return }
        // 只计划最近一次。系统活动数量和后台执行均受限制。
        guard let next = ScheduleRules.next(in: items.filter { !suppressed.contains($0.id) }, now: Date()) else { return }
        let alreadyRunning = Activity<CourseActivityAttributes>.activities.contains { $0.attributes.occurrenceID == next.id }
        // 已安排但尚未开始的活动不在 activities 里，必须另外记住，否则每次协调都会再请求一次。
        let alreadyScheduled = scheduled.contains(next.id)
        if !alreadyRunning && !alreadyScheduled {
            do {
                try start(next, scheduledAt: CourseLivePlan.earliestStart(for: next, lead: lead), lead: lead, termID: termID)
                scheduled.insert(next.id)
            }
            catch { return } // 主界面提供权限和手动启动提示；不影响本地通知。
        }
        // 只保留仍然在未来会开始的记录，避免集合无限增长。
        let futureIDs = Set(items.filter { $0.start > Date() }.map(\.id))
        scheduled = scheduled.intersection(futureIDs.union([next.id]))
        endTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(max(0, next.end.timeIntervalSinceNow)))
                try Task.checkCancellation()
                for activity in Activity<CourseActivityAttributes>.activities where activity.attributes.occurrenceID == next.id {
                    await finish(activity, suppress: false)
                }
                await reconcile(items: items, enabled: enabled, lead: lead, termID: termID)
            } catch {}
        }
        // 此计时任务仅在进程能执行时结束活动，不能保证锁屏/杀进程后准时运行。
        // 完整后台结束仍为真机验收门槛，不能把 staleDate 当作自动结束。
    }
}
