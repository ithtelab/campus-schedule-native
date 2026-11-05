import Foundation

enum ExamDeepLink {
    struct Target: Identifiable, Hashable, Sendable {
        var examID: String?
        var termID: String?
        var id: Self { self }
    }

    static func url(examID: String? = nil, termID: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = "campusschedule"
        components.host = "exams"
        let items = [examID.map { URLQueryItem(name: "id", value: $0) },
                     termID.map { URLQueryItem(name: "term", value: $0) }].compactMap { $0 }
        components.queryItems = items.isEmpty ? nil : items
        return components.url
    }

    static func target(_ url: URL) -> Target? {
        guard url.scheme == "campusschedule", url.host == "exams" else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Target(examID: items.first { $0.name == "id" }?.value, termID: items.first { $0.name == "term" }?.value)
    }
}
