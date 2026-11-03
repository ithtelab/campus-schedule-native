import SwiftUI

struct AcademicSettingsView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var start = Date()
    @State private var weeks = 20
    @State private var periods: [DemoPeriod] = []
    @State private var termID = ""
    @State private var confirmingRemoval = false
    @State private var saveError: String?
    private var affected: [String] { store.academicChangesRemovingCourses(periodCount: periods.count, weeks: weeks) }

    private var valid: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              ScheduleRules.calendar.component(.weekday, from: start) == 2,
              PreviewStore.supportedPeriodRange.contains(periods.count) else { return false }
        for index in periods.indices {
            guard periods[index].start < periods[index].end else { return false }
            if index > 0 && periods[index - 1].end > periods[index].start { return false }
        }
        return true
    }

    /// 按上午 / 下午 / 晚上分组展示。节次数量随学校而异，因此按实际数量分组。
    private var groups: [(title: String, range: Range<Int>)] {
        let count = periods.count
        let morningEnd = min(count, 4)
        let afternoonEnd = min(count, 8)
        var result: [(String, Range<Int>)] = [("上午", 0..<morningEnd)]
        if afternoonEnd > morningEnd { result.append(("下午", morningEnd..<afternoonEnd)) }
        if count > afternoonEnd { result.append(("晚上", afternoonEnd..<count)) }
        return result
    }

    /// 追加一节，默认比上一节晚 50 分钟、45 分钟课时。
    private func appendPeriod() {
        guard previewCount < PreviewStore.supportedPeriodRange.upperBound else { return }
        let previous = periods.last
        let nextIndex = periods.count + 1
        let newStart = previous.flatMap { period -> String? in
            guard let parts = Self.minutes(period.end) else { return nil }
            let start = min(parts + 5, 23 * 60 + 59)
            return String(format: "%02d:%02d", start / 60, start % 60)
        } ?? "08:00"
        let newEnd = Self.minutes(newStart).map { start -> String in
            let end = min(start + 45, 23 * 60 + 59)
            return String(format: "%02d:%02d", end / 60, end % 60)
        } ?? "08:45"
        periods.append(DemoPeriod(id: nextIndex, start: newStart, end: newEnd))
    }

    private func removeLastPeriod() {
        guard periods.count > PreviewStore.supportedPeriodRange.lowerBound else { return }
        periods.removeLast()
    }

    private static func minutes(_ value: String) -> Int? {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    /// 让 Stepper 用 Int 绑定数量，而不是直接编辑数组。
    private var previewCount: Int { periods.count }
    private var countBinding: Binding<Int> {
        Binding(get: { periods.count }, set: { target in
            let clamped = min(max(target, PreviewStore.supportedPeriodRange.lowerBound),
                              PreviewStore.supportedPeriodRange.upperBound)
            if clamped > periods.count {
                while periods.count < clamped { appendPeriod() }
            } else if clamped < periods.count {
                while periods.count > clamped { removeLastPeriod() }
            }
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("学期名称", text: $name)
                    DatePicker("第一周周一", selection: $start, displayedComponents: .date)
                    Stepper("共 \(weeks) 个教学周", value: $weeks, in: 1...53)
                } header: { Text("学期") }
                footer: { Text("第一周从周一开始。设置后，课表的日期与教学周会一起调整。") }

                Section {
                    Stepper("共 \(periods.count) 节", value: countBinding,
                            in: PreviewStore.supportedPeriodRange)
                } header: { Text("节次数量") }
                footer: { Text("按学校作息设置。多数学校为 8–14 节。") }

                ForEach(groups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.range, id: \.self) { index in
                            if periods.indices.contains(index) { periodRow(index) }
                        }
                    }
                }
                if !valid {
                    Section { Label("请检查：开学日为周一，各节时间先后有序且不重叠", systemImage: "exclamationmark.circle").foregroundStyle(.primary) }
                }
                if let saveError { Section { Text(saveError).font(.footnote) } }
            }
            .navigationTitle("学期与作息").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if affected.isEmpty { save() } else { confirmingRemoval = true }
                    }
                    .disabled(!valid || store.storageReadOnly || termID != store.activeTermID)
                }
            }
            .task {
                name = store.semesterName; start = store.semesterStart
                weeks = store.totalWeeks; periods = store.periods
                termID = store.activeTermID
            }
            .confirmationDialog("部分课程超出新作息或教学周", isPresented: $confirmingRemoval, titleVisibility: .visible) {
                Button("移除 \(affected.count) 门课程并保存", role: .destructive) { save() }
                Button("继续编辑", role: .cancel) {}
            } message: {
                Text("将移除：\(affected.joined(separator: "、"))。相关调停课记录也会移除。保存前会保留原始副本。")
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        if store.applyAcademicSettings(termID: termID, name: name, start: start, weeks: weeks, periods: periods) { dismiss() }
        else { saveError = store.errorMessage ?? "未能保存，请检查学期设置。" }
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
            // 下标与时间都做保护：编辑过程中数组可能被增删，时间字符串也可能来自旧备份。
            guard periods.indices.contains(index) else { return Date() }
            let value = start ? periods[index].start : periods[index].end
            let parts = value.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return Date() }
            return ScheduleRules.calendar.date(from: DateComponents(year: 2026, month: 1, day: 1,
                hour: parts[0], minute: parts[1])) ?? Date()
        } set: { value in
            guard periods.indices.contains(index) else { return }
            let hour = ScheduleRules.calendar.component(.hour, from: value)
            let minute = ScheduleRules.calendar.component(.minute, from: value)
            let formatted = String(format: "%02d:%02d", hour, minute)
            if start { periods[index].start = formatted } else { periods[index].end = formatted }
        }
    }
}
