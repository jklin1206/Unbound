import Foundation

// MARK: - MuscleHeatGroup
//
// Coarse 12-way muscle partition. The canonical training-signal taxonomy:
// `ScanContextBuilder` buckets recent training volume into these groups and
// `ScanContext` keys its 14-day signal map by `MuscleHeatGroup.rawValue`,
// which the rescan/program-generation pipeline consumes. The rawValues are
// part of that contract — keep them stable.

enum MuscleHeatGroup: String, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    var id: String { rawValue }

    // Upper
    case chest, shoulders, biceps, triceps, forearms, traps, back
    // Core
    case core
    // Lower
    case legs, hamstrings, glutes, calves

    var displayName: String {
        switch self {
        case .chest:      return "Chest"
        case .shoulders:  return "Shoulders"
        case .biceps:     return "Biceps"
        case .triceps:    return "Triceps"
        case .forearms:   return "Forearms"
        case .traps:      return "Traps"
        case .back:       return "Back"
        case .core:       return "Core"
        case .legs:       return "Legs"
        case .hamstrings: return "Hamstrings"
        case .glutes:     return "Glutes"
        case .calves:     return "Calves"
        }
    }
}
