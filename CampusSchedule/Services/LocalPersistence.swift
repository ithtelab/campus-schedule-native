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
        do {
            if let row = try context.fetch(FetchDescriptor<ScheduleDocument>()).first {
                row.payload = data; row.version = 1
            } else { context.insert(ScheduleDocument(payload: data)) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// 不解析原始内容；损坏或高版本载荷也必须原样保留后才能恢复。
    func recoveryData() throws -> Data? {
        try container.mainContext.fetch(FetchDescriptor<ScheduleDocument>()).first?.payload
    }

    @discardableResult
    func backupCurrent(archive: Data? = nil) throws -> URL? {
        guard let row = try container.mainContext.fetch(FetchDescriptor<ScheduleDocument>()).first else { return nil }
        struct Recovery: Encodable { var version: Int; var payload: Data; var savedAt: Date }
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true).appendingPathComponent("Recovery", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = "schedule-\(UUID().uuidString)"
        let rawURL = folder.appendingPathComponent(name + ".raw.json")
        let original = try JSONEncoder().encode(Recovery(version: row.version, payload: row.payload, savedAt: Date()))
        try original.write(to: rawURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        if let archive {
            let archiveURL = folder.appendingPathComponent(name + ".archive.json")
            try archive.write(to: archiveURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return archiveURL
        }
        return rawURL
    }

    func latestArchiveBackup() throws -> Data {
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: false).appendingPathComponent("Recovery", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])
            .filter { $0.lastPathComponent.hasSuffix(".archive.json") }
        guard let latest = files.max(by: {
            ((try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast)
                < ((try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast)
        }) else { throw CocoaError(.fileReadNoSuchFile) }
        return try Data(contentsOf: latest)
    }
}
