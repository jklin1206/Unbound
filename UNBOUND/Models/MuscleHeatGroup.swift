import Foundation

// MARK: - MuscleHeatGroup
//
// Coarser muscle partition driven by the anatomical-lineart heatmap
// (Resources/BodyMap/heatmap_front.png + heatmap_back.png). Labels mirror
// the `regions.json` shipped with the pipeline — see muscle-heat-map/README.
//
// Parallel to the older `BodyRegion` enum: BodyRegion is 14-way and
// drives lift→rank contribution logic; MuscleHeatGroup is 12-way and
// drives the home-hub visual. A `BodyRegion.heatGroup` mapping folds
// lats+lowerBack→back and abs+obliques→core.

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

// MARK: - BodyRegion bridge

extension BodyRegion {
    /// Which heatmap group this detailed region rolls up into. Multiple
    /// BodyRegions can share a heatGroup — the heatmap aggregator picks
    /// the max rank across the contributors.
    var heatGroup: MuscleHeatGroup {
        switch self {
        case .chest:      return .chest
        case .shoulders:  return .shoulders
        case .biceps:     return .biceps
        case .triceps:    return .triceps
        case .forearms:   return .forearms
        case .traps:      return .traps
        case .lats:       return .back
        case .lowerBack:  return .back
        case .abs:        return .core
        case .obliques:   return .core
        case .quads:      return .legs
        case .hamstrings: return .hamstrings
        case .glutes:     return .glutes
        case .calves:     return .calves
        }
    }
}

extension MuscleHeatGroup {
    /// Roll up a per-BodyRegion rank map into the 12-group heatmap space,
    /// taking the max ordinal rank where multiple regions contribute.
    static func aggregate(
        from regionRanks: [BodyRegion: SubRank]
    ) -> [MuscleHeatGroup: SubRank] {
        var result: [MuscleHeatGroup: SubRank] = [:]
        for (region, rank) in regionRanks {
            let group = region.heatGroup
            if let existing = result[group], existing.ordinal >= rank.ordinal {
                continue
            }
            result[group] = rank
        }
        return result
    }
}
