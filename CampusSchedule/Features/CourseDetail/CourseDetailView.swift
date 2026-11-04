import SwiftUI
import ActivityKit

struct CourseDetailView: View {
    let course: DemoCourse
    var character: CampusCharacterPlayer? = nil
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var changing = false
    @State private var deleting = false
    @State private var makeup = false
    @State private var activityMessage: String?
    private var original: DemoCourse { store.courses.first { $0.id == (course.sourceID ?? course.id) } ?? course }
    private var nextOccurrence: CourseOccurrence? { store.occurrences.first { $0.courseID == original.id && $0.end > store.now } }
    private var canStartActivity: Bool {
        nextOccurrence.map { CourseLivePlan.canStartManually($0, now: store.now, lead: store.reminderMinutes) } ?? false
    }

    /// 详情页的联系信息。
    ///
    /// 标题必须跟着值一起变：教务导入拿不到教学班时（教师端没有可用的公开数据源），
    /// 若标题写着「教学班」而值是教师姓名，比不显示还糟。因此只有确实有教学班时
    /// 才把它当主字段。
    private var contactLabel: String {
        if store.appearance.role == .teacher, !original.teachingClassText.isEmpty {
            return CampusRole.teacher.courseContactLabel
        }
        return CampusRole.student.courseContactLabel
    }

    private var contact: String {
        if store.appearance.role == .teacher, !original.teachingClassText.isEmpty {
            return original.teachingClassText
        }
        return original.teacher
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("此课程允许提醒", isOn: Binding(get: { original.remindersEnabled }, set: { value in
                        if let index = store.courses.firstIndex(where: { $0.id == original.id }) { store.courses[index].remindersEnabled = value }
                    })).tint(DesignSystem.switchTint)
                    HStack(spacing: 16) {
                        Text(original.title).font(.title.weight(.semibold))
                        if let character { CampusCharacter(player: character, contextDriven: true).frame(width: 88, height: 176) }
                    }
                    LabeledContent(contactLabel, value: contact)
                    if !original.teachingClassText.isEmpty && store.appearance.role == .student {
                        // 学生视角很少关心教学班，但合班上课时会写在教务页上，有就显示。
                        LabeledContent("教学班", value: original.teachingClassText)
                    }
                    LabeledContent("地点", value: original.room)
                    LabeledContent("时间", value: "\(original.startTime)–\(original.endTime)")
                    LabeledContent("周次", value: original.weeks.sorted().map(String.init).joined(separator: "、"))
                }
                if store.appearance.role == .teacher, let item = nextOccurrence {
                    Section {
                        // 备课状态按这一堂课记录；标记后课程仍完整保留在课表里。
                        Toggle("本次已备课", isOn: Binding(
                            get: { store.isPrepared(item) },
                            set: { _ in store.togglePrepared(item) }
                        )).tint(DesignSystem.switchTint)
                        Text("只标记 \(item.start.formatted(.dateTime.month().day().hour().minute())) 这一次课，不影响其他教学周。")
                            .font(.caption).foregroundStyle(.secondary)
                    } header: { Text("备课") }
                }
                Section {
                    Button("编辑整门课程", systemImage: "pencil") { editing = true }
                    Button("单次停课或调课", systemImage: "calendar.badge.clock") { changing = true }
                    Button("添加一次补课", systemImage: "calendar.badge.plus") { makeup = true }
                    Button("开始本次实时活动", systemImage: "waveform") {
                        guard let item = nextOccurrence else { return }
                        do { try CourseLiveActivities.shared.start(item, lead: store.reminderMinutes, termID: store.activeTermID); store.liveEnabled = true }
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
            .navigationTitle("课程详情").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .sheet(isPresented: $editing) { CourseEditorView(editing: original) }
            .sheet(isPresented: $changing) { CourseExceptionView(course: original) }
            .sheet(isPresented: $makeup) { CourseEditorView(template: original) }
            .alert("未能完成操作", isPresented: Binding(get: { activityMessage != nil }, set: { if !$0 { activityMessage = nil } })) {
                Button("好") { activityMessage = nil }
            } message: { Text(activityMessage ?? "") }
            .confirmationDialog("删除课程及其所有安排？", isPresented: $deleting, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if store.deleteCourse(original.id) { dismiss() }
                    else { activityMessage = store.errorMessage ?? "未能删除课程。" }
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct CourseExceptionView: View {
    let course: DemoCourse
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = ""
    @State private var cancelled = true
    @State private var start = Date()
    @State private var end = Date()
    @State private var room = ""
    private var items: [CourseOccurrence] { store.occurrences.filter { $0.courseID == course.id && $0.end > store.now } }
    private var chosen: CourseOccurrence? { items.first { $0.id == selectedID } }
    var body: some View {
        NavigationStack {
            Form {
                Picker("选择一次课程", selection: $selectedID) {
                    ForEach(items) { item in Text(item.start, format: .dateTime.month().day().hour().minute()).tag(item.id) }
                }
                Toggle("本次停课", isOn: $cancelled).tint(DesignSystem.switchTint)
                if !cancelled {
                    DatePicker("新的开始时间", selection: $start)
                    DatePicker("新的结束时间", selection: $end)
                    TextField("新的教室", text: $room)
                }
                Text("只影响选中的这一次课程，其他教学周保持不变。")
                ForEach(store.exceptions.filter { $0.courseID == course.id }) { item in
                    HStack {
                        Text(item.day, format: .dateTime.month().day())
                        Text(item.cancelled ? "停课" : "调课")
                        Spacer()
                        Button("恢复") { store.exceptions.removeAll { $0.id == item.id } }
                    }
                }
            }
            .navigationTitle("单次调整").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard let chosen else { return }
                        // 实例 ID 保留原始日期；调课后再次调整仍对应同一堂课。
                        let stamp = chosen.id.split(separator: ":").last.flatMap { TimeInterval($0) }
                        let day = stamp.map { Date(timeIntervalSince1970: $0) } ?? chosen.start
                        store.exceptions.removeAll { $0.courseID == course.id && ScheduleRules.calendar.isDate($0.day, inSameDayAs: day) }
                        store.exceptions.append(.init(courseID: course.id, day: day, cancelled: cancelled,
                            start: cancelled ? nil : start, end: cancelled ? nil : end, room: cancelled ? nil : room))
                        dismiss()
                    }
                    .disabled(chosen == nil || (!cancelled && (end <= start || store.occurrences.contains { $0.id != selectedID && $0.start < end && $0.end > start })))
                }
            }
            .task { selectedID = items.first?.id ?? ""; load() }
            .onChange(of: selectedID) { _, _ in load() }
        }
        .environment(\.timeZone, ScheduleRules.calendar.timeZone)
    }
    private func load() { if let chosen { start = chosen.start; end = chosen.end; room = chosen.room } }
}
