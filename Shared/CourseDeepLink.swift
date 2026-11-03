import Foundation

enum CourseDeepLink {
    struct Target: Equatable, Sendable { var courseID: String; var termID: String? }

    static func url(courseID: String?, termID: String?) -> URL? {
        guard let courseID, !courseID.isEmpty else { return URL(string: "campusschedule://today") }
        var components = URLComponents()
        components.scheme = "campusschedule"; components.host = "course"
        components.queryItems = [URLQueryItem(name: "id", value: courseID)]
        if let termID { components.queryItems?.append(URLQueryItem(name: "term", value: termID)) }
        return components.url
    }

    static func target(_ url: URL) -> Target? {
        guard url.scheme == "campusschedule", url.host == "course" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let id = components?.queryItems?.first { $0.name == "id" }?.value
            ?? url.pathComponents.last(where: { $0 != "/" })
        guard let id, !id.isEmpty else { return nil }
        return Target(courseID: id, termID: components?.queryItems?.first { $0.name == "term" }?.value)
    }
}
