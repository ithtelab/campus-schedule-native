import SwiftUI

/// 考试列表与编辑。考试按当前学期保存，删除学期时一并移除。
struct ExamListView: View {
    @Environment(PreviewStore.self) private var store
    @State private var editing: Exam?
    @State private var showingEditor = false
    @State private var pendingDeletion: Exam?

    private var ordered: [Exam] { ExamPlan.chronological(store.exams) }

    var body: some View {
        List {
            if ordered.isEmpty {
                ContentUnavailableView("还没有考试安排", systemImage: "graduationcap",
                                       description: Text("添加考试后，可以在这里查看考场、座位和倒计时。"))
            } else {
                ForEach(ordered) { exam in
                    Button { edit(exam) } label: { row(exam) }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("删除", systemImage: "trash", role: .destructive) { pendingDeletion = exam }
                        }
                }
            }
        }
        .navigationTitle("考试安排")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("添加", systemImage: "plus") { edit(nil) }
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let editing {
                ExamEditorView(exam: editing) { updated in
                    save(updated)
                    showingEditor = false
                } onCancel: { showingEditor = false }
            }
        }
        .confirmationDialog("删除这场考试？", isPresented: .init(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), presenting: pendingDeletion) { exam in
            Button("删除", role: .destructive) {
                store.exams.removeAll { $0.id == exam.id }
                pendingDeletion = nil
            }
            Button("取消", role: .cancel) { pendingDeletion = nil }
        } message: { exam in
            Text("「\(exam.courseTitle)」会从列表中移除。")
        }
    }

    private func row(_ exam: Exam) -> some View {
        let finished = ExamPlan.isFinished(exam, now: store.now)
        return HStack(spacing: 14) {
            VStack(spacing: 1) {
                Text(dayNumber(exam.date)).font(.title2.weight(.semibold)).monospacedDigit()
                Text(monthText(exam.date)).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(exam.courseTitle).foregroundStyle(finished ? .secondary : .primary).lineLimit(1)
                Text("\(exam.startTime)–\(exam.endTime)\(exam.room.isEmpty ? "" : " · \(exam.room)")")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if !exam.seatNumber.isEmpty {
                    Text("座位 \(exam.seatNumber)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if finished {
                Text("已考").font(.caption2).foregroundStyle(.tertiary)
            } else if let days = ExamPlan.daysUntilNext([exam], now: store.now) {
                Text(days == 0 ? "今天" : "\(days) 天")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DesignSystem.accent)
            }
        }
        .contentShape(Rectangle())
    }

    private func dayNumber(_ date: Date) -> String {
        String(ScheduleRules.calendar.component(.day, from: date))
    }
    private func monthText(_ date: Date) -> String {
        "\(ScheduleRules.calendar.component(.month, from: date))月"
    }

    private func edit(_ exam: Exam?) {
        editing = exam ?? Exam(courseTitle: "", date: store.now,
                               startTime: "09:00", endTime: "11:00")
        showingEditor = true
    }

    private func save(_ exam: Exam) {
        if let index = store.exams.firstIndex(where: { $0.id == exam.id }) {
            store.exams[index] = exam
        } else {
            store.exams.append(exam)
        }
    }
}

/// 新增或编辑一场考试。
struct ExamEditorView: View {
    @Environment(PreviewStore.self) private var store
    @State private var draft: Exam
    @State private var errorText: String?
    let onSave: (Exam) -> Void
    let onCancel: () -> Void

    init(exam: Exam, onSave: @escaping (Exam) -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: exam)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("考试科目", text: $draft.courseTitle)
                    DatePicker("日期", selection: $draft.date, displayedComponents: .date)
                    HStack {
                        TextField("开始", text: $draft.startTime).monospacedDigit()
                        Text("–").foregroundStyle(.secondary)
                        TextField("结束", text: $draft.endTime).monospacedDigit()
                    }
                } header: { Text("基本信息") }
                footer: { Text("时间格式为 24 小时制，例如 09:00。") }

                Section("考场") {
                    TextField("考场", text: $draft.room)
                    TextField("座位号", text: $draft.seatNumber).keyboardType(.numbersAndPunctuation)
                    TextField("备注", text: $draft.notes, axis: .vertical).lineLimit(2...4)
                }

                if let overlapping = overlappingTitles {
                    Section {
                        Label("与「\(overlapping)」时间重叠", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } footer: {
                        Text("同一天的两场考试时间重叠，通常是录入有误。仍然可以保存。")
                    }
                }

                if let errorText {
                    Section { Label(errorText, systemImage: "exclamationmark.circle").foregroundStyle(.red) }
                }
            }
            .navigationTitle(draft.courseTitle.isEmpty ? "添加考试" : "编辑考试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { onCancel() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { attemptSave() }.fontWeight(.semibold)
                }
            }
        }
    }

    /// 与已有考试冲突的科目名，用于提示而不是阻止保存。
    private var overlappingTitles: String? {
        let others = store.exams.filter { $0.id != draft.id }
        for other in others {
            guard let aStart = ExamPlan.startDate(draft), let aEnd = ExamPlan.endDate(draft),
                  let bStart = ExamPlan.startDate(other), let bEnd = ExamPlan.endDate(other) else { continue }
            guard ScheduleRules.calendar.isDate(aStart, inSameDayAs: bStart) else { continue }
            if aStart < bEnd && bStart < aEnd { return other.courseTitle }
        }
        return nil
    }

    private func attemptSave() {
        if let message = ExamPlan.validate(draft).errorDescription {
            errorText = message
            return
        }
        errorText = nil
        onSave(draft)
    }
}
