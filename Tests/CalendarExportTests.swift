import Foundation
import Testing
@testable import ScheduleCore

struct CalendarExportTests {
    @Test func writesUTCAndEscapesAndFoldsText() {
        let start = Date(timeIntervalSince1970: 0)
        let title = "设计,实践;第一节\n" + String(repeating: "课", count: 30)
        let event = CalendarExport.Event(id: "lesson", title: title, location: "B309", start: start,
                                         end: start.addingTimeInterval(3600))
        let value = String(decoding: CalendarExport.data(events: [event], includeLocations: false, generatedAt: start), as: UTF8.self)
        let unfolded = value.replacingOccurrences(of: "\r\n ", with: "")
        #expect(value.components(separatedBy: "\r\n").allSatisfy { $0.utf8.count <= 75 })
        #expect(unfolded.contains("SUMMARY:设计\\,实践\\;第一节\\n" + String(repeating: "课", count: 30)))
        #expect(value.contains("DTSTART:19700101T000000Z"))
        #expect(value.contains("DTEND:19700101T010000Z"))
        #expect(!value.contains("LOCATION:"))
        let withLocation = String(decoding: CalendarExport.data(events: [event], includeLocations: true), as: UTF8.self)
        #expect(withLocation.contains("LOCATION:B309"))
    }
}
