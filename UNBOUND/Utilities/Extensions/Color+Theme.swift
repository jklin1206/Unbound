import SwiftUI

extension Color {
    static let theme = ThemeColors()
}

struct ThemeColors {
    // Realigned with Unbound palette so every legacy surface inherits
    // violet-on-black consistently. Previous values: primary #FF6B35 orange,
    // primaryLight #FF8F5E, secondary #00D4AA teal — all retired.
    let background = Color(hex: "050505")        // matches unbound.bg
    let surface = Color(hex: "121212")           // matches unbound.surface
    let surfaceLight = Color(hex: "1A1A1A")      // matches unbound.surfaceElevated
    let primary = Color(hex: "7C3AED")           // violet — matches unbound.accent
    let primaryLight = Color(hex: "A855F7")      // impact violet — matches unbound.impact
    let secondary = Color(hex: "525252")         // neutral gray — monochrome-first
    let textPrimary = Color(hex: "F5F5F4")       // matches unbound.textPrimary
    let textSecondary = Color(hex: "A3A3A3")    // matches unbound.textSecondary
    let textMuted = Color(hex: "525252")         // matches unbound.textTertiary
    let danger = Color(hex: "B91C1C")            // matches unbound.alert
    let success = Color(hex: "22C55E")
    let warning = Color(hex: "FFD60A")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
