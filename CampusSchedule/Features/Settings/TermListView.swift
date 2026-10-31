import SwiftUI

/// 学期列表：切换、新建、重命名、删除。
struct TermListView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: TermSummary?
    @State private var renameText = ""
    @State private var pendingDeletion: TermSummary?

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
                    Text("轻点切换。当前学期决定课表、提醒与组件显示的内容。")
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
                Text("该学期的课程、作息与调课记录都会被删除，且无法撤销。建议先导出备份。")
            }
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
        formatter.dateFormat = "yyyy.MM.dd"
        return "\(formatter.string(from: term.startDate)) – \(formatter.string(from: term.endDate)) · \(term.totalWeeks) 周"
    }

    private func createTerm() {
        let id = store.addTerm()
        store.selectTerm(id)
        if let created = store.terms.first(where: { $0.id == id }) {
            renameText = created.name
            renaming = created
        }
    }
}
