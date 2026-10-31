import SwiftUI
import UniformTypeIdentifiers

/// 包一层用于 `fileExporter`：需要可识别、可命名，且能延迟生成字节。
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

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
    @State private var showingAcademicSettings = false
    @State private var showingTermList = false
    @State private var showingImport = false
    @State private var path = NavigationPath()
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var backupDocument: BackupDocument?
    @State private var pendingArchive: ScheduleArchive?
    @State private var showingRestorePrompt = false
    var body: some View {
        @Bindable var settings = store
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        CampusNotebook().stroke(.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .frame(width: 34, height: 38).rotationEffect(.degrees(-5)).accessibilityHidden(true)
                        CampusHeading(title: "校园日常")
                    }
                    .padding(.vertical, 12)
                }
                Section("课表") {
                    Button("学期与作息", systemImage: "calendar.badge.clock") { showingAcademicSettings = true }
                    Button("全部学期", systemImage: "list.bullet.rectangle") { showingTermList = true }
                    Button("导入课表", systemImage: "square.and.arrow.down.on.square") { showingImport = true }
                    NavigationLink("考试安排", value: SettingsRoute.exams)
                    LabeledContent("当前学期", value: store.semesterName)
                }
                Section {
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
                Section {
                    Toggle("iCloud 同步", isOn: $settings.cloudSyncEnabled).tint(DesignSystem.switchTint)
                    if let status = store.cloudSyncStatus {
                        Text(status).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: { Text("多设备") }
                footer: { Text("开启后课表会保存到你的 iCloud，在登录同一 Apple 账户的其他设备上自动出现。关闭后本机数据保留，不再上传。") }
                Section("组件") {
                    Text("在桌面或锁屏编辑模式中搜索“课间册”，添加当前与下一节课组件。")
                }
                Section {
                    Button("导出备份", systemImage: "square.and.arrow.up") { exportBackup() }
                    Button("从备份恢复", systemImage: "square.and.arrow.down") { showingImporter = true }
                } header: { Text("备份") }
                footer: { Text("导出的文件包含本学期课程、作息与调课记录，可换机迁移或自行保存。恢复会用备份内容替换当前学期。") }
                if let message = store.errorMessage {
                    Section("需要处理") { Label(message, systemImage: "exclamationmark.circle").foregroundStyle(.primary) }
                }
                Section("外观") { LabeledContent("显示模式", value: "跟随系统") }
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
                          contentType: .json, defaultFilename: backupDocument?.filename ?? "课间册.json") { result in
                if case .failure(let error) = result {
                    store.errorMessage = "导出未完成：\(error.localizedDescription)"
                }
                backupDocument = nil
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .alert("恢复备份？", isPresented: $showingRestorePrompt, presenting: pendingArchive) { archive in
                Button("替换当前学期", role: .destructive) { applyRestore(archive) }
                Button("取消", role: .cancel) { pendingArchive = nil }
            } message: { archive in
                Text("将用备份覆盖当前学期：\n\n\(archive.summary)\n\n当前数据会被替换，且无法撤销。建议先导出一次现有课表。")
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
                case "exams": path.append(SettingsRoute.exams)
                default: break
                }
            }
            .onChange(of: settings.reminderPreview) { _, enabled in if enabled { authorizeNotifications() } }
            .onChange(of: settings.endReminder) { _, enabled in if enabled { authorizeNotifications() } }
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
            showingExporter = true
        } catch {
            store.errorMessage = "导出失败：\(error.localizedDescription)"
        }
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
    private func authorizeNotifications() {
        guard !store.isPreview else { return }
        Task {
            do {
                if try await CourseNotifications.shared.authorize() { store.synchronize() }
                else { store.errorMessage = "通知权限未开启，请到系统设置中允许通知。" }
            } catch { store.errorMessage = error.localizedDescription }
        }
    }
}
