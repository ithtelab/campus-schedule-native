import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.campusSuppressMotion) private var suppressMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var player = CampusCharacterPlayer(style: .girl)
    @State private var rehearsal: Rehearsal = .reading

    private enum Rehearsal: String, CaseIterable, Identifiable {
        case reading, moving, finished

        var id: Self { self }
        var title: String {
            switch self {
            case .reading: "自习"
            case .moving: "换教室"
            case .finished: "下课后"
            }
        }
        var phase: CampusSchedulePhase {
            switch self {
            case .reading: .freeReading
            case .moving: .moving
            case .finished: .finished
            }
        }
    }

    var body: some View {
        @Bindable var settings = store
        Form {
            Section {
                stage
                    .listRowInsets(EdgeInsets())
                if store.showsCharacter {
                    Picker("动作场景", selection: $rehearsal) {
                        ForEach(Rehearsal.allCases) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("appearance.rehearsal")
                }
            }

            Section("人物形象") {
                ForEach(CampusPersona.allCases.filter(\.isAvailable)) { persona in
                    Button {
                        store.appearance.persona = persona
                    } label: {
                        HStack(spacing: 12) {
                            let style: CampusCharacterStyle = persona == .boy ? .boy : .girl
                            if let portrait = CampusCharacterAssets.image(style: style, frame: 0) {
                                Image(uiImage: portrait).resizable().scaledToFit()
                                    .frame(width: 32, height: 43)
                                    .frame(width: 48, height: 52)
                                    .background(portraitPaper, in: .rect(cornerRadius: 9))
                                    .accessibilityHidden(true)
                            }
                            Text(persona.title)
                            Spacer()
                            selectionMark(store.appearance.persona == persona)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(CampusPressStyle())
                    .accessibilityAddTraits(store.appearance.persona == persona ? .isSelected : [])
                    .accessibilityIdentifier("appearance.persona.\(persona.rawValue)")
                }
            }

            Section("主题") {
                ForEach(CampusTheme.allCases) { theme in
                    Button {
                        store.appearance.theme = theme
                    } label: {
                        HStack(spacing: 12) {
                            CampusThemeSurface(theme: theme, isSwatch: true)
                                .frame(width: 48, height: 36)
                                .clipShape(.rect(cornerRadius: 5))
                                .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(DesignSystem.rule) }
                            Text(theme.title)
                            Spacer()
                            selectionMark(store.appearance.theme == theme)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(CampusPressStyle())
                    .accessibilityAddTraits(store.appearance.theme == theme ? .isSelected : [])
                    .accessibilityIdentifier("appearance.theme.\(theme.rawValue)")
                }
            }

            Section("装饰密度") {
                Picker("装饰密度", selection: $settings.appearance.density) {
                    ForEach(DecorationDensity.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: store.showsCharacter) { _, visible in
                    if !visible { player.stop() }
                }
            }

            Section {
                Picker("互动效果", selection: $settings.appearance.effects) {
                    ForEach(InteractionEffects.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("互动效果")
            } footer: {
                Text("跟随课表时，人物会随课程变化。可以在上方预览不同场景的动作。")
            }
        }
        .foregroundStyle(.primary)
        .navigationTitle("人物与主题")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.characterStyle, initial: true) { _, style in
            player.stop()
            player = CampusCharacterPlayer(style: style)
            synchronize(animated: false)
        }
        .onChange(of: rehearsal) { _, _ in synchronize(animated: true) }
        .onDisappear { player.stop() }
        .sensoryFeedback(.selection, trigger: store.appearance)
    }

    private var stage: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 8) {
                Label("外观预览", systemImage: "viewfinder")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(store.appearance.theme.title).font(.title2.weight(.semibold))
                    .accessibilityIdentifier("appearance.preview.theme")
                Text(store.showsCharacter ? rehearsal.title : "人物已隐藏")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("appearance.preview.scene")
                if store.showsCharacter && !suppressMotion && !reduceMotion {
                    Text(responseTitle)
                        .font(.caption)
                        .accessibilityIdentifier("appearance.preview.response")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if store.showsCharacter {
                CampusCharacter(player: player, contextDriven: true, showsCaption: false)
                    .frame(width: 76, height: 108)
                    .padding(6)
                    .background(portraitPaper, in: .rect(cornerRadius: 12))
                    .accessibilityIdentifier("appearance.preview.character")
            }
        }
        .padding(18)
        .frame(minHeight: 136)
        .background { CampusThemeSurface(theme: store.appearance.theme, density: store.appearance.density) }
    }

    private var portraitPaper: Color {
        Color(white: scheme == .dark ? 0.78 : 0.95)
    }

    private func synchronize(animated: Bool) {
        player.synchronize(.init(phase: rehearsal.phase, occurrenceID: nil, room: nil),
                           animated: animated && store.showsCharacter && !reduceMotion && !suppressMotion)
    }

    private var responseTitle: String {
        if player.isBusy { return "正在\(player.lastAction?.title ?? "准备")" }
        if let action = player.lastAction { return "刚刚 · \(action.title)" }
        return "点人物试试"
    }

    private func selectionMark(_ selected: Bool) -> some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .font(.body.weight(.medium))
            .foregroundStyle(selected ? Color.primary : Color.secondary.opacity(0.55))
            .accessibilityHidden(true)
    }
}
