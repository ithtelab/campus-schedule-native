import SwiftUI

/// The sticker cluster fits beside the existing Today heading and does not take up a row.
struct CampusBlueStickers: View {
    static let blue = Color(red: 0.24, green: 0.36, blue: 0.88)
    static let width: CGFloat = 108
    static let compactWidth: CGFloat = 68

    var compact = false
    var showsSun = false
    var interactive = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.campusSuppressMotion) private var suppressMotion
    @Environment(\.colorScheme) private var scheme
    @GestureState private var drag: CGSize = .zero
    @State private var restingOffset: CGSize = .zero
    @State private var taps = 0

    private let ink = Color(red: 0.15, green: 0.21, blue: 0.53)
    private let paper = Color(red: 1, green: 0.98, blue: 0.92)

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 10)
                .fill(scheme == .dark ? Color(red: 0.18, green: 0.24, blue: 0.60) : Self.blue)
                .frame(height: 31)
                .rotationEffect(.degrees(-4))
                .padding(.horizontal, 4)
                .accessibilityHidden(true)
                .allowsHitTesting(false)

            campusCard
                .rotationEffect(.degrees(-13))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, compact ? 6 : 9)
                .accessibilityHidden(true)
                .allowsHitTesting(false)

            if showsSun && !compact {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ink)
                    .padding(3)
                    .background(Color(red: 1, green: 0.79, blue: 0.27), in: Circle())
                    .overlay { Circle().strokeBorder(paper, lineWidth: 1.5) }
                    .rotationEffect(.degrees(9))
                    .offset(x: -44, y: -11)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }

            if interactive && !reduceMotion && !suppressMotion {
                Button {
                    taps += 1
                } label: {
                    plane
                        .keyframeAnimator(initialValue: CGFloat.zero, trigger: taps) { content, lift in
                            content.offset(y: lift)
                        } keyframes: { _ in
                            CubicKeyframe(CGFloat(-5), duration: 0.11)
                            SpringKeyframe(CGFloat.zero, duration: 0.27)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(planeOffset(with: drag))
                .rotationEffect(.degrees(drag == .zero ? 0 : 12))
                .scaleEffect(drag == .zero ? 1 : 1.12)
                .animation(.spring(duration: 0.28), value: drag == .zero)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 5)
                        .updating($drag) { value, translation, _ in translation = value.translation }
                        .onEnded { restingOffset = planeOffset(with: $0.translation) }
                )
                .accessibilityLabel("纸飞机贴纸")
                .accessibilityHint("轻点让贴纸弹起")
                .accessibilityIdentifier("today.blue-sticker")
            } else {
                plane.frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: compact ? Self.compactWidth : Self.width, height: 44)
        .clipped()
    }

    private var campusCard: some View {
        HStack(spacing: 3) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 10, weight: .medium))
            VStack(alignment: .leading, spacing: 2) {
                Capsule().frame(width: 8, height: 1.5)
                Capsule().frame(width: 5, height: 1.5)
            }
        }
        .foregroundStyle(ink)
        .frame(width: 30, height: 21)
        .background(Color(red: 0.72, green: 0.79, blue: 1), in: .rect(cornerRadius: 4))
        .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(paper, lineWidth: 2) }
        .shadow(color: ink.opacity(0.25), radius: 1, y: 1)
    }

    private var plane: some View {
        Image(systemName: "paperplane.fill")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(ink)
            .background {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 29, weight: .black))
                    .foregroundStyle(paper)
                    .shadow(color: ink.opacity(0.35), radius: 1, y: 1)
            }
            .rotationEffect(.degrees(7))
    }

    private func planeOffset(with translation: CGSize) -> CGSize {
        CGSize(width: min(5, max(compact ? -3 : -22, restingOffset.width + translation.width)),
               height: min(4, max(-4, restingOffset.height + translation.height)))
    }
}
