import SwiftUI

/// 学期列表：切换、新建、重命名、删除。
struct TermListView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: TermSummary?
    @State private var renameText = ""
    @State private var pendingDeletion: TermSummary?
    @State private var creationError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.terms) { term in
                        Button {
                            store.selectTerm(term.id)
                            dismiss()
                        } label: {
                            row(term)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(term.id == store.activeTermID ? .isSelected : [])
                        .accessibilityIdentifier("term.\(term.id)")
                        .swipeActions(edge: .trailing) {
                            if store.terms.count > 1 {
                                Button("删除", systemImage: "trash", role: .destructive) {
                                    pendingDeletion = term
                                }
                            }
                            Button("重命名", systemImage: "pencil") {
                                renameText = term.name
                                renaming = term
                            }
                        }
                    }
                } header: {
                    Text("全部学期")
                } footer: {
                    Text("轻点切换查看课表。课程提醒和组件按学期日期自动选择课表。")
                }
            }
            .navigationTitle("学期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新建", systemImage: "plus") { createTerm() }
                }
            }
            .alert("重命名学期", isPresented: .init(
                get: { renaming != nil },
                set: { if !$0 { renaming = nil } }
            )) {
                TextField("学期名称", text: $renameText)
                Button("保存") {
                    if let term = renaming { store.renameTerm(term.id, to: renameText) }
                    renaming = nil
                }
                Button("取消", role: .cancel) { renaming = nil }
            }
            .confirmationDialog("删除这个学期？", isPresented: .init(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ), presenting: pendingDeletion) { term in
                Button("删除「\(term.name)」", role: .destructive) {
                    store.deleteTerm(term.id)
                    pendingDeletion = nil
                }
                Button("取消", role: .cancel) { pendingDeletion = nil }
            } message: { term in
                Text("将删除该学期的课程、作息、调停课、考试和待办。删除前会备份，可从设置里的「备份记录与学期恢复」恢复。")
            }
            .alert("未能新建学期", isPresented: Binding(get: { creationError != nil }, set: { if !$0 { creationError = nil } })) {
                Button("好", role: .cancel) {}
            } message: { Text(creationError ?? "") }
        }
    }

    private func row(_ term: TermSummary) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(term.name).foregroundStyle(.primary)
                Text(dateRange(term)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if term.id == store.activeTermID {
                Image(systemName: "checkmark").foregroundStyle(DesignSystem.accent)
            }
        }
        .contentShape(Rectangle())
    }

    private func dateRange(_ term: TermSummary) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = ScheduleRules.calendar.timeZone
        formatter.dateFormat = "yyyy.MM.dd"
        return "\(formatter.string(from: term.startDate)) – \(formatter.string(from: term.endDate)) · \(term.totalWeeks) 周"
    }

    private func createTerm() {
        let previous = store.activeTermID
        let id = store.addTerm()
        guard id != previous else {
            creationError = store.errorMessage ?? "请稍后再试。"
            return
        }
        store.selectTerm(id)
        if let created = store.terms.first(where: { $0.id == id }) {
            renameText = created.name
            renaming = created
        }
    }
}
