import SwiftData
import Foundation

@Model final class ScheduleDocument {
    @Attribute(.unique) var key: String
    var version: Int
    var payload: Data
    init(payload: Data) { self.key = "personal"; self.version = 1; self.payload = payload }
}

@MainActor final class LocalPersistence {
    struct Backup: Identifiable {
        let id: String
        let savedAt: Date
        let archive: ScheduleArchive
    }

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
            try? pruneBackups(in: folder, keeping: 12)
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

    func recentBackups() throws -> [Backup] {
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true).appendingPathComponent("Recovery", isDirectory: true)
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])
            .filter { $0.lastPathComponent.hasSuffix(".archive.json") }
            .sorted { backupDate($0) > backupDate($1) }
            .prefix(12).compactMap { url in
                guard let data = try? Data(contentsOf: url), let archive = try? ScheduleArchive.decoded(from: data) else { return nil }
                return Backup(id: url.lastPathComponent, savedAt: backupDate(url), archive: archive)
            }
    }

    private func backupDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
    }

    private func pruneBackups(in folder: URL, keeping limit: Int) throws {
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])
        let suffix = ".archive.json"
        let archives = files.filter { $0.lastPathComponent.hasSuffix(suffix) }.sorted { backupDate($0) > backupDate($1) }
        for archive in archives.dropFirst(limit) {
            let base = String(archive.lastPathComponent.dropLast(suffix.count))
            guard base.hasPrefix("schedule-"), UUID(uuidString: String(base.dropFirst("schedule-".count))) != nil else { continue }
            try FileManager.default.removeItem(at: archive)
            let raw = folder.appendingPathComponent(base + ".raw.json")
            if FileManager.default.fileExists(atPath: raw.path) { try FileManager.default.removeItem(at: raw) }
        }
    }
}
