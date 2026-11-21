import Foundation

enum CalendarExport {
    struct Event {
        let id: String
        let title: String
        let location: String
        let start: Date
        let end: Date
    }

    static func data(events: [Event], includeLocations: Bool, generatedAt: Date = Date()) -> Data {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let stamp = formatter.string(from: generatedAt)
        var lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//CampusSchedule//Classes and Exams//ZH", "CALSCALE:GREGORIAN"]
        for event in events where event.end > event.start {
            let uid = Data(event.id.utf8).base64EncodedString()
            lines.append(contentsOf: [
                "BEGIN:VEVENT",
                "UID:\(uid)@campusschedule",
                "DTSTAMP:\(stamp)",
                "DTSTART:\(formatter.string(from: event.start))",
                "DTEND:\(formatter.string(from: event.end))",
                "SUMMARY:\(escape(event.title))"
            ])
            if includeLocations, !event.location.isEmpty { lines.append("LOCATION:\(escape(event.location))") }
            lines.append("END:VEVENT")
        }
        lines.append("END:VCALENDAR")
        return Data((lines.map(fold).joined(separator: "\r\n") + "\r\n").utf8)
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
    }

    private static func fold(_ line: String) -> String {
        var result = ""
        var bytes = 0
        for scalar in line.unicodeScalars {
            let count = String(scalar).utf8.count
            if bytes + count > 75 {
                result += "\r\n "
                bytes = 1
            }
            result.unicodeScalars.append(scalar)
            bytes += count
        }
        return result
    }
}
