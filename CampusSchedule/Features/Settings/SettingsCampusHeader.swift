import SwiftUI

/// 信息和人物各占一侧；沿用全 App 的黑白手绘语言。
struct SettingsCampusHeader: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.campusSuppressMotion) private var suppressMotion
    @State private var character = CampusCharacterPlayer(style: .girl)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let now = store.isPreview ? store.now : timeline.date
            let items = store.occurrences
            let context = CampusScheduleContext.make(items: items, now: now, leadMinutes: store.reminderMinutes)
            let week = ScheduleRules.week(on: now, semesterStart: store.semesterStart)
            let remaining = items.filter { ScheduleRules.calendar.isDate($0.start, inSameDayAs: now) && $0.end > now }.count
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    CampusHeading(title: "校园日常",
                                  underline: store.appearance.theme == .blueStickers ? CampusStickerMark.accent : .primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.semesterName).font(.subheadline.weight(.medium)).lineLimit(2)
                        if (1...max(1, store.totalWeeks)).contains(week) {
                            Text("第 \(week) 周").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text(remaining == 0 ? "今天的时间，留给自己" : "今天还有 \(remaining) 节课")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !typeSize.isAccessibilitySize && store.showsCharacter {
                    CampusCharacter(player: character, contextDriven: true)
                        .frame(width: 82, height: 132)
                        .background {
                            CampusPortraitDecor(appearance: store.appearance)
                        }
                }
            }
            .padding(12)
            .background {
                CampusThemeSurface(theme: store.appearance.theme, density: store.appearance.density)
                    .clipShape(.rect(cornerRadius: 12))
            }
            .onChange(of: store.characterStyle, initial: true) { _, style in
                if character.style != style {
                    character.stop()
                    character = CampusCharacterPlayer(style: style)
                }
                character.synchronize(context, animated: false)
            }
            .onChange(of: context, initial: true) { _, value in
                let follows = store.appearance.effects == .followSchedule
                character.synchronize(value, animated: store.showsCharacter && follows && !reduceMotion && !suppressMotion)
            }
        }
        .onDisappear { character.stop() }
    }
}
