import SwiftData
import Foundation

@Model final class ScheduleDocument {
    @Attribute(.unique) var key: String
    var version: Int
    var payload: Data
    init(payload: Data) { self.key = "personal"; self.version = 1; self.payload = payload }
}

@MainActor final class LocalPersistence {
    private let container: ModelContainer
    init() throws { container = try ModelContainer(for: ScheduleDocument.self) }
    func load() throws -> Data? {
        let rows = try container.mainContext.fetch(FetchDescriptor<ScheduleDocument>())
        guard let row = rows.first else { return nil }
        guard row.version == 1 else { throw CocoaError(.coderReadCorrupt) }
        return row.payload
    }
    func save(_ data: Data) throws {
        let context = container.mainContext
        if let row = try context.fetch(FetchDescriptor<ScheduleDocument>()).first { row.payload = data }
        else { context.insert(ScheduleDocument(payload: data)) }
        try context.save()
    }
}
