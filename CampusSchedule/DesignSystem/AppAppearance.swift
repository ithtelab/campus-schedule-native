import SwiftUI
import UIKit

enum AppAppearance: String, CaseIterable, Identifiable, Hashable {
    case system, light, dark

    static let storageKey = "appAppearance"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Apply the preference to the hosting window so sheets and native controls inherit it.
struct AppAppearanceHost: UIViewRepresentable {
    let appearance: AppAppearance

    func makeUIView(context: Context) -> StyleView {
        let view = StyleView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        return view
    }

    func updateUIView(_ view: StyleView, context: Context) {
        view.style = appearance.interfaceStyle
        view.applyStyle()
    }

    final class StyleView: UIView {
        var style: UIUserInterfaceStyle = .unspecified

        override func didMoveToWindow() {
            super.didMoveToWindow()
            applyStyle()
        }

        func applyStyle() {
            Task { @MainActor [weak self] in
                guard let self, let window, window.overrideUserInterfaceStyle != style else { return }
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
