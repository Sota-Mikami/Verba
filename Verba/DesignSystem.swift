import SwiftUI

// Discord-inspired design tokens
enum DS {
    // Backgrounds
    static let bgPrimary = Color(hex: 0x313338)
    static let bgSecondary = Color(hex: 0x2B2D31)
    static let bgTertiary = Color(hex: 0x1E1F22)
    static let bgModifierHover = Color.white.opacity(0.04)
    static let bgModifierActive = Color.white.opacity(0.06)
    static let bgModifierSelected = Color.white.opacity(0.08)

    // Text
    static let textNormal = Color(hex: 0xDBDEE1)
    static let textMuted = Color(hex: 0x949BA4)
    static let textFaint = Color(hex: 0x6D6F78)
    static let textLink = Color(hex: 0x00A8FC)

    // Brand
    static let blurple = Color(hex: 0x5865F2)
    static let blurpleLight = Color(hex: 0x7289DA)

    // Status
    static let green = Color(hex: 0x57F287)
    static let yellow = Color(hex: 0xFEE75C)
    static let red = Color(hex: 0xED4245)
    static let orange = Color(hex: 0xFAA61A)

    // Layout
    static let radiusSmall: CGFloat = 4
    static let radiusMedium: CGFloat = 8
    static let radiusLarge: CGFloat = 12

    // Card background
    static let cardBg = Color(hex: 0x383A40)
    static let cardBorder = Color.white.opacity(0.06)

    // Input
    static let inputBg = Color(hex: 0x1E1F22)
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
