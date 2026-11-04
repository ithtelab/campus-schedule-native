import SwiftUI

/// 人物与主题。
///
/// 这一页只负责选择，不解释资源细节：未完成绘制的形象与主题会明确标注「制作中」并
/// 禁止选择，避免出现「能选但画不出来」的空壳选项。身份（学生／教师）与形象解耦，
/// 切换身份不影响已选形象。
struct AppearanceSettingsView: View {
    @Environment(PreviewStore.self) private var store
    @State private var player = CampusCharacterPlayer(style: .girl)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.campusSuppressMotion) private var suppressMotion

    var body: some View {
        @Bindable var settings = store
        Form {
            Section {
                HStack(alignment: .center, spacing: 16) {
                    CampusCharacter(player: player, contextDriven: true)
                        .frame(width: 74, height: 128)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(settings.appearance.persona.title).font(.headline)
                        Text(settings.appearance.theme.title)
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(densitySummary)
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 6)
            } footer: {
                Text("人物动作随课程状态变化：课前准备、换教室、上课、课间与当天结束。轻点人物会回应，不会修改课表。")
            }

            Section("人物形象") {
                ForEach(CampusPersona.allCases) { persona in
                    Button { select(persona) } label: {
                        row(title: persona.title,
                            detail: persona.isAvailable ? nil : "制作中",
                            selected: settings.appearance.persona == persona,
                            enabled: persona.isAvailable)
                    }
                    .buttonStyle(.plain)
                    .disabled(!persona.isAvailable)
                }
            }

            Section("主题") {
                ForEach(CampusTheme.allCases) { theme in
                    Button { settings.appearance.theme = theme } label: {
                        row(title: theme.title,
                            detail: theme.isAvailable ? nil : "制作中",
                            selected: settings.appearance.theme == theme,
                            enabled: theme.isAvailable)
                    }
                    .buttonStyle(.plain)
                    .disabled(!theme.isAvailable)
                }
            } footer: {
                Text("主题与浅色／深色是两个独立选择：在「外观」里选择跟随系统、浅色或深色。")
            }

            Section("装饰密度") {
                Picker("密度", selection: $settings.appearance.density) {
                    ForEach(DecorationDensity.allCases) { density in
                        Text(density.title).tag(density)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("关闭后不显示人物，课表与今日页仍完整可用。任何密度都不会遮挡课程名称、教室和时间。")
            }

            Section("互动效果") {
                Picker("效果", selection: $settings.appearance.effects) {
                    ForEach(InteractionEffects.allCases) { effect in
                        Text(effect.title).tag(effect)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("选择「静态」后人物只保留当前姿态，不播放过渡动作。系统开启「减弱动态效果」时同样只保留静态。")
            }
        }
        .navigationTitle("人物与主题")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { player = CampusCharacterPlayer(style: store.characterStyle) }
        .onChange(of: store.characterStyle) { _, style in
            player = CampusCharacterPlayer(style: style)
        }
        .onChange(of: store.appearance.effects, initial: true) { _, _ in synchronize(animated: true) }
        .task {
            // 预览态下没有真实课表，给一个人为上下文让动作看得出来。
            synchronize(animated: true)
        }
        .onDisappear { player.stop() }
    }

    private var densitySummary: String {
        switch store.appearance.density {
        case .off: "不显示人物"
        case .light: "少量装饰"
        case .rich: "丰富装饰"
        }
    }

    private func synchronize(animated: Bool) {
        let context = CampusScheduleContext.make(items: store.occurrences, now: store.now,
                                                leadMinutes: store.reminderMinutes)
        let motionAllowed = store.appearance.effects == .followSchedule && animated
        player.synchronize(context, animated: motionAllowed && !reduceMotion && !suppressMotion)
    }

    private func select(_ persona: CampusPersona) {
        guard persona.isAvailable else { return }
        store.appearance.persona = persona
        player = CampusCharacterPlayer(style: store.characterStyle)
        synchronize(animated: false)
    }

    private func row(title: String, detail: String?, selected: Bool, enabled: Bool) -> some View {
        HStack {
            Text(title).foregroundStyle(enabled ? .primary : .secondary)
            if let detail {
                Text(detail).font(.caption2).foregroundStyle(.tertiary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(DesignSystem.surface, in: Capsule())
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark").font(.footnote.weight(.semibold))
            }
        }
        .contentShape(Rectangle())
    }
}
