import Foundation

enum CourseDeepLink {
    struct Target: Equatable, Sendable {
        var courseID: String
        var termID: String?
        var occurrenceID: String? = nil
        var opensTasks = false
    }

    static func url(courseID: String?, termID: String?, occurrenceID: String? = nil) -> URL? {
        url(host: "course", courseID: courseID, termID: termID, occurrenceID: occurrenceID)
    }

    static func tasksURL(courseID: String, termID: String?) -> URL? {
        url(host: "course-tasks", courseID: courseID, termID: termID, occurrenceID: nil)
    }

    private static func url(host: String, courseID: String?, termID: String?, occurrenceID: String?) -> URL? {
        guard let courseID, !courseID.isEmpty else { return URL(string: "campusschedule://today") }
        var components = URLComponents()
        components.scheme = "campusschedule"; components.host = host
        components.queryItems = [URLQueryItem(name: "id", value: courseID)]
        if let termID { components.queryItems?.append(URLQueryItem(name: "term", value: termID)) }
        if let occurrenceID { components.queryItems?.append(URLQueryItem(name: "occurrence", value: occurrenceID)) }
        return components.url
    }

    /// Older activities only carry an occurrence key: course ID followed by the original day's timestamp.
    static func activityURL(courseID: String?, termID: String?, occurrenceID: String) -> URL? {
        var resolvedID = courseID
        if resolvedID == nil, let separator = occurrenceID.lastIndex(of: ":"),
           let timestamp = TimeInterval(occurrenceID[occurrenceID.index(after: separator)...]), timestamp.isFinite {
            let legacyID = String(occurrenceID[..<separator])
            if !legacyID.isEmpty { resolvedID = legacyID }
        }
        return url(courseID: resolvedID, termID: termID, occurrenceID: occurrenceID)
    }

    static func target(_ url: URL) -> Target? {
        guard url.scheme == "campusschedule", url.host == "course" || url.host == "course-tasks" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let id = components?.queryItems?.first { $0.name == "id" }?.value
            ?? url.pathComponents.last(where: { $0 != "/" })
        guard let id, !id.isEmpty else { return nil }
        let opensTasks = url.host == "course-tasks"
        return Target(courseID: id, termID: components?.queryItems?.first { $0.name == "term" }?.value,
                      occurrenceID: opensTasks ? nil : components?.queryItems?.first { $0.name == "occurrence" }?.value,
                      opensTasks: opensTasks)
    }

    /// Keep a tapped instance pinned even after it ends; stale keys must not silently open another class.
    static func occurrence(for target: Target, in items: [CourseOccurrence], now: Date) -> CourseOccurrence? {
        let matches = items.filter { $0.courseID == target.courseID }
        if let id = target.occurrenceID { return matches.first { $0.id == id } }
        return ScheduleRules.next(in: matches, now: now)
    }
}
