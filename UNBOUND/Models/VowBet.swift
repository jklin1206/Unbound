import Foundation

/// The size of a Binding Vow bet (spec §5). `oweXP` is withheld from future
/// earned training XP on a break; `winXP` is the token paid on a clear.
enum VowBet: String, CaseIterable, Codable, Sendable {
    case small
    case medium
    case large

    var oweXP: Int {
        switch self {
        case .small: return 150
        case .medium: return 250
        case .large: return 300
        }
    }

    var winXP: Int {
        switch self {
        case .small: return 50
        case .medium: return 100
        case .large: return 150
        }
    }

    var displayLabel: String {
        switch self {
        case .small: return "SMALL"
        case .medium: return "MEDIUM"
        case .large: return "LARGE"
        }
    }
}
