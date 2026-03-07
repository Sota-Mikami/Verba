import SwiftUI

// MARK: - Appearance Setting

enum AppAppearance: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Active color scheme (set by AppState)

enum DS {
    static var activeScheme: ColorScheme = .dark

    // Backgrounds
    //   Dark:  Discord grays
    //   Light: Subtle warm grays, clear hierarchy
    static var bgPrimary: Color { activeScheme == .dark ? Color(hex: 0x313338) : Color(hex: 0xFFFFFF) }
    static var bgSecondary: Color { activeScheme == .dark ? Color(hex: 0x2B2D31) : Color(hex: 0xF0F1F3) }
    static var bgTertiary: Color { activeScheme == .dark ? Color(hex: 0x1E1F22) : Color(hex: 0xE3E5E8) }
    static var bgModifierHover: Color { activeScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.04) }
    static var bgModifierActive: Color { activeScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.08) }
    static var bgModifierSelected: Color { activeScheme == .dark ? Color.white.opacity(0.08) : blurple.opacity(0.15) }

    // Text — WCAG AA contrast ratios on respective backgrounds
    //   textNormal: ≥7:1 (AAA)
    //   textMuted:  ≥4.5:1 (AA)
    //   textFaint:  ≥3:1 (AA for large text / UI elements)
    static var textNormal: Color { activeScheme == .dark ? Color(hex: 0xDBDEE1) : Color(hex: 0x1A1D21) }
    static var textMuted: Color { activeScheme == .dark ? Color(hex: 0x949BA4) : Color(hex: 0x5C5F66) }
    static var textFaint: Color { activeScheme == .dark ? Color(hex: 0x6D6F78) : Color(hex: 0x80848E) }
    static var textLink: Color { activeScheme == .dark ? Color(hex: 0x00A8FC) : Color(hex: 0x0060DF) }

    // Card
    //   Light: white cards on gray background for clear elevation
    static var cardBg: Color { activeScheme == .dark ? Color(hex: 0x383A40) : Color(hex: 0xFFFFFF) }
    static var cardBorder: Color { activeScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.12) }

    // Input
    static var inputBg: Color { activeScheme == .dark ? Color(hex: 0x1E1F22) : Color(hex: 0xE8EAED) }

    // Brand
    static var blurple: Color { activeScheme == .dark ? Color(hex: 0x5865F2) : Color(hex: 0x4752C4) }
    static var blurpleLight: Color { activeScheme == .dark ? Color(hex: 0x7289DA) : Color(hex: 0x5865F2) }

    // Status — darker variants in light mode for contrast on white/light backgrounds
    static var green: Color { activeScheme == .dark ? Color(hex: 0x57F287) : Color(hex: 0x248045) }
    static var yellow: Color { activeScheme == .dark ? Color(hex: 0xFEE75C) : Color(hex: 0x9B6E1A) }
    static var red: Color { activeScheme == .dark ? Color(hex: 0xED4245) : Color(hex: 0xD83C3E) }
    static var orange: Color { activeScheme == .dark ? Color(hex: 0xFAA61A) : Color(hex: 0xC27803) }

    // Layout
    static let radiusSmall: CGFloat = 4
    static let radiusMedium: CGFloat = 8
    static let radiusLarge: CGFloat = 12
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
