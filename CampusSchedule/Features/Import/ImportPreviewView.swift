import SwiftUI

/// 导入前的预览与确认。用户在这里看到将要写入的全部内容。
struct ImportPreviewView: View {
    let plan: ImportPlanner.Plan
    let onConfirm: (ImportPlanner.Plan) -> Bool
    let onCancel: () -> Void
    @Environment(PreviewStore.self) private var store
    @State private var writeError: String?

    private var grouped: [(weekday: Int, courses: [ParsedCourse])] {
        Dictionary(grouping: plan.courses, by: \.weekday)
            .map { (weekday: $0.key, courses: $0.value.sorted { $0.startPeriod < $1.startPeriod }) }
            .sorted { $0.weekday < $1.weekday }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("课程安排", value: "\(plan.courses.count) 条")
                    if plan.replacedCount > 0 {
                        LabeledContent("更新已有安排", value: "\(plan.replacedCount) 条")
                    }
                    if !plan.conflicts.isEmpty {
                        LabeledContent("时间重叠", value: "\(plan.conflicts.count) 处")
                            .foregroundStyle(.orange)
                    }
                } header: { Text("将导入「\(store.terms.first { $0.id == plan.targetTermID }?.name ?? store.semesterName)」") }

                ForEach(plan.warnings, id: \.self) { warning in
                    Section { Label(warning, systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary) }
                }
                if let writeError { Section { Text(writeError).font(.footnote) } }

                if !plan.conflicts.isEmpty {
                    Section {
                        ForEach(plan.conflicts.indices, id: \.self) { index in
                            let conflict = plan.conflicts[index]
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(conflict.incoming.title) 与 \(conflict.existingTitle)").font(.callout)
                                Text("\(conflict.detail) · \(conflict.fromSameImport ? "本次导入内" : "与已有课程")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } header: { Text("时间冲突") }
                    footer: { Text("导入后这些时段会有两门课。可以继续导入，之后在课表里调整。") }
                }

                ForEach(grouped, id: \.weekday) { group in
                    Section(weekdayTitle(group.weekday)) {
                        ForEach(group.courses, id: \.self) { course in
                            row(course)
                        }
                    }
                }
            }
            .navigationTitle("确认导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { onCancel() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("导入") {
                        if !onConfirm(plan) { writeError = store.errorMessage ?? "导入未完成，请核对当前学期后重试。" }
                    }
                        .fontWeight(.semibold)
                        .disabled(!plan.isApplicable)
                }
            }
        }
    }

    private func row(_ course: ParsedCourse) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(course.title).lineLimit(1)
            HStack(spacing: 8) {
                Text("第\(course.startPeriod)-\(course.endPeriod)节")
                if !course.room.isEmpty { Text(course.room).lineLimit(1) }
                if !course.teacher.isEmpty { Text(course.teacher).lineLimit(1) }
            }
            .font(.caption).foregroundStyle(.secondary)
            Text(weeksText(course.weeks)).font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private func weeksText(_ weeks: Set<Int>) -> String {
        guard !weeks.isEmpty else { return "整学期" }
        let sorted = weeks.sorted()
        // 连续区间压成「1-8」，其余用逗号。
        var parts: [String] = []
        var start = sorted[0]
        var previous = sorted[0]
        for week in sorted.dropFirst() {
            if week == previous + 1 { previous = week; continue }
            parts.append(start == previous ? "\(start)" : "\(start)-\(previous)")
            start = week; previous = week
        }
        parts.append(start == previous ? "\(start)" : "\(start)-\(previous)")
        return parts.joined(separator: ",") + " 周"
    }

    private func weekdayTitle(_ weekday: Int) -> String {
        "周" + ImportPlanner.weekdayName(weekday)
    }
}

struct ImportArchiveReview: View {
    let archive: ScheduleArchive
    let restore: () throws -> Void
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirming = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                Section("备份内容") {
                    LabeledContent("备份日期") { Text(archive.exportedAt, format: .dateTime.year().month().day().hour().minute()) }
                    LabeledContent("学期", value: "\(archive.semesters.count) 个")
                    LabeledContent("纪念事件", value: "\(archive.milestones.count) 条")
                }
                Section("学期") {
                    ForEach(archive.semesters, id: \.id) { term in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(term.name)
                            Text("\(term.courses.count) 门课程 · \(term.exams.count) 场考试 · \(term.courseTasks.count) 条待办")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Button("恢复这份备份", role: .destructive) { confirming = true }
                } footer: {
                    Text("恢复会替换本机全部学期和纪念事件，并保留恢复前的副本。")
                }
                if let error { Section { Text(error).font(.footnote) } }
            }
            .navigationTitle("预览备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .confirmationDialog("恢复备份并替换本机数据？", isPresented: $confirming, titleVisibility: .visible) {
                Button("替换本机数据", role: .destructive) {
                    do { try restore() }
                    catch { self.error = store.errorMessage ?? error.localizedDescription }
                }
            } message: {
                Text("将用备份中的 \(archive.semesters.count) 个学期替换本机的 \(store.terms.count) 个学期。")
            }
        }
    }
}

struct AcademicChangesView: View {
    let refresh: AcademicRefreshService
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<AcademicRefreshChange> = []
    @State private var removalConfirmation: (connectionID: UUID, changes: [AcademicRefreshChange])?
    @State private var confirmingRemoval = false
    @State private var feedback: String?

    private var changes: [AcademicRefreshChange] {
        guard let connection = refresh.connection, !refresh.requiresReconnect(connection) else { return [] }
        return connection.diff.changes(totalWeeks: connection.totalWeeks)
    }

    private var selectedChanges: [AcademicRefreshChange] { changes.filter { selection.contains($0) } }

    var body: some View {
        NavigationStack {
            List {
                if let connection = refresh.connection {
                    sourceSection(connection)
                    if changes.isEmpty {
                        Text("当前没有待核对的变更。")
                    } else {
                        Section {
                            ForEach(changes) { change in
                                Toggle(isOn: binding(for: change)) { changeRow(change) }
                            }
                        } header: { Text("选择要处理的变更") }
                        actions(connection)
                    }
                    if let termID = connection.termID, store.canUndoAcademicChanges(termID: termID) {
                        Button("撤销上次应用", systemImage: "arrow.uturn.backward") {
                            if store.undoAcademicChanges(termID: termID) {
                                refresh.reopenLastAppliedReview()
                                feedback = "已恢复应用变更前的本地课表。"
                            } else {
                                feedback = store.errorMessage ?? "课表已再次编辑，无法撤销上次应用。"
                            }
                        }
                        .disabled(refresh.busy)
                    }
                } else {
                    Text("教务连接已关闭。")
                }
                if let feedback { Section { Text(feedback).font(.footnote) } }
                if let message = refresh.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("教务课表变更")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
            .onChange(of: changes) { _, current in selection.formIntersection(current) }
            .confirmationDialog("应用选中的教务变更？", isPresented: $confirmingRemoval, titleVisibility: .visible) {
                Button("应用并移除缺少的课程", role: .destructive) {
                    if let removalConfirmation, let connection = refresh.connection, connection.id == removalConfirmation.connectionID {
                        apply(removalConfirmation.changes, to: connection)
                    } else { feedback = "教务连接已变更，请重新选择。" }
                }
            } message: { Text("选中的移除会从本地课表删除对应安排。请先对照学校通知。") }
        }
    }

    private func sourceSection(_ connection: AcademicRefreshService.Connection) -> some View {
        Section("教务来源") {
            LabeledContent("学校", value: connection.school)
            LabeledContent("学期", value: store.terms.first { $0.id == connection.termID }?.name ?? connection.term)
        }
    }

    private func actions(_ connection: AcademicRefreshService.Connection) -> some View {
        Section {
            Button("应用所选到课表", systemImage: "checkmark.circle") {
                if selectedChanges.contains(where: { $0.after == nil }) {
                    removalConfirmation = (connection.id, selectedChanges)
                    confirmingRemoval = true
                } else { apply(selectedChanges, to: connection) }
            }
            .disabled(selectedChanges.isEmpty || refresh.busy || store.storageReadOnly)
            Button("忽略所选", systemImage: "minus.circle") {
                if refresh.markReviewed(id: connection.id, latest: connection.latest, changes: selectedChanges) {
                    selection.removeAll()
                    feedback = "已标记所选变更为忽略。"
                } else { feedback = refresh.message ?? "教务结果已更新，请重新选择。" }
            }
            .disabled(selectedChanges.isEmpty || refresh.busy)
        } footer: { Text("只处理选中的条目。页面未见的课程，请核对停课通知后再移除。") }
    }

    private func apply(_ chosen: [AcademicRefreshChange], to connection: AcademicRefreshService.Connection) {
        guard let termID = connection.termID, refresh.canReview(id: connection.id, latest: connection.latest, changes: chosen) else {
            feedback = "教务结果已更新，请重新选择。"
            return
        }
        guard store.applyAcademicChanges(chosen, termID: termID) else {
            feedback = store.errorMessage ?? "本机课表已变动，请核对后再试。"
            return
        }
        let reviewed = refresh.markReviewed(id: connection.id, latest: connection.latest, changes: chosen, applied: true)
        selection.removeAll()
        feedback = reviewed ? "已应用 \(chosen.count) 条变更。" : "本机课表已更新，教务核对状态暂未保存。"
    }

    private func binding(for change: AcademicRefreshChange) -> Binding<Bool> {
        Binding(get: { selection.contains(change) }, set: { selected in
            if selected { selection.insert(change) }
            else { selection.remove(change) }
        })
    }

    private func changeRow(_ change: AcademicRefreshChange) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(change.after?.title ?? change.before?.title ?? "课程").font(.headline)
            if let before = change.before { courseSummary(before, label: change.after == nil ? "页面未见" : "原安排") }
            if let after = change.after { courseSummary(after, label: change.before == nil ? "新增" : "新安排") }
        }
        .accessibilityElement(children: .combine)
    }

    private func courseSummary(_ course: ParsedCourse, label: String) -> some View {
        let weeks = course.weeks.isEmpty ? "整学期"
            : "第 \(course.weeks.sorted().map(String.init).joined(separator: "、")) 周"
        let room = course.room.isEmpty ? "教室待确认" : course.room
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(label) · 周\(ImportPlanner.weekdayName(course.weekday)) 第 \(course.startPeriod)–\(course.endPeriod) 节")
            Text("\(room) · \(weeks)")
            if !course.teacher.isEmpty { Text(course.teacher) }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
