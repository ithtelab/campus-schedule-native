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
    private(set) var context: CampusScheduleContext?
    private(set) var isCoordinating = false
    var isBusy: Bool { isPlaying || isCoordinating }
    @ObservationIgnored private var playback: Task<Void, Never>?
    @ObservationIgnored private var activeID: UUID?
    @ObservationIgnored private var flow: Task<Void, Never>?
    @ObservationIgnored private var flowID: UUID?

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
        guard !isBusy else { return }
        playback = Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await self.play(action, reducedMotion: reducedMotion)
        }
    }

    /// The timetable owns the stable pose. Opening the app never replays missed transitions.
    func synchronize(_ value: CampusScheduleContext, animated: Bool) {
        guard context != value else { return }
        let initial = context == nil
        stop()
        context = value
        if initial || !animated {
            state = value.stableState; frame = state.frame
        } else {
            startFlow(value, response: false, reducedMotion: false)
        }
    }

    func respondToContext(reducedMotion: Bool) {
        guard let context, !isBusy else { return }
        startFlow(context, response: true, reducedMotion: reducedMotion)
    }

    private func startFlow(_ value: CampusScheduleContext, response: Bool, reducedMotion: Bool) {
        if reducedMotion {
            state = value.stableState; frame = state.frame
            return
        }
        let token = UUID()
        flowID = token; isCoordinating = true
        flow = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if self.flowID == token { self.flowID = nil; self.isCoordinating = false } }
            var actions: [CampusCharacterAction] = []
            if response { actions.append(value.response) }
            else if value.phase == .moving { actions.append(.walk) }
            else if value.phase == .preparing { actions.append(.prepareCourse) }
            else if value.phase == .finished { actions.append(.stretch) }
            var predicted = self.state
            for action in actions { predicted = CampusAnimationPlan.make(action, from: predicted).destination }
            if predicted.isSeated != value.stableState.isSeated {
                let action: CampusCharacterAction = value.stableState.isSeated ? .sit : .stand
                actions.append(action); predicted = CampusAnimationPlan.make(action, from: predicted).destination
            }
            if predicted.hasBook != value.stableState.hasBook {
                actions.append(value.stableState.hasBook ? .pickUpBook : .putDownBook)
            }
            for action in actions {
                guard !Task.isCancelled, self.flowID == token else { return }
                if self.canPerform(action) { guard await self.play(action) else { return } }
            }
            guard !Task.isCancelled, self.flowID == token else { return }
            self.state = value.stableState; self.frame = self.state.frame
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
        flow?.cancel(); flow = nil; flowID = nil; isCoordinating = false
        playback?.cancel(); playback = nil; activeID = nil
        if let context { state = context.stableState }
        frame = state.frame; isPlaying = false
    }
}

struct CampusCharacter: View {
    let player: CampusCharacterPlayer
    var contextDriven = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.campusSuppressMotion) private var suppressMotion
    @Environment(\.scenePhase) private var phase
    @State private var feedback = 0

    var body: some View {
        Group {
        if contextDriven {
            Button {
                guard !player.isBusy else { return }
                feedback += 1
                player.respondToContext(reducedMotion: reduceMotion || suppressMotion)
            } label: { artwork }
            .accessibilityHint("动作随当前课表变化，轻点回应")
        } else {
        Menu {
            ForEach(CampusCharacterAction.allCases.filter { $0 != .prepareCourse }, id: \.self) { action in
                Button(action.title) { perform(action) }.disabled(player.isPlaying || !player.canPerform(action))
            }
        } label: {
            artwork
        } primaryAction: {
            perform(player.suggestedAction)
        }
        .accessibilityHint("内部动作验证：轻点触发动作，长按选择")
        }
        }
        .buttonStyle(CampusPressStyle())
        .sensoryFeedback(.selection, trigger: feedback)
        .accessibilityLabel("校园人物，\(caption)")
        .onChange(of: phase) { _, value in if value != .active { player.stop() } }
    }

    private var caption: String {
        if contextDriven { return player.context?.interactionTitle ?? "校园日常" }
        return player.isPlaying ? player.lastAction?.title ?? "" : "点人物 · \(player.suggestedAction.title)"
    }

    private var artwork: some View {
        VStack(spacing: 3) {
            if let image = CampusCharacterAssets.image(style: player.style, frame: player.frame) {
                Image(uiImage: image).resizable().scaledToFit().accessibilityHidden(true)
            }
            Text(caption).font(.system(size: 9)).lineLimit(2).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
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
