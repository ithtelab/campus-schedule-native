import Foundation

/// 人物形象。
///
/// 身份（学生／教师）与形象不绑定：教师也能选学生形象，反之亦然。
/// 只有已经绘制完整姿态的角色才可选用，其余标记为制作中，避免出现
/// 「能选但画不出来」的空壳选项。
public enum CampusPersona: String, Codable, Sendable, CaseIterable, Identifiable {
    case girl
    case boy
    case teacher
    case cat

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .girl: "棒球帽女生"
        case .boy: "耳机男生"
        case .teacher: "手持讲义的教师"
        case .cat: "校园小猫"
        }
    }

    /// 当前版本是否已经具备完整姿态资源。
    public var isAvailable: Bool {
        switch self {
        case .girl, .boy: true
        case .teacher, .cat: false
        }
    }

    /// 缺省形象。与历史版本的行为一致，老用户升级后画面不跳变。
    public static var fallback: CampusPersona { .girl }
}

/// 视觉主题。
///
/// 主题与浅色／深色是两个独立选择：先选主题，再选跟随系统／浅色／深色。
/// 首版只有「简洁纸面」具备完整令牌，其余两项先保留选择位，资源补齐后
/// 只需在这里补上令牌映射，不必改业务页面。
public enum CampusTheme: String, Codable, Sendable, CaseIterable, Identifiable {
    case paper
    case notebook
    case chalkboard

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .paper: "简洁纸面"
        case .notebook: "校园手账"
        case .chalkboard: "黑板笔记"
        }
    }

    public var isAvailable: Bool {
        switch self {
        case .paper: true
        case .notebook, .chalkboard: false
        }
    }

    public static var fallback: CampusTheme { .paper }
}

/// 装饰密度。任何密度下都不遮挡课程名、教室、时间与按钮。
public enum DecorationDensity: String, Codable, Sendable, CaseIterable, Identifiable {
    case off
    case light
    case rich

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .off: "关闭"
        case .light: "少量"
        case .rich: "丰富"
        }
    }

    /// 是否显示人物。
    public var showsCharacter: Bool { self != .off }
    /// 是否显示今日页底部的统计摘要。它是信息而不是装饰，但丰富模式才显示更克制。
    public var showsStats: Bool { self == .rich }
}

/// 互动效果：静态或跟随课表。
public enum InteractionEffects: String, Codable, Sendable, CaseIterable, Identifiable {
    case followSchedule
    case staticOnly

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .followSchedule: "跟随课表"
        case .staticOnly: "静态"
        }
    }
}

/// 外观偏好。不随切换学期丢失。
public struct AppearancePreferences: Codable, Equatable, Sendable {
    public var persona: CampusPersona
    public var theme: CampusTheme
    public var density: DecorationDensity
    public var effects: InteractionEffects

    public init(persona: CampusPersona = .fallback,
                theme: CampusTheme = .fallback,
                density: DecorationDensity = .light,
                effects: InteractionEffects = .followSchedule) {
        self.persona = persona
        self.theme = theme
        self.density = density
        self.effects = effects
    }

    /// 逐字段容错解码：新增字段或未来枚举值不会让整套外观偏好失效，
    /// 只会退回该字段的默认值。
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        persona = (try? container.decode(CampusPersona.self, forKey: .persona)) ?? .fallback
        theme = (try? container.decode(CampusTheme.self, forKey: .theme)) ?? .fallback
        density = (try? container.decode(DecorationDensity.self, forKey: .density)) ?? .light
        effects = (try? container.decode(InteractionEffects.self, forKey: .effects)) ?? .followSchedule
        // 制作中的形象与主题即使被写进文件也退回可用项，否则界面会去找不存在的图集。
        if !persona.isAvailable { persona = .fallback }
        if !theme.isAvailable { theme = .fallback }
    }
}
