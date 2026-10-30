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
}
