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
    //   Dark:  warm plum-black (LP palette)
    //   Light: warm off-whites (not cold gray)
    static var bgPrimary: Color { activeScheme == .dark ? Color(hex: 0x0c0b0f) : Color(hex: 0xfaf8f5) }
    static var bgSecondary: Color { activeScheme == .dark ? Color(hex: 0x15141a) : Color(hex: 0xf3f0ec) }
    static var bgTertiary: Color { activeScheme == .dark ? Color(hex: 0x1c1b23) : Color(hex: 0xe8e4de) }
    static var bgModifierHover: Color { activeScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03) }
    static var bgModifierActive: Color { activeScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06) }
    static var bgModifierSelected: Color { activeScheme == .dark ? Color.white.opacity(0.08) : accent.opacity(0.12) }

    // Text
    //   Dark:  warm off-white (never pure white)
    //   Light: warm dark (not pure black)
    static var textNormal: Color { activeScheme == .dark ? Color(hex: 0xede8e1) : Color(hex: 0x2a2520) }
    static var textMuted: Color { activeScheme == .dark ? Color(hex: 0x9a948a) : Color(hex: 0x6b645a) }
    static var textFaint: Color { activeScheme == .dark ? Color(hex: 0x5a5650) : Color(hex: 0x9a948a) }
    static var textLink: Color { activeScheme == .dark ? Color(hex: 0x9b8aff) : Color(hex: 0x5c4ed6) }

    // Text on accent backgrounds (always light for contrast)
    static var textOnAccent: Color { Color(hex: 0xfaf8f5) }

    // Card — elevated surface
    static var cardBg: Color { activeScheme == .dark ? Color(hex: 0x1c1b23) : Color(hex: 0xFFFFFF) }
    static var cardBorder: Color { activeScheme == .dark ? Color.white.opacity(0.06) : Color(hex: 0x2a2520).opacity(0.08) }

    // Input
    static var inputBg: Color { activeScheme == .dark ? Color(hex: 0x1c1b23) : Color(hex: 0xe8e4de) }

    // Brand — Verba purple (cool accent for machine/tech)
    static var accent: Color { activeScheme == .dark ? Color(hex: 0x7c6cfc) : Color(hex: 0x5c4ed6) }
    static var accentLight: Color { activeScheme == .dark ? Color(hex: 0x9b8aff) : Color(hex: 0x7c6cfc) }

    // Voice — warm amber (for recording, streaming, voice-related feedback)
    static var warm: Color { activeScheme == .dark ? Color(hex: 0xf0a060) : Color(hex: 0xc47a30) }

    // Legacy aliases (transitional)
    static var blurple: Color { accent }
    static var blurpleLight: Color { accentLight }

    // Status
    static var green: Color { activeScheme == .dark ? Color(hex: 0x3dd68c) : Color(hex: 0x248045) }
    static var yellow: Color { activeScheme == .dark ? Color(hex: 0xfbbf24) : Color(hex: 0x9B6E1A) }
    static var red: Color { activeScheme == .dark ? Color(hex: 0xf04747) : Color(hex: 0xD83C3E) }
    static var orange: Color { activeScheme == .dark ? Color(hex: 0xf0a060) : Color(hex: 0xC27803) }

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
