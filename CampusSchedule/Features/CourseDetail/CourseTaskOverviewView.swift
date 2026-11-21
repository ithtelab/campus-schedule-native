import SwiftUI

struct CourseTaskOverviewView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Row?
    @State private var showingCourse: Row?
    @State private var actionError: String?

    private struct Row: Identifiable {
        let term: TermSummary
        let course: DemoCourse
        let task: CourseTask
        var id: String { "\(term.id):\(task.id.uuidString)" }
    }

    private enum Group: String, CaseIterable {
        case overdue = "逾期"
        case today = "今天"
        case thisWeek = "本周"
        case later = "之后"
        case noDueDate = "无截止时间"
        case finished = "已完成"

        init(task: CourseTask, now: Date) {
            if task.isCompleted { self = .finished; return }
            guard let due = task.due else { self = .noDueDate; return }
            if due < now { self = .overdue; return }
            let calendar = ScheduleRules.calendar
            if calendar.isDate(due, inSameDayAs: now) { self = .today; return }
            let weekday = calendar.component(.weekday, from: now)
            let daysUntilNextMonday = 7 - (weekday + 5) % 7
            let nextMonday = calendar.date(byAdding: .day, value: daysUntilNextMonday, to: calendar.startOfDay(for: now)) ?? now
            self = due < nextMonday ? .thisWeek : .later
        }
    }

    private var rows: [Row] {
        store.terms.flatMap { term in
            CourseTask.ordered(store.courseTasks(in: term.id)).compactMap { task in
                guard let course = store.course(withID: task.courseID, in: term.id) else { return nil }
                return Row(term: term, course: course, task: task)
            }
        }.sorted { ($0.task.due ?? .distantFuture) < ($1.task.due ?? .distantFuture) }
    }

    var body: some View {
        NavigationStack {
            List {
                let grouped = Dictionary(grouping: rows, by: { Group(task: $0.task, now: store.now) })
                ForEach(Group.allCases, id: \.self) { group in
                    if let entries = grouped[group] {
                        Section(group.rawValue) {
                            ForEach(entries) { row in taskRow(row) }
                        }
                    }
                }
            }
            .overlay {
                if rows.isEmpty {
                    ContentUnavailableView("还没有课程待办", systemImage: "checklist", description: Text("打开一门课，记下作业、截止时间或需要带的东西。"))
                }
            }
            .navigationTitle("待办总览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .sheet(item: $editing) { row in
                CourseTaskEditor(task: row.task, now: store.now) { updated in
                    store.updateCourseTask(updated, termID: row.term.id) ? nil : saveError
                }
            }
            .sheet(item: $showingCourse) { row in
                CourseDetailView(course: row.course, linkedTermID: row.term.id)
            }
            .alert("未能更新待办", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
                Button("好", role: .cancel) {}
            } message: { Text(actionError ?? "") }
        }
    }

    private var saveError: String { store.errorMessage ?? "课程或待办已变化，请返回后重试。" }

    private func taskRow(_ row: Row) -> some View {
        HStack(spacing: 8) {
            Button {
                var task = row.task
                task.isCompleted.toggle()
                if !store.updateCourseTask(task, termID: row.term.id) { actionError = saveError }
            } label: {
                Image(systemName: row.task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(row.task.isCompleted ? "将\(row.task.title)标为未完成" : "完成\(row.task.title)")
            Button { editing = row } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.task.title).strikethrough(row.task.isCompleted)
                    Text("\(row.course.title) · \(row.term.name)")
                        .font(.caption).foregroundStyle(.secondary)
                    if let due = row.task.due {
                        Text(CourseTaskDueLabel.text(due, now: store.now, completed: row.task.isCompleted))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("编辑待办")
        }
        .swipeActions {
            Button("查看课程", systemImage: "book") { showingCourse = row }
        }
        .contextMenu {
            Button("查看课程", systemImage: "book") { showingCourse = row }
            Button("编辑待办", systemImage: "pencil") { editing = row }
        }
    }
}
