import SwiftUI
import ActivityKit

struct CourseDetailView: View {
    let course: DemoCourse
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var changing = false
    @State private var deleting = false
    @State private var makeup = false
    private var original: DemoCourse { store.courses.first { $0.id == (course.sourceID ?? course.id) } ?? course }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("此课程允许提醒", isOn: Binding(get: { original.remindersEnabled }, set: { value in
                        if let index = store.courses.firstIndex(where: { $0.id == original.id }) { store.courses[index].remindersEnabled = value }
                    })).tint(DesignSystem.accent)
                    Text(original.title).font(.title.weight(.semibold))
                    LabeledContent("教师", value: original.teacher)
                    LabeledContent("地点", value: original.room)
                    LabeledContent("时间", value: "\(original.startTime)–\(original.endTime)")
                    LabeledContent("周次", value: original.weeks.sorted().map(String.init).joined(separator: "、"))
                }
                Section {
                    Button("编辑整门课程", systemImage: "pencil") { editing = true }
                    Button("单次停课或调课", systemImage: "calendar.badge.clock") { changing = true }
                    Button("添加一次补课", systemImage: "calendar.badge.plus") { makeup = true }
                    Button("开始本次实时活动", systemImage: "waveform") {
                        guard let item = store.occurrences.first(where: { $0.courseID == original.id && $0.end > store.now }) else { return }
                        do { try CourseLiveActivities.shared.start(item); store.liveEnabled = true } catch { store.errorMessage = error.localizedDescription }
                    }
                    .disabled(store.isPreview)
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
            .confirmationDialog("删除课程及其所有安排？", isPresented: $deleting, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    store.courses.removeAll { $0.id == original.id }
                    store.exceptions.removeAll { $0.courseID == original.id }
                    dismiss()
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
                Toggle("本次停课", isOn: $cancelled)
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
