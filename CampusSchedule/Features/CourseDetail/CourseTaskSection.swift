import SwiftUI

struct CourseTaskSection: View {
    @Environment(PreviewStore.self) private var store
    @State private var editing: CourseTask?
    @State private var actionError: String?
    let courseID: String

    var body: some View {
        let termID = store.activeTermID
        let tasks = CourseTask.ordered(store.courseTasks.filter { $0.courseID == courseID })
        Section("课程待办") {
            ForEach(tasks) { task in
                taskRow(task, termID: termID)
            }
            Button("添加待办", systemImage: "plus") { editing = CourseTask(courseID: courseID) }
                .accessibilityIdentifier("course-task.add")
        }
        .sheet(item: $editing) { task in
            CourseTaskEditor(task: task, now: store.now) { updated in
                if store.updateCourseTask(updated, termID: termID) { return nil }
                return store.errorMessage ?? "未能保存待办。请确认课程仍在当前学期。"
            }
        }
        .alert("未能更新待办", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("好") { actionError = nil }
        } message: { Text(actionError ?? "") }
    }

    private func taskRow(_ task: CourseTask, termID: String) -> some View {
        HStack(spacing: 4) {
            Button {
                var updated = task
                updated.isCompleted.toggle()
                save(updated, termID: termID)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
                    .foregroundStyle(task.isCompleted ? Color.secondary : DesignSystem.accent)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(task.isCompleted ? "将\(task.title)标为未完成" : "完成\(task.title)")
            .accessibilityIdentifier("course-task.toggle.\(task.title)")

            Button { editing = task } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title).foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted)
                    if let due = task.due {
                        Text(CourseTaskDueLabel.text(due, now: store.now)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.borderless)
        }
        .swipeActions {
            Button("删除待办", systemImage: "trash", role: .destructive) { save(task, termID: termID, deleting: true) }
        }
    }

    private func save(_ task: CourseTask, termID: String, deleting: Bool = false) {
        if !store.updateCourseTask(task, termID: termID, deleting: deleting) {
            actionError = store.errorMessage ?? "请确认课程仍在当前学期。"
        }
    }
}

private struct CourseTaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CourseTask
    @State private var hasDue: Bool
    @State private var due: Date
    @State private var errorMessage: String?
    let onSave: (CourseTask) -> String?

    init(task: CourseTask, now: Date, onSave: @escaping (CourseTask) -> String?) {
        _draft = State(initialValue: task)
        _hasDue = State(initialValue: task.due != nil)
        _due = State(initialValue: task.due ?? (ScheduleRules.calendar.date(byAdding: .day, value: 1, to: now) ?? now))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("例如：交作业、带实验服", text: $draft.title)
                    .accessibilityIdentifier("course-task.title")
                Toggle("设置截止时间", isOn: $hasDue)
                    .accessibilityIdentifier("course-task.has-due")
                if hasDue { DatePicker("截止时间", selection: $due) }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("课程待办")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(!draft.isValid)
                }
            }
        }
    }

    private func save() {
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.due = hasDue ? due : nil
        errorMessage = onSave(draft)
        if errorMessage == nil { dismiss() }
    }
}

enum CourseTaskDueLabel {
    static func text(_ due: Date, now: Date) -> String {
        let calendar = ScheduleRules.calendar
        let day = calendar.isDate(due, inSameDayAs: now) ? "今天"
            : "\(calendar.component(.month, from: due))月\(calendar.component(.day, from: due))日"
        return "\(due < now ? "已逾期 · " : "")\(day) \(ScheduleRules.time(due))"
    }
}
