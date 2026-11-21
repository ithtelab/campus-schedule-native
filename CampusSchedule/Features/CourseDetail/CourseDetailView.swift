import SwiftUI
import ActivityKit

struct CourseDetailView: View {
    let course: DemoCourse
    var character: CampusCharacterPlayer? = nil
    var tasksOnly = false
    var onClose: (() -> Void)? = nil
    var linkedTermID: String? = nil
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var changing = false
    @State private var deleting = false
    @State private var makeup = false
    @State private var activityMessage: String?
    @State private var editingTask: CourseTask?
    private var termID: String { linkedTermID ?? store.activeTermID }
    private var original: DemoCourse { store.course(withID: course.sourceID ?? course.id, in: termID) ?? course }
    private var occurrence: CourseOccurrence? {
        guard course.sourceID != nil else { return nil }
        return store.occurrences(in: termID).first { $0.id == course.id }
    }
    private var activityOccurrence: CourseOccurrence? {
        if course.sourceID != nil { return occurrence }
        return store.occurrences(in: termID).first { $0.courseID == original.id && $0.end > store.now }
    }
    private var canStartActivity: Bool {
        activityOccurrence.map { CourseLivePlan.canStartManually($0, now: store.now, lead: store.reminderMinutes) } ?? false
    }

    var body: some View {
        NavigationStack {
            List {
                if tasksOnly {
                    Text(original.title).font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader)
                } else {
                    if let occurrence {
                        Section("本次安排") {
                            if occurrence.wasRescheduled {
                                Label("本次已调课", systemImage: "calendar.badge.clock")
                            }
                            Text(occurrence.title).font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                            LabeledContent("日期", value: occurrence.start.formatted(courseDateStyle))
                            LabeledContent("时间", value: "\(store.time(occurrence.start))–\(store.time(occurrence.end))")
                            LabeledContent("地点", value: occurrence.room.isEmpty ? "待确认" : occurrence.room)
                        }
                    } else if course.sourceID != nil {
                        Section("本次安排") {
                            Text("这次课程已取消或调整，请查看更新后的课表。")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Section {
                        Toggle("此课程允许提醒", isOn: Binding(get: { original.remindersEnabled }, set: { value in
                            if !store.setCourseReminders(value, courseID: original.id, termID: termID) {
                                activityMessage = store.errorMessage ?? "未能保存课程提醒。"
                            }
                        })).tint(DesignSystem.switchTint)
                        HStack(spacing: 16) {
                            Text(original.title).font(.title.weight(.semibold))
                            if let character { CampusCharacter(player: character, contextDriven: true).frame(width: 88, height: 176) }
                        }
                        LabeledContent("教师", value: original.teacher)
                        LabeledContent("地点", value: original.room)
                        LabeledContent("时间", value: "\(original.startTime)–\(original.endTime)")
                        LabeledContent("周次", value: original.weeks.sorted().map(String.init).joined(separator: "、"))
                    } header: {
                        if course.sourceID != nil { Text("整门课程 · 原安排") }
                    }
                }
                CourseTaskSection(editing: $editingTask, courseID: original.id, termID: termID)
                if !tasksOnly {
                    Section {
                        Button("编辑整门课程", systemImage: "pencil") { editing = true }
                        Button("单次停课或调课", systemImage: "calendar.badge.clock") { changing = true }
                        Button("添加一次补课", systemImage: "calendar.badge.plus") { makeup = true }
                        Button("开始本次实时活动", systemImage: "waveform") {
                            guard let item = activityOccurrence else { return }
                            do { try CourseLiveActivities.shared.start(item, lead: store.reminderMinutes, termID: termID); store.liveEnabled = true }
                            catch { activityMessage = error.localizedDescription }
                        }
                        .disabled(store.isPreview || !canStartActivity)
                        Text("在课前 \(store.reminderMinutes) 分钟内或上课中可开启实时活动。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Section {
                        Button("删除整门课程", role: .destructive) { deleting = true }
                    }
                }
            }
            .navigationTitle(tasksOnly ? "课程待办" : "课程详情").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") {
                if let onClose { onClose() } else { dismiss() }
            } } }
            .sheet(isPresented: $editing) { CourseEditorView(editing: original, targetTermID: termID) }
            .sheet(isPresented: $changing) {
                CourseExceptionView(course: original, termID: termID, initialOccurrenceID: course.sourceID == nil ? nil : course.id)
            }
            .sheet(isPresented: $makeup) { CourseEditorView(template: original, targetTermID: termID) }
            .sheet(item: $editingTask) { task in
                let termID = self.termID
                CourseTaskEditor(task: task, now: store.now) { updated in
                    if store.updateCourseTask(updated, termID: termID) { return nil }
                    return store.errorMessage ?? "未能保存待办。请确认课程仍在原学期。"
                }
            }
            .alert("未能完成操作", isPresented: Binding(get: { activityMessage != nil }, set: { if !$0 { activityMessage = nil } })) {
                Button("好") { activityMessage = nil }
            } message: { Text(activityMessage ?? "") }
            .confirmationDialog("删除课程及其所有安排？", isPresented: $deleting, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if store.deleteCourse(original.id, termID: termID) { dismiss() }
                    else { activityMessage = store.errorMessage ?? "未能删除课程。" }
                }
            } message: {
                if store.courseTasks(in: termID).contains(where: { $0.courseID == original.id }) {
                    Text("这门课关联的待办也会一起删除。")
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct CourseExceptionView: View {
    let course: DemoCourse
    let termID: String
    let initialOccurrenceID: String?
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = ""
    @State private var action: Adjustment?
    @State private var start = Date()
    @State private var end = Date()
    @State private var room = ""
    @State private var saveError: String?

    private enum Adjustment: String, CaseIterable, Identifiable {
        case reschedule = "调课"
        case cancel = "停课"
        var id: Self { self }
    }

    private var occurrences: [CourseOccurrence] { store.occurrences(in: termID) }
    private var items: [CourseOccurrence] {
        occurrences.filter { $0.courseID == course.id && ($0.end > store.now || $0.id == initialOccurrenceID) }
    }
    private var chosen: CourseOccurrence? { items.first { $0.id == selectedID } }
    private var exceptions: [CourseException] {
        store.termContents[termID]?.exceptions.filter { $0.courseID == course.id } ?? []
    }

    private var validationMessage: String? {
        guard action == .reschedule, let term = store.terms.first(where: { $0.id == termID }) else { return nil }
        guard end > start else { return "结束时间需要晚于开始时间。" }
        guard term.contains(start), term.contains(end) else { return "请选择这个学期内的日期。" }
        guard ScheduleRules.calendar.isDate(start, inSameDayAs: end) else { return "开始和结束时间需要在同一天。" }
        if occurrences.contains(where: { $0.id != selectedID && $0.start < end && $0.end > start }) {
            return "调整后的时间与其他安排重叠。"
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if items.isEmpty {
                    Text("目前没有可调整的课程。已停课的安排可以在下方恢复。")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("选择一次课程", selection: $selectedID) {
                        Text("请选择").tag("")
                        ForEach(items) { item in
                            Text("\(item.start.formatted(courseDateStyle)) \(store.time(item.start))").tag(item.id)
                        }
                    }
                    Picker("操作", selection: $action) {
                        Text("请选择").tag(nil as Adjustment?)
                        ForEach(Adjustment.allCases) { value in Text(value.rawValue).tag(Optional(value)) }
                    }
                    .disabled(chosen == nil)
                }
                if action == .reschedule {
                    DatePicker("新的开始时间", selection: $start)
                    DatePicker("新的结束时间", selection: $end)
                    TextField("新的教室", text: $room)
                }
                Text("只影响选中的这一次课程，其他教学周保持不变。")
                if let validationMessage { Text(validationMessage).foregroundStyle(.secondary) }
                if !exceptions.isEmpty {
                    Section("已调整的课程") {
                        ForEach(exceptions.sorted { $0.day < $1.day }) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(item.day.formatted(courseDateStyle)) · \(item.cancelled ? "停课" : "调课")")
                                    if let newStart = item.start {
                                        Text("调整至 \(newStart.formatted(courseDateStyle)) \(store.time(newStart))")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button("恢复") { save(item, deleting: true) }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
            .navigationTitle("单次调整").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard let chosen, let action else { return }
                        let cancelled = action == .cancel
                        let room = room.trimmingCharacters(in: .whitespacesAndNewlines)
                        save(.init(courseID: course.id, day: originalDay(of: chosen), cancelled: cancelled,
                                   start: cancelled ? nil : start, end: cancelled ? nil : end,
                                   room: cancelled || room.isEmpty ? nil : room))
                    }
                    .disabled(chosen == nil || action == nil || validationMessage != nil || store.storageReadOnly)
                }
            }
            .task {
                if let initialOccurrenceID, items.contains(where: { $0.id == initialOccurrenceID }) {
                    selectedID = initialOccurrenceID
                }
                load()
            }
            .onChange(of: selectedID) { _, _ in load() }
            .alert("未能更新课程", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("好", role: .cancel) {}
            } message: { Text(saveError ?? "") }
        }
        .environment(\.timeZone, ScheduleRules.calendar.timeZone)
    }
    private func originalDay(of occurrence: CourseOccurrence) -> Date {
        let stamp = occurrence.id.split(separator: ":").last.flatMap { TimeInterval($0) }
        return stamp.map { Date(timeIntervalSince1970: $0) } ?? occurrence.start
    }

    private func load() {
        guard let chosen else { action = nil; return }
        let day = originalDay(of: chosen)
        let existing = exceptions.last { ScheduleRules.calendar.isDate($0.day, inSameDayAs: day) }
        action = existing.map { $0.cancelled ? .cancel : .reschedule }
        start = chosen.start
        end = chosen.end
        room = chosen.room
    }

    private func save(_ adjustment: CourseException, deleting: Bool = false) {
        guard store.updateCourseException(adjustment, termID: termID, deleting: deleting) else {
            saveError = store.errorMessage ?? "请检查这门课程是否仍在该学期。"
            return
        }
        if deleting { load() } else { dismiss() }
    }
}

private var courseDateStyle: Date.FormatStyle {
    var style = Date.FormatStyle.dateTime.year().month().day().weekday(.abbreviated)
    style.calendar = ScheduleRules.calendar
    style.timeZone = ScheduleRules.calendar.timeZone
    return style
}
