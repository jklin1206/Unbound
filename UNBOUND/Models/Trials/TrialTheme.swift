import Foundation
import SwiftUI

/// The axis or wildcard flavor that defines a weekly vow.
enum WeeklyVowTheme: Codable, Hashable, Sendable {
    case axis(AttributeKey)
    case wildcard
}

extension WeeklyVowTheme {
    /// Bridges a Binding Vows v2 lane to the Squad activity feed's legacy theme
    /// tag. The squad row renders only the vow name, so this preserves the
    /// persisted payload shape without reintroducing the retired card `theme`.
    init(lane: VowLane) {
        switch lane {
        case .recovery: self = .axis(.mobility)
        case .fuel:     self = .axis(.vitality)
        case .engine:   self = .axis(.endurance)
        }
    }
}

// MARK: - UI helpers

extension WeeklyVowTheme {
    /// Accent color used for vow cards and in-session chips.
    var tintColor: Color {
        switch self {
        case .axis(let key):
            switch key {
            case .power:         return Color.unbound.accent
            case .vitality:       return Color(red: 0.3, green: 0.82, blue: 0.55)
            case .control:       return Color(red: 0.45, green: 0.65, blue: 1.0)
            case .endurance:     return Color(red: 0.25, green: 0.70, blue: 0.50)
            case .mobility:      return Color(red: 0.55, green: 0.75, blue: 0.35)
            case .explosiveness: return Color(red: 0.95, green: 0.60, blue: 0.20)
            }
        case .wildcard:
            return Color(red: 0.90, green: 0.75, blue: 0.30)   // gold-ish
        }
    }

    /// Human-readable label for the theme tag.
    var displayLabel: String {
        switch self {
        case .axis(let key): return key.displayName.uppercased()
        case .wildcard:      return "WILDCARD"
        }
    }
}

typealias TrialTheme = WeeklyVowTheme
