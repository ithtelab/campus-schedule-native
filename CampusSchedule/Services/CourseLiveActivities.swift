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
    func start(_ item: CourseOccurrence, scheduledAt: Date? = nil) throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, !suppressed.contains(item.id) else { return }
        let attributes = CourseActivityAttributes(occurrenceID: item.id, title: item.title, room: item.room, start: item.start)
        let content = ActivityContent(state: CourseActivityAttributes.ContentState(end: item.end, nextTitle: item.nextTitle, nextRoom: item.nextRoom, beforeClass: Date() < item.start), staleDate: item.end)
        let activity: Activity<CourseActivityAttributes>
        if let scheduledAt, scheduledAt > Date() {
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil, style: .standard,
                alertConfiguration: AlertConfiguration(title: "即将上课", body: "请查看课程安排", sound: .default), start: scheduledAt)
        } else {
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        }
        observe(activity)
    }
    private func observe(_ activity: Activity<CourseActivityAttributes>) {
        guard watchTasks[activity.id] == nil else { return }
        watchTasks[activity.id] = Task { @MainActor in
            for await state in activity.activityStateUpdates {
                if state == .dismissed { suppressed.insert(activity.attributes.occurrenceID); break }
            }
        }
    }
    func reconcile(items: [CourseOccurrence], enabled: Bool, lead: Int) async {
        endTask?.cancel()
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
        if !Activity<CourseActivityAttributes>.activities.contains(where: { $0.attributes.occurrenceID == next.id }) {
            do { try start(next, scheduledAt: next.start.addingTimeInterval(-Double(lead * 60))) }
            catch { return } // 主界面提供权限和手动启动提示；不影响本地通知。
        }
        endTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(max(0, next.end.timeIntervalSinceNow)))
                try Task.checkCancellation()
                for activity in Activity<CourseActivityAttributes>.activities where activity.attributes.occurrenceID == next.id {
                    await finish(activity, suppress: false)
                }
                await reconcile(items: items, enabled: enabled, lead: lead)
            } catch {}
        }
        // 此计时任务仅在进程能执行时结束活动，不能保证锁屏/杀进程后准时运行。
        // 完整后台结束仍为真机验收门槛，不能把 staleDate 当作自动结束。
    }
}
