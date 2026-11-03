import SwiftUI

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
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
