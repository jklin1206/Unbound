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
//
// Phase 2 (program-redesign): Heavy Lifting cluster removed. TITAN/LEAN
// archetypes re-seeded onto calisthenics + endurance entry nodes.

enum ArchetypeSpawnPoints {
    static func nodeIds(for archetype: Archetype) -> [String] {
        switch archetype {
        case .heavyDuty:
            // TITAN: mass-heavy foundation — squat base + carry base + core.
            return ["ld.goblet-20", "co.bw-farmer-carry", "cal.plank-30"]
        case .leanCut:
            // LEAN: aerobic + upper-body entry.
            return ["pp.dead-hang-30", "cal.plank-30"]
        case .shredded:
            return ["cal.plank-30", "pp.dead-hang-30", "ld.bulgarian-split-squat"]
        case .vTaper:
            return ["pp.dead-hang-30", "cal.plank-30"]
        }
    }
}
