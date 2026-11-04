import UserNotifications

actor CourseNotifications {
    static let shared = CourseNotifications()
    func authorize() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }
    func replace(courses: [CourseOccurrence], enabled: Bool, lead: Int, endEnabled: Bool, endLead: Int) async throws {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("course.") }.map(\.identifier))
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let events = NotificationPlan.make(courses: courses, now: Date(), enabled: enabled,
            lead: lead, endEnabled: endEnabled, endLead: endLead)
        for event in events {
            try Task.checkCancellation()
            let content = UNMutableNotificationContent()
            content.title = event.title; content.body = event.body; content.sound = .default
            content.userInfo = ["reminderID": event.id]
            var components = ScheduleRules.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: event.date)
            components.timeZone = ScheduleRules.calendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try await center.add(UNNotificationRequest(identifier: "course." + event.id, content: content, trigger: trigger))
        }
    }

    /// 重排纪念事件提醒。
    ///
    /// 只清理 `milestone.` 前缀的请求，不影响课程提醒。每条事件是否提醒由它自己的
    /// 提前天数决定，因此不看「上课提醒」这个总开关 —— 那个开关说的是课程。
    /// 每年重复的事件由 `MilestoneReminderPlan` 滚动到下一次，所以用一次性触发器；
    /// 每次启动、编辑或删除都会整体重排，避免留下指向已删事件的旧提醒。
    func replaceMilestones(_ milestones: [Milestone]) async throws {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.filter { $0.identifier.hasPrefix("milestone.") }.map(\.identifier))
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        for event in MilestoneReminderPlan.make(milestones, now: Date()) {
            try Task.checkCancellation()
            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = event.body
            content.sound = .default
            content.userInfo = ["reminderID": event.id]
            var components = MilestoneCounter.calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: event.date)
            components.timeZone = MilestoneCounter.calendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try await center.add(UNNotificationRequest(identifier: event.id, content: content, trigger: trigger))
        }
    }
}
