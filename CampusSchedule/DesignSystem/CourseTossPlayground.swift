import SwiftUI
import Observation

@MainActor @Observable final class CourseTossReaction {
    static let prefix = "campus-toss:"
    private(set) var count = 0
    private(set) var title = ""
    private(set) var isDragging = false
    @available(iOS 26.0, *)
    func update(phase: DragSession.Phase) {
        switch phase {
        // Keep the destination alive while the system commits the drop.
        case .initial, .active, .ending(_): isDragging = true
        case .ended(_), .dataTransferCompleted: isDragging = false
        @unknown default: isDragging = false
        }
    }
    func dismiss() { isDragging = false }
    static func payload(_ course: DemoCourse) -> String { prefix + course.id }
    @discardableResult func accept(_ payloads: [String], courses: [DemoCourse]) -> Bool {
        guard let payload = payloads.first, payload.hasPrefix(Self.prefix),
              let course = courses.first(where: { $0.id == String(payload.dropFirst(Self.prefix.count)) }) else { return false }
        title = course.title; count += 1
        return true
    }
}

private struct CourseTossSource: ViewModifier {
    let course: DemoCourse
    let courses: [DemoCourse]
    let reaction: CourseTossReaction
    func body(content: Content) -> some View {
        content.draggable(CourseTossReaction.payload(course))
            .modifier(CourseTossDragTracking(reaction: reaction))
            .accessibilityAction(named: "扔个纸团，保留课程") {
                reaction.accept([CourseTossReaction.payload(course)], courses: courses)
            }
    }
}

// DragSession and onDragSessionUpdated arrive in iOS 26. Below that the dock still
// appears through the drop destination's targeted state instead of a live session.
private struct CourseTossDragTracking: ViewModifier {
    let reaction: CourseTossReaction
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.onDragSessionUpdated { reaction.update(phase: $0.phase) }
        } else {
            content
        }
    }
}

private struct CourseTossOverlay: ViewModifier {
    let courses: [DemoCourse]
    let reaction: CourseTossReaction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    // Without DragSession the dock cannot react to a drag starting, so it stays
    // available whenever a course can be dragged.
    private var dockVisible: Bool {
        if #available(iOS 26.0, *) { reaction.isDragging }
        else { !courses.isEmpty }
    }
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if dockVisible {
                CourseTossDock(courses: courses, reaction: reaction)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(DesignSystem.rule, lineWidth: 0.75) }
                    .padding(.horizontal, 16).padding(.bottom, 8)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: reaction.isDragging)
        .onDisappear { reaction.dismiss() }
        .onChange(of: scenePhase) { _, value in if value != .active { reaction.dismiss() } }
        .task {
            // Isolated screenshot state, never enabled in a normal launch.
            if #available(iOS 26.0, *), ProcessInfo.processInfo.environment["CAMPUS_TOSS_PREVIEW"] == "1" {
                reaction.update(phase: .active)
            }
        }
    }
}

extension View {
    func courseTossSource(_ course: DemoCourse, courses: [DemoCourse], reaction: CourseTossReaction) -> some View {
        modifier(CourseTossSource(course: course, courses: courses, reaction: reaction))
    }
    func courseTossOverlay(courses: [DemoCourse], reaction: CourseTossReaction) -> some View {
        modifier(CourseTossOverlay(courses: courses, reaction: reaction))
    }
}

struct CourseTossDock: View {
    let courses: [DemoCourse]
    let reaction: CourseTossReaction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var targeted = false
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(reaction.count == 0 ? "不喜欢？扔个纸团。" : "\(reaction.title) · 扔掉烦恼")
                    .font(.caption.weight(.medium)).lineLimit(1)
                Text("拖到纸篓里，课程照常保留").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(targeted ? Color.primary : Color.primary.opacity(0.045))
                Image(systemName: "trash").font(.system(size: 25, weight: .regular))
                    .rotationEffect(.degrees(targeted ? -7 : 3))
                    .foregroundStyle(targeted ? Color(uiColor: .systemBackground) : Color.primary)
                if !reduceMotion {
                    Image(systemName: "doc.fill").font(.caption)
                        .phaseAnimator([0, 1, 2], trigger: reaction.count) { content, phase in
                            content.opacity(phase == 1 ? 1 : 0)
                                .offset(y: phase == 0 ? -30 : phase == 1 ? -15 : 8)
                                .scaleEffect(phase == 2 ? 0.3 : 1).rotationEffect(.degrees(Double(phase) * 17))
                        } animation: { _ in .easeIn(duration: 0.18) }
                }
            }
            .frame(width: 58, height: 50)
            .scaleEffect(targeted && !reduceMotion ? 1.08 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25), value: targeted)
            .dropDestination(for: String.self) { payloads, _ in reaction.accept(payloads, courses: courses) }
                isTargeted: { targeted = $0 }
            .accessibilityLabel("纸篓，只播放互动，保留课程")
        }
        .padding(.horizontal, 20).padding(.vertical, 6)
        .background(DesignSystem.paper)
        .sensoryFeedback(.success, trigger: reaction.count)
    }
}
