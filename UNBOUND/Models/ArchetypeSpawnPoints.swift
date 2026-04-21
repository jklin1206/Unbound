import Foundation

// MARK: - ArchetypeSpawnPoints
//
// Each archetype spawns with 2-3 nodes seeded as `.attempting` in different
// clusters. Everything else starts `.locked`. Identity emerges from where
// you start + which clusters you develop — NOT from finishing a specific
// tree.
//
// The old boss/archetype-lock model is gone. Every user can theoretically
// reach every node; spawn points only dictate the initial "attempting" set.

enum ArchetypeSpawnPoints {
    static func nodeIds(for archetype: Archetype) -> [String] {
        switch archetype {
        case .heavyDuty:
            // TITAN inherits the mass-heavy pull seed previously split with BRUISER.
            return ["hl.bw-back-squat", "hl.bw-deadlift", "ld.goblet-20"]
        case .leanCut:
            return ["hl.0.75x-bench", "pp.dead-hang-30"]
        case .shredded:
            return ["cal.plank-30", "pp.dead-hang-30", "ld.bulgarian-split-squat"]
        case .vTaper:
            return ["pp.dead-hang-30", "cal.plank-30"]
        }
    }
}
