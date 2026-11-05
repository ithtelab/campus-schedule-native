import SwiftUI

/// 纪念事件列表：倒数日与累计日。
///
/// 完整列表只在这里出现，今日页最多展示三条置顶事件，避免挤占课程与考试信息。
struct MilestoneListView: View {
    @Environment(PreviewStore.self) private var store
    @State private var editing: Milestone?
    @State private var pendingDeletion: Milestone?

    private var ordered: [Milestone] { store.sortedMilestones }

    var body: some View {
        List {
            if ordered.isEmpty {
                ContentUnavailableView("还没有纪念事件", systemImage: "flag",
                                       description: Text("记下恋爱、生日或毕业的日期，把想常看的日子置顶。"))
            } else {
                ForEach(ordered) { item in
                    NavigationLink {
                        MilestoneDetailView(id: item.id)
                    } label: { row(item) }
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
                Menu {
                    Button("自定义事件", systemImage: "calendar.badge.plus") {
                        editing = Milestone(title: "", date: store.now)
                    }
                    Button("恋爱日", systemImage: "heart.circle") {
                        editing = Milestone(title: "我们的恋爱日", date: store.now,
                                            direction: .countUp, category: .relationship)
                    }
                    .accessibilityIdentifier("milestone.template.relationship")
                } label: {
                    Label("添加", systemImage: "plus")
                }
                .accessibilityIdentifier("milestone.add")
            }
        }
        .sheet(item: $editing) { item in
            MilestoneEditorView(milestone: item, isNew: true) { updated in
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
        }
    }

    private func row(_ item: Milestone) -> some View {
        let reading = MilestoneCounter.read(item, now: store.now)
        let hidden = reading.isHidden(expiry: item.expiry)
        return HStack(spacing: 14) {
            Image(systemName: item.category.symbol)
                .font(.body.weight(.medium))
                .frame(width: 36, height: 36)
                .background(DesignSystem.surface, in: .rect(cornerRadius: 9))
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

struct MilestoneDetailView: View {
    let id: String
    @Environment(PreviewStore.self) private var store
    @State private var editing: Milestone?

    var body: some View {
        Group {
            if let item = store.milestones.first(where: { $0.id == id }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        MilestoneDateCard(item: item, now: store.now, interactive: true)
                        VStack(alignment: .leading, spacing: 12) {
                            Label(item.repeatsAnnually ? "每年重复" : "单次事件", systemImage: "repeat")
                            Label(item.reminderDaysBefore > 0 ? "提前 \(item.reminderDaysBefore) 天提醒" : "未设置提醒",
                                  systemImage: "bell")
                        }
                        .font(.subheadline).foregroundStyle(.secondary)

                        if !MilestoneCounter.read(item, now: store.now).isHidden(expiry: item.expiry) {
                            Button {
                                if let index = store.milestones.firstIndex(where: { $0.id == id }) {
                                    store.milestones[index].pinned.toggle()
                                }
                            } label: {
                                Label(item.pinned ? "取消置顶" : "置顶到今日页", systemImage: item.pinned ? "pin.slash" : "pin")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("milestone.pin")
                            .sensoryFeedback(.selection, trigger: item.pinned)
                        }
                    }
                    .padding(20)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("编辑") { editing = item }
                    }
                }
            } else {
                ContentUnavailableView("事件已移除", systemImage: "calendar.badge.exclamationmark")
            }
        }
        .navigationTitle("纪念事件")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { item in
            MilestoneEditorView(milestone: item) { updated in
                if let index = store.milestones.firstIndex(where: { $0.id == id }) {
                    store.milestones[index] = updated
                }
                editing = nil
            } onCancel: { editing = nil }
        }
    }
}

private struct MilestoneDateCard: View {
    let item: Milestone
    let now: Date
    var interactive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize = 56.0
    @State private var heartTaps = 0

    var body: some View {
        let reading = MilestoneCounter.read(item, now: now)
        VStack(alignment: .leading, spacing: 10) {
            Label(item.category.title, systemImage: item.category.symbol)
                .font(.footnote.weight(.medium)).foregroundStyle(.secondary)
            Text(item.title.isEmpty ? "未命名事件" : item.title)
                .font(.title2.weight(.semibold))
            if let caption = MilestoneFormat.counterCaption(item, reading: reading) {
                Text(caption).font(.subheadline.weight(.medium))
            }
            HStack(spacing: 16) {
                Text(MilestoneFormat.number(reading))
                    .font(.system(size: min(numberSize, 92), weight: .bold, design: .monospaced))
                    .lineLimit(1).minimumScaleFactor(0.45)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("milestone.counter")
                Spacer(minLength: 0)
                if item.category == .relationship && interactive {
                    heartButton
                } else if item.category == .relationship && !typeSize.isAccessibilitySize {
                    heartStamp.accessibilityHidden(true)
                } else if !typeSize.isAccessibilitySize {
                    Image(systemName: item.category.symbol)
                        .font(.system(size: 30, weight: .light))
                        .frame(width: 64, height: 64)
                        .overlay { Circle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [2, 3])) }
                        .rotationEffect(.degrees(-12))
                        .foregroundStyle(Color.primary.opacity(0.42))
                        .accessibilityHidden(true)
                }
            }
            Divider()
            Text(MilestoneFormat.dateText(reading.effectiveDate, relativeTo: now))
                .font(.footnote).foregroundStyle(.secondary)
            if let highlight = MilestoneFormat.relationshipHighlight(item, reading: reading) {
                Label(highlight, systemImage: "sparkle")
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(DesignSystem.surface, in: .rect(cornerRadius: 8))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.paper, in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(DesignSystem.rule) }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: reading.state)
    }

    private var heartButton: some View {
        Button { heartTaps += 1 } label: {
            VStack(spacing: 4) {
                heartStamp
                Text(heartTaps == 0 ? "比个心" : "收到啦")
                    .font(.caption2.weight(.medium))
            }
        }
        .buttonStyle(CampusPressStyle())
        .sensoryFeedback(.selection, trigger: heartTaps)
        .accessibilityLabel("比个心")
        .accessibilityValue(heartTaps == 0 ? "" : "收到啦")
        .accessibilityIdentifier("milestone.heart")
    }

    private var heartStamp: some View {
        ZStack {
            Circle().strokeBorder(DesignSystem.rule, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            Image(systemName: "heart")
                .font(.system(size: 23, weight: .medium))
                .rotationEffect(.degrees(-16))
                .offset(x: -9, y: 5)
            Image(systemName: heartTaps == 0 ? "heart" : "heart.fill")
                .font(.system(size: 17, weight: .medium))
                .rotationEffect(.degrees(16))
                .offset(x: 11, y: -9)
                .symbolEffect(.bounce, value: reduceMotion ? 0 : heartTaps)
        }
        .frame(width: 58, height: 58)
        .accessibilityHidden(true)
    }
}

/// 纪念事件的展示文案统一放在 `Shared/MilestoneFormat.swift`：App 与组件共用同一套写法。

/// 新增或编辑一个纪念事件。
struct MilestoneEditorView: View {
    @Environment(PreviewStore.self) private var store
    @State private var draft: Milestone
    @State private var errorText: String?
    @State private var checkingPermission = false
    @State private var notificationUnavailable = false
    private let isNew: Bool
    let onSave: (Milestone) -> Void
    let onCancel: () -> Void

    init(milestone: Milestone, isNew: Bool = false, onSave: @escaping (Milestone) -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: milestone)
        self.isNew = isNew
        self.onSave = onSave
        self.onCancel = onCancel
    }

    /// 提前提醒的可选天数。太长的提前量在纪念日上没有意义。
    private static let reminderChoices = [0, 1, 3, 7, 14, 30]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MilestoneDateCard(item: draft, now: store.now)
                        .listRowInsets(EdgeInsets())
                }
                Section {
                    TextField("名称", text: $draft.title)
                        .accessibilityIdentifier("milestone.title")
                    DatePicker(draft.countsRelationshipDays ? "在一起的日期" : "日期", selection: $draft.date, displayedComponents: .date)
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

                if let errorText {
                    Section { Label(errorText, systemImage: "exclamationmark.circle").foregroundStyle(.red) }
                }
            }
            .navigationTitle(isNew ? "添加纪念事件" : "编辑纪念事件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { onCancel() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { Task { await attemptSave() } }
                        .fontWeight(.semibold).disabled(checkingPermission)
                }
            }
            .alert("通知权限未开启", isPresented: $notificationUnavailable) {
                Button("仍然保存") { onSave(draft) }
                Button("返回修改", role: .cancel) {}
            } message: {
                Text("允许「课间册」发送通知后，纪念事件提醒才会生效。")
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

    private func attemptSave() async {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            errorText = "请输入名称。"
            return
        }
        errorText = nil
        draft.title = title
        if draft.reminderDaysBefore > 0 && !store.isPreview {
            checkingPermission = true
            defer { checkingPermission = false }
            do {
                guard try await CourseNotifications.shared.authorize() else {
                    notificationUnavailable = true
                    return
                }
            } catch {
                errorText = "无法检查通知权限：\(error.localizedDescription)"
                return
            }
        }
        onSave(draft)
    }
}
