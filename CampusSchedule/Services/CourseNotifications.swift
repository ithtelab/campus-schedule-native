import UserNotifications

actor CourseNotifications {
    static let shared = CourseNotifications()
    private var scheduledWork: Task<Void, Error>?

    func authorize() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    func synchronize(courses: [CourseOccurrence], enabled: Bool, lead: Int, endEnabled: Bool, endLead: Int,
                     milestones: [Milestone]) async throws {
        try Task.checkCancellation()
        let previous = scheduledWork
        previous?.cancel()
        let work = Task {
            _ = await previous?.result
            try Task.checkCancellation()
            let now = Date()
            let courseEvents = NotificationPlan.make(courses: courses, now: now, enabled: enabled,
                lead: lead, endEnabled: endEnabled, endLead: endLead).map { event in
                CourseReminder(date: event.date, id: "course." + event.id, title: event.title, body: event.body)
            }
            let milestoneEvents = MilestoneReminderPlan.make(milestones, now: now).map { event in
                CourseReminder(date: event.date, id: event.id, title: event.title, body: event.body)
            }
            try await reconcile(events: courseEvents + milestoneEvents)
        }
        scheduledWork = work
        try await withTaskCancellationHandler {
            try await work.value
        } onCancel: {
            work.cancel()
        }
    }

    private func reconcile(events: [CourseReminder]) async throws {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        let settings = await center.notificationSettings()
        try Task.checkCancellation()
        let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        let managed = requests.filter { $0.identifier.hasPrefix("course.") || $0.identifier.hasPrefix("milestone.") }
        let limit = max(0, 64 - (requests.count - managed.count))
        let desired = authorized ? Array(events.sorted {
            $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date
        }.prefix(limit)) : []
        let pending = Dictionary(uniqueKeysWithValues: managed.map { request in
            let date = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantPast
            return (request.identifier, CourseReminder(date: date, id: request.identifier,
                                                       title: request.content.title, body: request.content.body))
        })
        let changes = ReminderChanges(pending: pending, desired: desired)
        center.removePendingNotificationRequests(withIdentifiers: changes.obsolete)

        var firstError: Error?
        for event in changes.additions {
            try Task.checkCancellation()
            guard event.date > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = event.body
            content.sound = .default
            content.userInfo = ["reminderID": event.id.hasPrefix("course.") ? String(event.id.dropFirst("course.".count)) : event.id]
            let calendar = event.id.hasPrefix("course.") ? ScheduleRules.calendar : MilestoneCounter.calendar
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: event.date)
            components.timeZone = calendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: event.id, content: content, trigger: trigger))
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        if let firstError { throw firstError }
    }
}
