import Foundation

/// Which card slot in the 3-card weekly trio.
enum TrialCardKind: String, Codable, CaseIterable, Sendable {
    case aligned    // Reinforces the user's strongest axis
    case growth     // Targets the user's weakest axis
    case prestige   // Stretch / wildcard
}
