import SwiftUI

// MARK: - Unbound Color Tokens
//
// Premium Hollow palette per UNBOUND_PROMPT.md spec.
// Parallel namespace to Color.theme — legacy surfaces keep using Color.theme;
// the new onboarding flow (and Day 2/3 surfaces) use Color.unbound.
//
// Violet is reserved for moments of impact only:
//   - pressed button borders / input focus
//   - progress bar fill
//   - rank badge outline
//   - selected card borders
//   - scan line sweeps
//   - key numeric readouts (Gains, streak count, match %)
//
// Everywhere else: monochrome. When in doubt, remove violet.

extension Color {
    static let unbound = UnboundColors()
}

struct UnboundColors {
    // Surfaces
    let bg = Color.unboundHex("050505")               // pure near-black — page background
    let surface = Color.unboundHex("121212")          // cards, modals, elevated containers
    let surfaceElevated = Color.unboundHex("1A1A1A")  // doubly elevated surfaces

    // Text
    let textPrimary = Color.unboundHex("F5F5F4")      // warm bone white
    let textSecondary = Color.unboundHex("A3A3A3")    // softened from spec for premium readability
    let textTertiary = Color.unboundHex("525252")     // meta / placeholder

    // Borders / dividers
    let border = Color.unboundHex("262626")
    let borderSubtle = Color.unboundHex("1F1F1F")

    // Accents — use sparingly per Violet Usage Rule
    let accent = Color.unboundHex("7C3AED")           // cursed violet — primary interactive signal
    let impact = Color.unboundHex("A855F7")           // impact violet — rank-up, badge unlock

    // Semantic
    let alert = Color.unboundHex("B91C1C")            // critical warnings only
    let success = Color.unboundHex("22C55E")          // sparingly — streak kept, rescan complete

    // Category accents — tinted interactive cards to break monochrome.
    // Muscle heatmap uses a red-green ramp (universal fitness language);
    // tile accents color-code category (coach/communication, warn/attention).
    let coachCyan = Color.unboundHex("06B6D4")        // communication tiles (coach bubble, chat)
    let warnOrange = Color.unboundHex("F97316")       // attention tiles (needs work, weakness)
    let rankRed = Color.unboundHex("B91C1C")          // E-rank muscles — urgent/untrained
    let rankOrange = Color.unboundHex("F97316")       // D-rank muscles — weak
    let rankAmber = Color.unboundHex("EAB308")        // C-rank muscles — moderate
    let rankGreen = Color.unboundHex("22C55E")        // B-rank muscles — solid
    let rankGold = Color.unboundHex("FFC857")         // S-rank muscles — elite
}

// Self-contained hex helper so this file has no cross-file dependency.
// Named distinctly to avoid any collision with Color+Theme's init(hex:).
extension Color {
    fileprivate static func unboundHex(_ hex: String) -> Color {
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >>  8) & 0xFF) / 255.0
        let b = Double( int        & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
