import SwiftUI

struct AcademicSettingsView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var start = Date()
    @State private var weeks = 20
    @State private var periods: [DemoPeriod] = []

    private var valid: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              Calendar.current.component(.weekday, from: start) == 2, periods.count == 10 else { return false }
        for index in periods.indices {
            guard periods[index].start < periods[index].end else { return false }
            if index > 0 && periods[index - 1].end > periods[index].start { return false }
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("学期名称", text: $name)
                    DatePicker("第一周周一", selection: $start, displayedComponents: .date)
                    Stepper("共 \(weeks) 个教学周", value: $weeks, in: 1...30)
                } header: { Text("学期") }
                footer: { Text("第一周从周一开始。设置后，课表的日期与教学周会一起调整。") }

                ForEach([0, 4, 8], id: \.self) { group in
                    Section(group == 0 ? "上午" : group == 4 ? "下午" : "晚上") {
                        ForEach(group..<(group == 8 ? 10 : group + 4), id: \.self) { index in
                            if periods.indices.contains(index) {
                                periodRow(index)
                            }
                        }
                    }
                }
                Section {
                    if !valid { Label("请检查：开学日为周一，各节时间先后有序且不重叠", systemImage: "exclamationmark.circle").foregroundStyle(.orange) }
                    Label(store.isPreview ? "演示学期与作息" : "本地学期与作息", systemImage: "info.circle").foregroundStyle(.secondary)
                } footer: { Text(store.isPreview ? "仅在演示会话生效。" : "保存到本机，并同步更新课程时间、通知和组件。") }
            }
            .navigationTitle("学期与作息").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.semesterName = name
                        store.semesterStart = Calendar.current.startOfDay(for: start)
                        store.totalWeeks = weeks
                        store.selectedWeek = min(store.selectedWeek, weeks)
                        store.periods = periods
                        store.refreshCourseTimes()
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
            .task {
                name = store.semesterName; start = store.semesterStart
                weeks = store.totalWeeks; periods = store.periods
            }
        }
        .presentationDetents([.large])
    }

    private func periodRow(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("第 \(index + 1) 节").font(.subheadline.weight(.medium))
            HStack {
                DatePicker("开始", selection: timeBinding(index, start: true), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Text("—").foregroundStyle(.tertiary)
                DatePicker("结束", selection: timeBinding(index, start: false), displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }

    private func timeBinding(_ index: Int, start: Bool) -> Binding<Date> {
        Binding {
            let value = start ? periods[index].start : periods[index].end
            let parts = value.split(separator: ":").compactMap { Int($0) }
            return Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1,
                hour: parts[0], minute: parts[1])) ?? Date()
        } set: { value in
            let hour = Calendar.current.component(.hour, from: value)
            let minute = Calendar.current.component(.minute, from: value)
            let formatted = String(format: "%02d:%02d", hour, minute)
            if start { periods[index].start = formatted } else { periods[index].end = formatted }
        }
    }
}
