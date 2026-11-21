import SwiftUI

/// 学期列表：切换、新建、重命名、删除。
struct TermListView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: TermSummary?
    @State private var renameText = ""
    @State private var pendingDeletion: TermSummary?
    @State private var showingNewTerm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.terms) { term in
                        Button {
                            store.selectTerm(term.id)
                            dismiss()
                        } label: {
                            row(term)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(term.id == store.activeTermID ? .isSelected : [])
                        .accessibilityIdentifier("term.\(term.id)")
                        .swipeActions(edge: .trailing) {
                            if store.terms.count > 1 {
                                Button("删除", systemImage: "trash", role: .destructive) {
                                    pendingDeletion = term
                                }
                            }
                            Button("重命名", systemImage: "pencil") {
                                renameText = term.name
                                renaming = term
                            }
                        }
                    }
                } header: {
                    Text("全部学期")
                } footer: {
                    Text("轻点切换查看课表。课程提醒和组件按学期日期自动选择课表。")
                }
            }
            .navigationTitle("学期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新建", systemImage: "plus") { showingNewTerm = true }
                        .disabled(store.storageReadOnly)
                }
            }
            .alert("重命名学期", isPresented: .init(
                get: { renaming != nil },
                set: { if !$0 { renaming = nil } }
            )) {
                TextField("学期名称", text: $renameText)
                Button("保存") {
                    if let term = renaming { store.renameTerm(term.id, to: renameText) }
                    renaming = nil
                }
                Button("取消", role: .cancel) { renaming = nil }
            }
            .confirmationDialog("删除这个学期？", isPresented: .init(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ), presenting: pendingDeletion) { term in
                Button("删除「\(term.name)」", role: .destructive) {
                    store.deleteTerm(term.id)
                    pendingDeletion = nil
                }
                Button("取消", role: .cancel) { pendingDeletion = nil }
            } message: { term in
                Text("将删除该学期的课程、作息、调停课、考试和待办。删除前会备份，可从设置里的「备份记录与学期恢复」恢复。")
            }
            .sheet(isPresented: $showingNewTerm) { NewTermView() }
        }
    }

    private func row(_ term: TermSummary) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(term.name).foregroundStyle(.primary)
                Text(dateRange(term)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if term.id == store.activeTermID {
                Image(systemName: "checkmark").foregroundStyle(DesignSystem.accent)
            }
        }
        .contentShape(Rectangle())
    }

    private func dateRange(_ term: TermSummary) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = ScheduleRules.calendar.timeZone
        formatter.dateFormat = "yyyy.MM.dd"
        return "\(formatter.string(from: term.startDate)) – \(formatter.string(from: term.endDate)) · \(term.totalWeeks) 周"
    }

}

private struct NewTermView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var name = ""
    @State private var start = Date()
    @State private var weeks = 20
    @State private var reusePeriods = true
    @State private var newTermID: String?
    @State private var importCourses = false
    @State private var addCourse = false
    @State private var requesting = false
    @State private var permission: CourseNotifications.Status.Permission?
    @State private var message: String?

    private var isMonday: Bool { ScheduleRules.calendar.component(.weekday, from: start) == 2 }

    var body: some View {
        NavigationStack {
            Form {
                if let newTermID {
                    Section("加入课程") {
                        Button("导入课表", systemImage: "square.and.arrow.down") {
                            store.selectTerm(newTermID)
                            importCourses = true
                        }
                        Button("手动添加", systemImage: "plus") { addCourse = true }
                    }
                    Section("提醒与组件") {
                        if permission == .denied {
                            Button("在系统设置开启通知", systemImage: "bell.slash") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                        } else if store.reminderPreview && (permission == .allowed || permission == .quiet) {
                            Label("上课提醒已开启", systemImage: "bell")
                        } else {
                            Button("开启上课提醒", systemImage: "bell") { enableReminders() }.disabled(requesting)
                        }
                        Text("长按桌面进入编辑，搜索「课间册」即可添加组件。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    Section("学期信息") {
                        TextField("学期名称", text: $name)
                        DatePicker("第一周周一", selection: $start, displayedComponents: .date)
                        if !isMonday { Text("请选择周一作为开学日。").font(.footnote).foregroundStyle(.secondary) }
                        Stepper("教学周数 · \(weeks) 周", value: $weeks, in: 1...53)
                    }
                    Section {
                        Toggle("沿用「\(store.semesterName)」的作息", isOn: $reusePeriods)
                    } footer: { Text("新学期从空课表开始。") }
                }
                if let message { Section { Text(message).font(.footnote).foregroundStyle(.secondary) } }
            }
            .navigationTitle(newTermID == nil ? "新建学期" : "学期已创建")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if newTermID == nil {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if newTermID != nil { Button("完成") { dismiss() } }
                    else { Button("创建") { create() }.disabled(!isMonday || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
            }
            .onAppear {
                if name.isEmpty && newTermID == nil {
                    name = TermSelection.uniqueName("新学期", existing: store.terms)
                    start = TermSelection.suggestedStart(after: store.terms)
                }
            }
            .sheet(isPresented: $importCourses) { ImportView() }
            .sheet(isPresented: $addCourse) { CourseEditorView(targetTermID: newTermID) }
            .task(id: newTermID) {
                if newTermID != nil { permission = await CourseNotifications.shared.status().permission }
            }
        }
        .environment(\.timeZone, ScheduleRules.calendar.timeZone)
    }

    private func create() {
        let previous = store.activeTermID
        let id = store.addTerm(name: name, start: start, totalWeeks: weeks, reusePeriods: reusePeriods, select: true)
        if id == previous { message = store.errorMessage ?? "未能新建学期，请稍后重试。" }
        else { message = nil; newTermID = id }
    }

    private func enableReminders() {
        requesting = true
        Task { @MainActor in
            defer { requesting = false }
            do {
                if try await CourseNotifications.shared.authorize() { store.reminderPreview = true; message = nil }
                else { message = "通知权限未开启，可在 iOS 设置中允许课间册发送通知。" }
            } catch { message = error.localizedDescription }
            permission = await CourseNotifications.shared.status().permission
        }
    }
}
