import SwiftUI

/// 考试列表与编辑。考试按当前学期保存，删除学期时一并移除。
struct ExamListView: View {
    @Environment(PreviewStore.self) private var store
    @State private var editing: Exam?
    @State private var pendingDeletion: Exam?
    @State private var actionError: String?

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
                        .accessibilityIdentifier("exam.row.\(exam.id)")
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
                    .accessibilityIdentifier("exam.add")
            }
        }
        .sheet(item: $editing) { exam in
            let termID = store.activeTermID
            ExamEditorView(exam: exam) { updated in
                guard store.updateExam(updated, termID: termID) else { return false }
                editing = nil
                return true
            } onCancel: { editing = nil }
            .id(exam.id)
            .environment(store)
        }
        .confirmationDialog("删除这场考试？", isPresented: .init(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), presenting: pendingDeletion) { exam in
            Button("删除", role: .destructive) {
                if !store.updateExam(exam, termID: store.activeTermID, deleting: true) {
                    actionError = store.errorMessage ?? "无法删除这场考试。"
                }
                pendingDeletion = nil
            }
            Button("取消", role: .cancel) { pendingDeletion = nil }
        } message: { exam in
            Text("「\(exam.courseTitle)」会从列表中移除。")
        }
        .alert("未能删除考试", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("好") { actionError = nil }
        } message: { Text(actionError ?? "") }
        .task {
            if store.isPreview && ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_SHEET"] == "exam-editor" {
                edit(nil)
            }
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
    }

}

/// 新增或编辑一场考试。
struct ExamEditorView: View {
    @Environment(PreviewStore.self) private var store
    @State private var draft: Exam
    @State private var errorText: String?
    @State private var reminders: ExamReminders
    @State private var checkingPermission = false
    @State private var showPermissionAlert = false
    let onSave: (Exam) -> Bool
    let onCancel: () -> Void

    init(exam: Exam, onSave: @escaping (Exam) -> Bool, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: exam)
        _reminders = State(initialValue: exam.reminders ?? ExamReminders())
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("考试科目", text: $draft.courseTitle)
                        .accessibilityIdentifier("exam.title")
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

                Section {
                    Toggle("前一天同一时间", isOn: $reminders.dayBefore)
                        .accessibilityIdentifier("exam.reminder.day-before")
                    Toggle("开考前 30 分钟", isOn: $reminders.beforeStart)
                        .accessibilityIdentifier("exam.reminder.before-start")
                } header: { Text("考试提醒") }
                footer: { Text("提醒由 iPhone 本地发送。已过的提醒时间会自动跳过。") }

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
            .disabled(checkingPermission)
            .interactiveDismissDisabled(checkingPermission)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { onCancel() }.disabled(checkingPermission) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { attemptSave() }.fontWeight(.semibold).disabled(checkingPermission)
                }
            }
            .alert("通知权限未开启", isPresented: $showPermissionAlert) {
                Button("保存考试") { persist() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("考试安排和提醒设置可以保存。请在 iOS 设置中允许课间册发送通知，才能收到提醒。")
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
        guard reminders.isEnabled, !store.isPreview else { persist(); return }
        checkingPermission = true
        Task { @MainActor in
            defer { checkingPermission = false }
            do {
                if try await CourseNotifications.shared.authorize() { persist() }
                else { showPermissionAlert = true }
            } catch { showPermissionAlert = true }
        }
    }

    private func persist() {
        draft.courseTitle = draft.courseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.reminders = reminders.isEnabled ? reminders : nil
        errorText = nil
        if !onSave(draft) { errorText = store.errorMessage ?? "无法保存考试，请稍后重试。" }
    }
}

struct ExamSessionView: View {
    let session: ExamSession

    var body: some View {
        List {
            Section {
                Text(session.title).font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader)
                LabeledContent("日期", value: session.dateLabel(relativeTo: Date()))
                LabeledContent("时间", value: "\(ScheduleRules.time(session.start))–\(ScheduleRules.time(session.end))")
            }
            Section("考场信息") {
                LabeledContent("考场", value: session.room.isEmpty ? "待确认" : session.room)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("exam.detail.room")
                LabeledContent("座位", value: session.seat.isEmpty ? "待确认" : session.seat)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("exam.detail.seat")
            }
        }
        .navigationTitle("考试详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
