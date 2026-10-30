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
        var events: [(Date, String, String, String)] = []
        for course in courses where course.remindersEnabled {
            if enabled { events.append((course.start.addingTimeInterval(-Double(lead * 60)), course.id + ".start", "即将上课 · " + course.title, course.room)) }
            if endEnabled { events.append((course.end.addingTimeInterval(-Double(endLead * 60)), course.id + ".end", endLead == 0 ? "下课了 · " + course.title : "即将下课 · " + course.title, course.nextRoom.map { "下一节：\($0)" } ?? "本次课程即将结束")) }
        }
        for event in events.filter({ $0.0 > Date() }).sorted(by: { $0.0 < $1.0 }).prefix(60) {
            try Task.checkCancellation()
            let content = UNMutableNotificationContent()
            content.title = event.2; content.body = event.3; content.sound = .default
            content.userInfo = ["occurrenceID": event.1]
            var components = ScheduleRules.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: event.0)
            components.timeZone = ScheduleRules.calendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try await center.add(UNNotificationRequest(identifier: "course." + event.1, content: content, trigger: trigger))
        }
    }
}
