import Foundation

struct CourseException: Identifiable, Codable {
    var id = UUID()
    var courseID: String
    var day: Date
    var cancelled = false
    var start: Date?
    var end: Date?
    var room: String?
}
