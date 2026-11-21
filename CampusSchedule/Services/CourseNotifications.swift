import UserNotifications

actor CourseNotifications {
    static let shared = CourseNotifications()
    static let destinationKey = "reminderDestination"
    @MainActor private(set) static var refillDeadline: Date?
    private var scheduledWork: Task<Void, Error>?

    struct Status: Sendable {
        enum Permission: Equatable, Sendable {
            case needsRequest, denied, quiet, allowed
        }
        var permission: Permission
        var nextCourseReminder: Date?
    }

    func authorize() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func status() async -> Status {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let permission: Status.Permission
        switch settings.authorizationStatus {
        case .notDetermined: permission = .needsRequest
        case .denied: permission = .denied
        case .provisional: permission = .quiet
        case .authorized, .ephemeral:
            permission = settings.alertSetting == .enabled ? .allowed : .quiet
        @unknown default: permission = .denied
        }
        let requests = await center.pendingNotificationRequests()
        let nextCourseReminder = requests.filter { $0.identifier.hasPrefix("course.") }
            .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }.min()
        return Status(permission: permission, nextCourseReminder: nextCourseReminder)
    }

    func sendTestReminder() async throws {
        let content = UNMutableNotificationContent()
        content.title = "课间册测试提醒"
        content.body = "通知可正常送达。"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        try await UNUserNotificationCenter.current().add(.init(identifier: "reminder.test", content: content, trigger: trigger))
    }

    func synchronize(courses: [CourseOccurrence], enabled: Bool, lead: Int, endEnabled: Bool, endLead: Int,
                     milestones: [Milestone], examsByTerm: [String: [Exam]]) async throws {
        try Task.checkCancellation()
        let previous = scheduledWork
        previous?.cancel()
        let work = Task {
            _ = await previous?.result
            try Task.checkCancellation()
            let now = Date()
            let courseEvents = NotificationPlan.make(courses: courses, now: now, enabled: enabled,
                lead: lead, endEnabled: endEnabled, endLead: endLead, limit: .max).map { event in
                var qualified = event
                qualified.id = "course." + event.id
                return qualified
            }
            let milestoneEvents = MilestoneReminderPlan.make(milestones, now: now, limit: .max).map { event in
                CourseReminder(date: event.date, id: event.id, title: event.title, body: event.body,
                               destination: MilestoneDeepLink.url(milestoneID: event.milestoneID))
            }
            let examEvents = examsByTerm.flatMap { termID, exams in
                exams.flatMap { ExamPlan.reminders(for: $0, termID: termID, now: now) }
            }
            try await reconcile(events: courseEvents + milestoneEvents + examEvents)
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
        let authorization = settings.authorizationStatus
        let authorized = authorization == .authorized || authorization == .provisional || authorization == .ephemeral
        let managed = requests.filter {
            $0.identifier.hasPrefix("course.") || $0.identifier.hasPrefix("milestone.") || $0.identifier.hasPrefix("exam.")
        }
        // Reserve one slot for a test notification so it cannot displace a course or an exam.
        let limit = max(0, 63 - (requests.count - managed.count))
        let desired = authorized ? ReminderChanges.prioritized(events, limit: limit) : []
        let pending = Dictionary(uniqueKeysWithValues: managed.map { request in
            let date = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantPast
            let destination = (request.content.userInfo[Self.destinationKey] as? String).flatMap { URL(string: $0) }
            return (request.identifier, CourseReminder(date: date, id: request.identifier,
                                                       title: request.content.title, body: request.content.body,
                                                       destination: destination))
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
            if let destination = event.destination {
                content.userInfo = [Self.destinationKey: destination.absoluteString]
            }
            let calendar = event.id.hasPrefix("milestone.") ? MilestoneCounter.calendar : ScheduleRules.calendar
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: event.date)
            components.timeZone = calendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: event.id, content: content, trigger: trigger))
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        try Task.checkCancellation()
        let now = Date()
        let refill = authorized ? ReminderChanges.refillDate(desired: desired, availableCount: events.count, now: now) : nil
        await Self.scheduleRefill(at: firstError == nil ? refill : now.addingTimeInterval(30 * 60))
        if let firstError { throw firstError }
    }

    @MainActor private static func scheduleRefill(at date: Date?) {
        guard date != refillDeadline else { return }
        refillDeadline = date
        let refresh = AcademicRefreshService.shared
        refresh.restore()
        refresh.scheduleNext()
    }
}
