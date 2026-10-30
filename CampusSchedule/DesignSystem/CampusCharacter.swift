import SwiftUI
import Observation
import UIKit

enum CampusCharacterStyle: String, CaseIterable {
    case boy, girl
}

@MainActor
enum CampusCharacterAssets {
    static let boy = frames(named: "CampusBoyActions")
    static let girl: [UIImage] = {
        var original = frames(named: "CampusGirlActions")
        let corrected = frames(named: "CampusGirlStretchCorrection")
        guard original.count == 16, corrected.count == 16 else { return [] }
        // Preserve the first 15 original frames exactly; only replace the missing-cap frame.
        original[15] = corrected[15]
        return original
    }()
    static var available: Bool { boy.count == 16 && girl.count == 16 }

    private static func frames(named name: String) -> [UIImage] {
        guard let sheet = UIImage(named: name)?.cgImage else { return [] }
        return (0..<16).compactMap { index in
            let column = index % 4, row = index / 4
            let x = sheet.width * column / 4, y = sheet.height * row / 4
            let right = sheet.width * (column + 1) / 4, bottom = sheet.height * (row + 1) / 4
            guard let frame = sheet.cropping(to: CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(right - x), height: CGFloat(bottom - y))) else { return nil }
            return UIImage(cgImage: frame)
        }
    }

    static func image(style: CampusCharacterStyle, frame: Int) -> UIImage? {
        let atlas = style == .boy ? boy : girl
        return atlas.indices.contains(frame) ? atlas[frame] : nil
    }
}

@MainActor @Observable
final class CampusCharacterPlayer {
    let style: CampusCharacterStyle
    private(set) var state: CampusCharacterState
    private(set) var frame: Int
    private(set) var isPlaying = false
    private(set) var lastAction: CampusCharacterAction?
    private(set) var playedFrames: [Int] = []
    @ObservationIgnored private var playback: Task<Void, Never>?
    @ObservationIgnored private var activeID: UUID?

    init(style: CampusCharacterStyle, state: CampusCharacterState = .seatedReading, frame: Int? = nil) {
        self.style = style; self.state = state; self.frame = frame ?? state.frame
    }

    var suggestedAction: CampusCharacterAction {
        switch state {
        case .seatedReading: .stand
        case .seatedEmpty: .pickUpBook
        case .standingReading: .putDownBook
        case .standingEmpty: lastAction == .stand ? .pickUpBook : lastAction == .walk ? .sit : .walk
        }
    }

    func canPerform(_ action: CampusCharacterAction) -> Bool {
        !CampusAnimationPlan.make(action, from: state).frames.isEmpty
    }

    func request(_ action: CampusCharacterAction, reducedMotion: Bool) {
        guard !isPlaying else { return }
        playback = Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await self.play(action, reducedMotion: reducedMotion)
        }
    }

    @discardableResult
    func play(_ action: CampusCharacterAction, reducedMotion: Bool = false) async -> Bool {
        guard !isPlaying else { return false }
        let plan = CampusAnimationPlan.make(action, from: state)
        guard !plan.frames.isEmpty else { return false }
        let token = UUID()
        activeID = token; isPlaying = true; lastAction = action; playedFrames = []
        defer { if activeID == token { activeID = nil; isPlaying = false } }
        if reducedMotion {
            state = plan.destination; frame = state.frame
            return true
        }
        do {
            for next in plan.frames {
                try Task.checkCancellation()
                guard activeID == token else { return false }
                frame = next; playedFrames.append(next)
                try await Task.sleep(for: .seconds(plan.frameSeconds))
            }
            guard activeID == token else { return false }
            state = plan.destination; frame = state.frame
            return true
        } catch {
            if activeID == token { frame = state.frame }
            return false
        }
    }

    func stop() {
        playback?.cancel(); playback = nil; activeID = nil
        frame = state.frame; isPlaying = false
    }
}

struct CampusCharacter: View {
    let player: CampusCharacterPlayer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.campusSuppressMotion) private var suppressMotion
    @Environment(\.scenePhase) private var phase
    @State private var feedback = 0

    var body: some View {
        Menu {
            ForEach(CampusCharacterAction.allCases.filter { $0 != .prepareCourse }, id: \.self) { action in
                Button(action.title) { perform(action) }.disabled(player.isPlaying || !player.canPerform(action))
            }
        } label: {
            VStack(spacing: 3) {
                if let image = CampusCharacterAssets.image(style: player.style, frame: player.frame) {
                    Image(uiImage: image).resizable().scaledToFit().accessibilityHidden(true)
                }
                Text(player.isPlaying ? player.lastAction?.title ?? "" : "点人物 · \(player.suggestedAction.title)")
                    .font(.system(size: 9)).lineLimit(2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        } primaryAction: {
            perform(player.suggestedAction)
        }
        .buttonStyle(CampusPressStyle())
        .sensoryFeedback(.selection, trigger: feedback)
        .accessibilityLabel("校园人物，\(player.isPlaying ? player.lastAction?.title ?? "动作中" : player.suggestedAction.title)")
        .accessibilityHint("轻点触发动作，长按选择站起、坐下、拿书、放书或行走")
        .onChange(of: phase) { _, value in if value != .active { player.stop() } }
    }

    private func perform(_ action: CampusCharacterAction) {
        guard !player.isPlaying else { return }
        feedback += 1
        player.request(action, reducedMotion: reduceMotion || suppressMotion)
    }
}

struct CampusPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.13), value: configuration.isPressed)
    }
}
