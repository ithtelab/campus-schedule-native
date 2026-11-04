import Foundation

/// 纪念事件的深链。点击组件或今日页摘要时打开对应事件。
enum MilestoneDeepLink {
    struct Target: Equatable, Sendable {
        /// nil 表示打开列表而不是某个具体事件（例如事件已被删除）。
        var milestoneID: String?
    }

    static func url(milestoneID: String?) -> URL? {
        guard let milestoneID, !milestoneID.isEmpty else { return URL(string: "campusschedule://milestones") }
        var components = URLComponents()
        components.scheme = "campusschedule"
        components.host = "milestone"
        components.queryItems = [URLQueryItem(name: "id", value: milestoneID)]
        return components.url
    }

    static func target(_ url: URL) -> Target? {
        guard url.scheme == "campusschedule" else { return nil }
        if url.host == "milestones" { return Target(milestoneID: nil) }
        guard url.host == "milestone" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let id = components?.queryItems?.first { $0.name == "id" }?.value
        return Target(milestoneID: id?.isEmpty == false ? id : nil)
    }
}
