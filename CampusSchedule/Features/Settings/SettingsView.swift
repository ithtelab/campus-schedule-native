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
    case milestones
    case appearance
    case about
    case calendarExport
    case backupHistory
}

/// 上课提醒的提前量。用枚举而不是内联数组：`Picker` 里的 `ForEach([Int])`
/// 会让整个 `Form` 的类型推导变得极慢，接近编译器的超时阈值。
enum ReminderLead: Int, CaseIterable {
    case five = 5, ten = 10, fifteen = 15, thirty = 30

    var minutes: Int { rawValue }
    var title: String { "\(rawValue) 分钟" }
}

/// 下课提醒的提前量。0 表示下课时。
enum EndReminderLead: Int, CaseIterable {
    case atEnd = 0, one = 1, three = 3, five = 5

    var minutes: Int { rawValue }
    var title: String {
        self == .atEnd ? "下课时" : "提前 \(rawValue) 分钟"
    }
}

struct SettingsView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.scenePhase) private var phase
    @Binding var appearance: AppAppearance
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
    @State private var confirmingCloudDeletion = false
    @State private var showingCloudConflict = false
    @State private var notificationStatus: CourseNotifications.Status?
    @State private var notificationActionInProgress = false
    @State private var notificationFeedback: String?
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
                    NavigationLink("纪念事件", value: SettingsRoute.milestones)
                    NavigationLink("导出到日历", value: SettingsRoute.calendarExport)
                }
                Section {
                    Toggle("上课提醒", isOn: $settings.reminderPreview).tint(DesignSystem.switchTint)
                    Picker("提前时间", selection: $settings.reminderMinutes) {
                        ForEach(ReminderLead.allCases, id: \.self) { lead in
                            Text(lead.title).tag(lead.minutes)
                        }
                    }
                    Toggle("下课提醒", isOn: $settings.endReminder).tint(DesignSystem.switchTint)
                    if settings.endReminder {
                        Picker("下课提醒时间", selection: $settings.endLead) {
                            ForEach(EndReminderLead.allCases, id: \.self) { lead in
                                Text(lead.title).tag(lead.minutes)
                            }
                        }
                    }
                    notificationDetails
                } header: { Text("提醒") }
                Section {
                    Toggle("课程实时活动", isOn: $settings.liveEnabled).tint(DesignSystem.switchTint)
                } header: { Text("锁屏与灵动岛") }
                footer: { Text("在锁屏与灵动岛查看课程安排。后台显示和移除时间由 iOS 调度。") }
                Section("外观") {
                    Picker("显示模式", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .accessibilityIdentifier("settings.appearance")
                    NavigationLink("人物与主题", value: SettingsRoute.appearance)
                }
                Section {
                    Toggle("iCloud 同步", isOn: $settings.cloudSyncEnabled).tint(DesignSystem.switchTint)
                        .disabled(store.storageReadOnly || store.isPreview)
                        .accessibilityIdentifier("settings.icloud")
                    if settings.cloudSyncEnabled {
                        Button("立即同步", systemImage: "arrow.clockwise") { store.refreshCloudSync() }
                        if store.pendingCloudConflict != nil {
                            Button("解决同步冲突", systemImage: "exclamationmark.icloud") { showingCloudConflict = true }
                        }
                        Button("删除 iCloud 副本", systemImage: "trash", role: .destructive) {
                            confirmingCloudDeletion = true
                        }
                    }
                    if let status = store.cloudSyncStatus {
                        Text(status).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: { Text("多设备") }
                footer: { Text("在使用同一 Apple 账户的设备上开启同步，可共享课表、考试和纪念事件。更新可能需要一些时间。") }
                Section("组件") {
                    Text("在桌面或锁屏编辑模式中搜索“课间册”，添加当前与下一节课组件。")
                }
                Section {
                    Button("导出备份", systemImage: "square.and.arrow.up") { exportBackup() }
                        .disabled(store.storageReadOnly)
                    Button("从备份恢复", systemImage: "square.and.arrow.down") { showingImporter = true }
                    Button("导出修改前的副本", systemImage: "clock.arrow.circlepath") { exportPreviousBackup() }
                        .disabled(store.isPreview)
                    NavigationLink("备份记录与学期恢复", value: SettingsRoute.backupHistory)
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
                Section {
                    NavigationLink(value: SettingsRoute.about) {
                        Label("关于课间册", systemImage: "info.circle")
                    }
                    .accessibilityIdentifier("settings.about")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .exams: ExamListView()
                case .milestones: MilestoneListView()
                case .appearance: AppearanceSettingsView()
                case .about: AboutView()
                case .calendarExport: CalendarExportView()
                case .backupHistory: BackupHistoryView()
                }
            }
            .sheet(isPresented: $showingAcademicSettings) { AcademicSettingsView() }
            .sheet(isPresented: $showingTermList) { TermListView() }
            .sheet(isPresented: $showingImport) { ImportView() }
            .confirmationDialog("删除 iCloud 课表副本？", isPresented: $confirmingCloudDeletion, titleVisibility: .visible) {
                Button("删除 iCloud 副本", role: .destructive) { store.removeCloudCopy() }
            } message: {
                Text("本机课表会保留。支持此操作的其他设备收到变更后会暂停同步。如果有设备仍在用旧版本，请先在这些设备关闭同步。")
            }
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
            .onChange(of: store.pendingCloudConflict != nil, initial: true) { _, hasConflict in
                showingCloudConflict = hasConflict
            }
            .alert("iCloud 与本机都有改动", isPresented: $showingCloudConflict) {
                Button("使用 iCloud 版本") { store.resolveConflictUsingCloud() }
                Button("保留本机版本", role: .destructive) { store.resolveConflictKeepingLocal() }
                Button("稍后决定", role: .cancel) {}
            } message: {
                Text("两台设备各自修改了课表，无法自动合并。选择要保留的那一份，另一份会被覆盖。")
            }
            .task {
                guard store.isPreview else { return }
                // 截图与云端验证通过环境变量直接打开某个二级页面。
                switch ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_SHEET"] {
                case "academic": showingAcademicSettings = true
                case "terms": showingTermList = true
                case "import": showingImport = true
                case "exams", "exam-editor": path.append(SettingsRoute.exams)
                case "milestones", "milestone-editor":
                    path.append(SettingsRoute.milestones)
                case "appearance": path.append(SettingsRoute.appearance)
                default: break
                }
            }
            .task(id: phase) {
                if phase == .active { await refreshNotificationStatus() }
            }
            .onChange(of: settings.reminderPreview) { _, enabled in updateReminderPreference(enabled: enabled) }
            .onChange(of: settings.endReminder) { _, enabled in updateReminderPreference(enabled: enabled) }
            .onChange(of: settings.reminderMinutes) { _, _ in updateReminderPreference(enabled: false) }
            .onChange(of: settings.endLead) { _, _ in updateReminderPreference(enabled: false) }
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
    @ViewBuilder private var notificationDetails: some View {
        if let notificationStatus {
            switch notificationStatus.permission {
            case .needsRequest:
                LabeledContent("系统通知", value: "尚未授权")
                Button("允许发送通知", systemImage: "bell") { requestNotificationPermission() }
                    .disabled(notificationActionInProgress)
            case .denied:
                LabeledContent("系统通知", value: "未允许")
                Button("打开系统通知设置", systemImage: "gear", action: openSystemSettings)
            case .quiet, .allowed:
                LabeledContent("系统通知", value: notificationStatus.permission == .quiet ? "静默送达" : "已允许")
                if let date = notificationStatus.nextCourseReminder {
                    LabeledContent("下次课程提醒") {
                        Text(date, format: .dateTime.month().day().hour().minute())
                    }
                } else if store.reminderPreview || store.endReminder {
                    LabeledContent("下次课程提醒", value: "暂无待发送提醒")
                }
                Button("发送测试提醒", systemImage: "bell.badge", action: sendTestReminder)
                    .disabled(notificationActionInProgress)
            }
        }
        if let notificationFeedback { Text(notificationFeedback).font(.footnote).foregroundStyle(.secondary) }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func refreshNotificationStatus() async {
        guard !store.isPreview else { return }
        let status = await CourseNotifications.shared.status()
        if !Task.isCancelled { notificationStatus = status }
    }

    private func updateReminderPreference(enabled: Bool) {
        guard !store.isPreview else { return }
        Task {
            await refreshNotificationStatus()
            if enabled, notificationStatus?.permission == .needsRequest {
                requestNotificationPermission()
            } else {
                await store.synchronize()?.value
                await refreshNotificationStatus()
            }
        }
    }

    private func requestNotificationPermission() {
        guard !store.isPreview, !notificationActionInProgress else { return }
        notificationActionInProgress = true
        notificationFeedback = nil
        Task {
            defer { notificationActionInProgress = false }
            do {
                if try await CourseNotifications.shared.authorize() { await store.synchronize()?.value }
            } catch { notificationFeedback = error.localizedDescription }
            await refreshNotificationStatus()
        }
    }

    private func sendTestReminder() {
        notificationActionInProgress = true
        notificationFeedback = nil
        Task {
            defer { notificationActionInProgress = false }
            do {
                try await CourseNotifications.shared.sendTestReminder()
                notificationFeedback = "测试提醒已安排。显示方式取决于系统通知和专注模式。"
            } catch { notificationFeedback = error.localizedDescription }
            await refreshNotificationStatus()
        }
    }
}
