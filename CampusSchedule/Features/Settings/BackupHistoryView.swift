import SwiftUI

struct BackupHistoryView: View {
    @Environment(PreviewStore.self) private var store
    @State private var backups: [LocalPersistence.Backup] = []
    @State private var pending: ArchivedSemester?
    @State private var message: String?

    var body: some View {
        List {
            ForEach(backups) { backup in
                Section {
                    ForEach(backup.archive.semesters, id: \.id) { term in
                        Button { pending = term } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(term.name).foregroundStyle(.primary)
                                Text("\(term.courses.count) 门课 · \(term.exams.count) 场考试 · \(term.courseTasks.count) 条待办")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .disabled(store.storageReadOnly)
                    }
                } header: {
                    Text(backup.savedAt, format: .dateTime.year().month().day().hour().minute())
                }
            }
        }
        .overlay {
            if backups.isEmpty {
                ContentUnavailableView("还没有历史备份", systemImage: "clock.arrow.circlepath",
                                       description: Text("导入、删除学期等操作前会保存本机副本。"))
            }
        }
        .navigationTitle("备份记录")
        .task { reload() }
        .confirmationDialog("恢复此学期？", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            titleVisibility: .visible, presenting: pending) { term in
            let replacesExisting = store.termContents[term.id] != nil
            Button(replacesExisting ? "替换此学期" : "恢复此学期", role: replacesExisting ? .destructive : nil) {
                do {
                    try store.restoreSemester(term)
                    reload()
                    message = "已恢复「\(term.name)」。"
                } catch { message = error.localizedDescription }
                pending = nil
            }
            Button("取消", role: .cancel) { pending = nil }
        } message: { term in
            Text("恢复「\(term.name)」的课程、作息、考试、调停课和待办。系统会先备份本机课表。")
        }
        .alert("备份记录", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    private func reload() {
        do { backups = try store.recentBackups() }
        catch { message = error.localizedDescription }
    }
}
