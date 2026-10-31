import SwiftUI

struct SettingsView: View {
    @Environment(PreviewStore.self) private var store
    @State private var showingAcademicSettings = false
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
                Section("组件") {
                    Text("在桌面或锁屏编辑模式中搜索“课间册”，添加当前与下一节课组件。")
                }
                if let message = store.errorMessage {
                    Section("需要处理") { Label(message, systemImage: "exclamationmark.circle").foregroundStyle(.primary) }
                }
                Section("外观") { LabeledContent("显示模式", value: "跟随系统") }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAcademicSettings) { AcademicSettingsView() }
            .task { showingAcademicSettings = ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_SHEET"] == "academic" }
            .onChange(of: settings.reminderPreview) { _, enabled in if enabled { authorizeNotifications() } }
            .onChange(of: settings.endReminder) { _, enabled in if enabled { authorizeNotifications() } }
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
