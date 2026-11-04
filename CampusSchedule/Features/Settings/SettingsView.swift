import SwiftUI
import UniformTypeIdentifiers

/// 包一层用于 `fileExporter`：需要可识别、可命名，且能延迟生成字节。
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .data] }

    var data: Data
    var filename: String

    init(data: Data, filename: String) {
        self.data = data
        self.filename = filename
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
        self.filename = configuration.file.filename ?? "课间册.json"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum SettingsRoute: Hashable {
    case exams
}

struct SettingsView: View {
    @Environment(PreviewStore.self) private var store
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @State private var showingAcademicSettings = false
    @State private var showingTermList = false
    @State private var showingImport = false
    @State private var path = NavigationPath()
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var backupDocument: BackupDocument?
    @State private var exportContentType: UTType = .json
    @State private var pendingArchive: ScheduleArchive?
    @State private var showingRestorePrompt = false
    var body: some View {
        @Bindable var settings = store
        NavigationStack(path: $path) {
            Form {
                Section {
                    SettingsCampusHeader()
                }
                Section("课表") {
                    Button("学期与作息", systemImage: "calendar.badge.clock") { showingAcademicSettings = true }
                    Button("全部学期", systemImage: "list.bullet.rectangle") { showingTermList = true }
                    Button("导入课表", systemImage: "square.and.arrow.down.on.square") { showingImport = true }
                    NavigationLink("考试安排", value: SettingsRoute.exams)
                    NavigationLink {
                        MilestoneListView()
                    } label: {
                        Label("纪念事件", systemImage: "flag")
                    }
                }
                Section("提醒") {
                    Toggle("上课提醒", isOn: $settings.reminderPreview).tint(DesignSystem.switchTint)
                    Picker("提前时间", selection: $settings.reminderMinutes) {
                        ForEach([5, 10, 15, 30], id: \.self) { Text("\($0) 分钟").tag($0) }
                    }
                    Toggle("下课提醒", isOn: $settings.endReminder).tint(DesignSystem.switchTint)
                    if settings.endReminder {
                        Picker("下课提醒时间", selection: $settings.endLead) {
                            Text("下课时").tag(0)
                            Text("提前 1 分钟").tag(1)
                            Text("提前 3 分钟").tag(3)
                            Text("提前 5 分钟").tag(5)
                        }
                    }
                } header: { Text("提醒") }
                Section {
                    Toggle("课程实时活动", isOn: $settings.liveEnabled).tint(DesignSystem.switchTint)
                } header: { Text("锁屏与灵动岛") }
                footer: { Text("在锁屏与灵动岛查看课程安排。") }
                Section("外观") {
                    Picker("显示模式", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .accessibilityIdentifier("settings.appearance")
                }
                Section {
                    Toggle("iCloud 同步", isOn: $settings.cloudSyncEnabled).tint(DesignSystem.switchTint)
                        .disabled(store.storageReadOnly || store.isDemoEdition || store.isPreview)
                    if let status = store.cloudSyncStatus {
                        Text(status).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: { Text("多设备") }
                footer: { Text("个人课表可通过同一 Apple 账户同步，其他设备更新可能稍有延迟。关闭后本机数据保留。演示课表不参与同步。") }
                Section("组件") {
                    Text("在桌面或锁屏编辑模式中搜索“课间册”，添加当前与下一节课组件。")
                }
                Section {
                    Button("导出备份", systemImage: "square.and.arrow.up") { exportBackup() }
                        .disabled(store.storageReadOnly)
                    Button("从备份恢复", systemImage: "square.and.arrow.down") { showingImporter = true }
                    Button("导出修改前的副本", systemImage: "clock.arrow.circlepath") { exportPreviousBackup() }
                        .disabled(store.isDemoEdition || store.isPreview)
                } header: { Text("备份") }
                footer: { Text("备份包含全部学期、课程、考试和调停课记录。恢复会替换本机全部学期，覆盖前会保留原始副本。") }
                if store.storageReadOnly {
                    Section("原始数据已保护") {
                        Text(store.storageIssue ?? "读取失败，已停止写入。")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("导出原始数据", systemImage: "doc.badge.arrow.up") { exportOriginalData() }
                    }
                }
                if let message = store.errorMessage {
                    Section("需要处理") {
                        Label(message, systemImage: "exclamationmark.circle").foregroundStyle(.primary)
                        // 通知被拒后系统不会再弹窗，只能由用户自己去设置里改，
                        // 所以给一个直达入口而不是只留一句话。
                        if message.contains("通知") {
                            Button("打开系统设置", systemImage: "gear") { openSystemSettings() }
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .exams: ExamListView()
                }
            }
            .sheet(isPresented: $showingAcademicSettings) { AcademicSettingsView() }
            .sheet(isPresented: $showingTermList) { TermListView() }
            .sheet(isPresented: $showingImport) { ImportView() }
            .fileExporter(isPresented: $showingExporter, document: backupDocument,
                          contentType: exportContentType, defaultFilename: backupDocument?.filename ?? "课间册.json") { result in
                if case .failure(let error) = result {
                    store.errorMessage = "导出未完成：\(error.localizedDescription)"
                }
                backupDocument = nil
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .alert("恢复备份？", isPresented: $showingRestorePrompt, presenting: pendingArchive) { archive in
                Button("替换全部学期", role: .destructive) { applyRestore(archive) }
                Button("取消", role: .cancel) { pendingArchive = nil }
            } message: { archive in
                if store.storageReadOnly {
                    Text("本机数据暂时无法读取，将先保留原始文件，再用备份恢复全部学期：\n\n\(archive.summary)\n\n不能保留原始文件时将停止恢复。")
                } else {
                    Text("将覆盖本机全部 \(store.terms.count) 个学期：\n\(store.terms.map(\.name).joined(separator: "、"))\n\n替换为备份中的 \(archive.semesters.count) 个学期：\n\(archive.summary)\n\n覆盖前会自动保留原始副本；不能保留副本时将停止恢复。")
                }
            }
            .alert("iCloud 与本机都有改动", isPresented: .init(
                get: { store.pendingCloudConflict != nil },
                set: { if !$0 { store.dismissCloudConflict() } }
            )) {
                Button("使用 iCloud 版本") { store.resolveConflictUsingCloud() }
                Button("保留本机版本", role: .destructive) { store.resolveConflictKeepingLocal() }
                Button("稍后决定", role: .cancel) { store.dismissCloudConflict() }
            } message: {
                Text("两台设备各自修改了课表，无法自动合并。选择要保留的那一份，另一份会被覆盖。")
            }
            .task {
                // 截图与云端验证通过环境变量直接打开某个二级页面。
                switch ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_SHEET"] {
                case "academic": showingAcademicSettings = true
                case "terms": showingTermList = true
                case "import": showingImport = true
                case "exams", "exam-editor": path.append(SettingsRoute.exams)
                default: break
                }
            }
            .onChange(of: settings.reminderPreview) { _, enabled in if enabled { authorizeNotifications(revertReminders: true) } }
            .onChange(of: settings.endReminder) { _, enabled in if enabled { authorizeNotifications(revertReminders: false, revertEndReminder: true) } }
        }
    }

    // MARK: - 备份

    private func exportBackup() {
        do {
            let archive = try store.makeArchive()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmm"
            backupDocument = BackupDocument(data: try archive.encoded(),
                                            filename: "课间册-\(formatter.string(from: Date())).json")
            exportContentType = .json
            showingExporter = true
        } catch {
            store.errorMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func exportOriginalData() {
        do {
            backupDocument = BackupDocument(data: try store.recoveryDataForExport(), filename: "课间册-原始数据.bin")
            exportContentType = .data
            showingExporter = true
        } catch { store.errorMessage = "原始数据导出失败：\(error.localizedDescription)" }
    }

    private func exportPreviousBackup() {
        do {
            backupDocument = BackupDocument(data: try store.previousBackupForExport(), filename: "课间册-修改前备份.json")
            exportContentType = .json
            showingExporter = true
        } catch { store.errorMessage = "还没有可导出的修改前副本。" }
    }

    private func handleImport(_ result: Result<URL, any Error>) {
        do {
            let url = try result.get()
            // 备份可能来自任意来源，先取得安全作用域的访问权限再读取。
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            pendingArchive = try PreviewStore.inspectArchive(data)
            showingRestorePrompt = true
        } catch {
            store.errorMessage = "无法读取备份：\(error.localizedDescription)"
        }
    }

    private func applyRestore(_ archive: ScheduleArchive) {
        do {
            try store.restore(from: archive)
            pendingArchive = nil
        } catch {
            store.errorMessage = "恢复失败：\(error.localizedDescription)"
        }
    }
    /// 请求通知权限。被拒时把开关恢复为关闭。
    ///
    /// 不恢复的话开关会显示「已开启」但实际永远不会发出通知，用户要到提醒
    /// 没响时才发现。权限一旦被拒，系统不会再弹窗，只能引导用户去设置里改。
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func authorizeNotifications(revertReminders: Bool = true, revertEndReminder: Bool = false) {
        guard !store.isPreview else { return }
        Task {
            do {
                if try await CourseNotifications.shared.authorize() {
                    store.synchronize()
                } else {
                    // 把开关退回关闭，让界面与实际能力一致。
                    if revertReminders { store.reminderPreview = false }
                    if revertEndReminder { store.endReminder = false }
                    store.errorMessage = "通知权限未开启。请在系统设置中允许「课间册」发送通知后重新开启提醒。"
                }
            } catch {
                if revertReminders { store.reminderPreview = false }
                if revertEndReminder { store.endReminder = false }
                store.errorMessage = error.localizedDescription
            }
        }
    }
}
