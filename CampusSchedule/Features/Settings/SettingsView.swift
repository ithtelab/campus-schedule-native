import SwiftUI

struct SettingsView: View {
    @Environment(PreviewStore.self) private var store
    @State private var showingAcademicSettings = false

    var body: some View {
        @Bindable var settings = store

        NavigationStack {
            Form {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("你的校园，井井有条").font(.headline)
                            Text("本地优先 · 简单看课表")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundStyle(.primary).font(.title2)
                    }
                    .padding(.vertical, 8)
                }
                Section("课表") {
                    Button { showingAcademicSettings = true } label: {
                        HStack {
                            Label("学期与作息", systemImage: "calendar.badge.clock")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.primary)
                    }
                    LabeledContent("当前课表", value: store.semesterName)
                    LabeledContent("学校", value: "尚未连接")
                    LabeledContent("教务导入", value: "后续接入")
                }
                Section {
                    Toggle("上课提醒（预览）", isOn: $settings.reminderPreview)
                        .tint(DesignSystem.accent)
                    if settings.reminderPreview {
                        Picker("提前时间", selection: $settings.reminderMinutes) {
                            Text("5 分钟").tag(5)
                            Text("10 分钟").tag(10)
                            Text("15 分钟").tag(15)
                            Text("30 分钟").tag(30)
                        }
                    }
                } header: {
                    Text("提醒")
                } footer: {
                    Text("此处仅预览设置交互，不申请通知权限、不发送提醒。退出应用后设置不保留。")
                }
                Section("外观") {
                    LabeledContent("显示模式", value: "跟随系统")
                    LabeledContent("设计", value: "原生系统材质")
                }
                Section {
                    Label("本阶段没有云端连接", systemImage: "iphone")
                    Label("没有收集教务账号", systemImage: "lock.shield")
                } header: {
                    Text("数据与隐私")
                } footer: {
                    Text("当前为 UI 原型，课程均为演示数据。正式名称待定。")
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showingAcademicSettings) { AcademicSettingsView() }
            .task { showingAcademicSettings = ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_SHEET"] == "academic" }
        }
    }
}
