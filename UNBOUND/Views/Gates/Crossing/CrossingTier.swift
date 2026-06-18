import Foundation

/// The cadence of The Crossing, tiered by how far into the journey the gate is
/// (spec §8). `short` = gates I–IV (~7s), `full` = V–VII (~15s), `finale` = VIII
/// (flashback montage of all eight stamped gate cards → the gold flood).
enum CrossingTier: Equatable, Sendable {
    case short
    case full
    case finale

    /// Derive from the destination rank's gate order (1…8).
    static func forOrder(_ order: Int) -> CrossingTier {
        switch order {
        case ...4: return .short
        case 5...7: return .full
        default: return .finale
        }
    }

    /// Beat durations in seconds: (hush, walk, arrival, investiture).
    /// The spoils beat holds until dismissed. `finale` adds a montage budget.
    var beats: (hush: Double, walk: Double, arrival: Double, investiture: Double) {
        switch self {
        case .short:  return (0.6, 2.2, 1.4, 1.6)
        case .full:   return (0.9, 5.0, 3.0, 2.6)
        case .finale: return (0.9, 3.0, 2.4, 2.6) // walk = the 8-card flashback montage
        }
    }

    /// Per-card dwell time for the finale flashback montage (8 cards).
    var montageCardInterval: Double { 0.34 }
}
