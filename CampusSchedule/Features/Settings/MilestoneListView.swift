import SwiftUI

/// 纪念事件列表：倒数日与累计日。
///
/// 完整列表只在这里出现，今日页最多展示三条置顶事件，避免挤占课程与考试信息。
struct MilestoneListView: View {
    @Environment(PreviewStore.self) private var store
    @State private var editing: Milestone?
    @State private var pendingDeletion: Milestone?
    /// 从组件或今日页摘要进来时要直接打开的事件。事件已删除时保持列表，不留下死链。
    var focusID: String? = nil
    @State private var didFocus = false

    init(focusID: String? = nil) {
        self.focusID = focusID
    }

    private var ordered: [Milestone] { store.sortedMilestones }

    var body: some View {
        List {
            if ordered.isEmpty {
                ContentUnavailableView("还没有纪念事件", systemImage: "flag",
                                       description: Text("添加毕业、生日或考试日期，今日页会按需显示倒数。"))
            } else {
                ForEach(ordered) { item in
                    Button { editing = item } label: { row(item) }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("删除", systemImage: "trash", role: .destructive) { pendingDeletion = item }
                        }
                }
            }
        }
        .navigationTitle("纪念事件")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("添加", systemImage: "plus") { editing = Milestone(title: "", date: store.now) }
                    .accessibilityIdentifier("milestone.add")
            }
        }
        .sheet(item: $editing) { item in
            MilestoneEditorView(milestone: item) { updated in
                save(updated)
                editing = nil
            } onCancel: { editing = nil }
            .id(item.id)
            .environment(store)
        }
        .confirmationDialog("删除这个纪念事件？", isPresented: .init(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), presenting: pendingDeletion) { item in
            Button("删除", role: .destructive) {
                store.milestones.removeAll { $0.id == item.id }
                pendingDeletion = nil
            }
            Button("取消", role: .cancel) { pendingDeletion = nil }
        } message: { item in
            Text("「\(item.title)」及其提醒会一起移除。")
        }
        .task {
            if store.isPreview && ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_SHEET"] == "milestone-editor" {
                editing = Milestone(title: "", date: store.now,
                                    category: .graduation, reminderDaysBefore: 7,
                                    repeatsAnnually: false)
                return
            }
            // 只处理一次：关掉编辑页后不要又自动弹开。
            guard !didFocus else { return }
            didFocus = true
            if let focusID, let item = store.milestones.first(where: { $0.id == focusID }) {
                editing = item
            }
        }
    }

    private func row(_ item: Milestone) -> some View {
        let reading = MilestoneCounter.read(item, now: store.now)
        let hidden = reading.isHidden(expiry: item.expiry)
        return HStack(spacing: 14) {
            Image(systemName: item.category.symbol)
                .font(.title3)
                .frame(width: 30)
                .foregroundStyle(hidden ? Color.secondary : Color.primary)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(item.title.isEmpty ? "未命名" : item.title)
                        .foregroundStyle(hidden ? .secondary : .primary)
                        .lineLimit(1)
                    if item.pinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.tertiary) }
                    if item.repeatsAnnually { Image(systemName: "repeat").font(.caption2).foregroundStyle(.tertiary) }
                }
                Text(subtitle(item, reading: reading))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(MilestoneFormat.primary(item, reading: reading))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(hidden ? .tertiary : .primary)
        }
        .contentShape(Rectangle())
    }

    private func subtitle(_ item: Milestone, reading: MilestoneReading) -> String {
        let date = MilestoneFormat.dateText(reading.effectiveDate)
        if reading.isHidden(expiry: item.expiry) {
            return "已归档 · \(date)"
        }
        var parts = [date]
        if item.reminderDaysBefore > 0 { parts.append("提前 \(item.reminderDaysBefore) 天提醒") }
        return parts.joined(separator: " · ")
    }

    private func save(_ item: Milestone) {
        if let index = store.milestones.firstIndex(where: { $0.id == item.id }) {
            store.milestones[index] = item
        } else {
            store.milestones.append(item)
        }
    }
}

/// 纪念事件的展示文案统一放在 `Shared/MilestoneFormat.swift`：App 与组件共用同一套写法。

/// 新增或编辑一个纪念事件。
struct MilestoneEditorView: View {
    @Environment(PreviewStore.self) private var store
    @State private var draft: Milestone
    @State private var errorText: String?
    let onSave: (Milestone) -> Void
    let onCancel: () -> Void

    init(milestone: Milestone, onSave: @escaping (Milestone) -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: milestone)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    /// 提前提醒的可选天数。太长的提前量在纪念日上没有意义。
    private static let reminderChoices = [0, 1, 3, 7, 14, 30]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称", text: $draft.title)
                        .accessibilityIdentifier("milestone.title")
                    DatePicker("日期", selection: $draft.date, displayedComponents: .date)
                    Picker("方向", selection: $draft.direction) {
                        ForEach(Milestone.Direction.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("分类", selection: $draft.category) {
                        ForEach(Milestone.Category.allCases, id: \.self) { category in
                            Label(category.title, systemImage: category.symbol).tag(category)
                        }
                    }
                } header: { Text("基本信息") }
                footer: { Text(countingHint) }

                Section {
                    Toggle("置顶到今日页", isOn: $draft.pinned).tint(DesignSystem.switchTint)
                    Toggle("每年重复", isOn: $draft.repeatsAnnually).tint(DesignSystem.switchTint)
                    Picker("提前提醒", selection: $draft.reminderDaysBefore) {
                        ForEach(Self.reminderChoices, id: \.self) { days in
                            Text(days == 0 ? "不提醒" : "提前 \(days) 天").tag(days)
                        }
                    }
                } header: { Text("提醒") }
                footer: { Text("提醒在当天上午 9 点发出。每年重复的事件会自动指向下一次日期。") }

                Section {
                    Picker("过期后", selection: $draft.expiry) {
                        ForEach(Milestone.Expiry.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                } header: { Text("过期处理") }
                footer: { Text("归档只影响展示，事件仍保留在列表里可以编辑或删除。") }

                if let preview {
                    Section("今天看到的是") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(MilestoneFormat.primary(draft, reading: preview))
                                .font(.title3.weight(.semibold)).monospacedDigit()
                            Text(MilestoneFormat.sentence(draft, reading: preview))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }

                if let errorText {
                    Section { Label(errorText, systemImage: "exclamationmark.circle").foregroundStyle(.red) }
                }
            }
            .navigationTitle(draft.title.isEmpty ? "添加纪念事件" : "编辑纪念事件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { onCancel() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { attemptSave() }.fontWeight(.semibold)
                }
            }
        }
    }

    /// 计日说明。写清楚「今天算 0 天」，避免用户以为差一天。
    private var countingHint: String {
        switch draft.direction {
        case .countdown:
            return "按日历日计算，不扣小时。当天显示「就是今天」。"
        case .countUp:
            return "从这一天开始累计，当天为第 0 天，第二天显示第 1 天。"
        }
    }

    private var preview: MilestoneReading? {
        MilestoneCounter.read(draft, now: store.now)
    }

    private func attemptSave() {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorText = "请输入名称。"
            return
        }
        errorText = nil
        onSave(draft)
    }
}
