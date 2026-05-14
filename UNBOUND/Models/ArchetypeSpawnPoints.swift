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
    /// Spawn points are ALWAYS root nodes (no prereqs) of each tree the
    /// archetype engages with. Users start from the very top of every tree
    /// they're seeded into — never mid-chain. If you change a tree's root,
    /// update this list.
    static func nodeIds(for archetype: Archetype) -> [String] {
        switch archetype {
        case .heavyDuty:
            // TITAN: mass-heavy foundation — squat root + carry base + core root.
            return ["ld.goblet-20", "co.bw-farmer-carry", "cal.plank-30"]
        case .leanCut:
            // LEAN: aerobic + upper-body roots (push + pull entry).
            return ["co.bw-farmer-carry", "pp.incline-row", "cal.incline-pushup"]
        case .shredded:
            // SHREDDED: balanced calisthenics — push + pull + legs + core roots.
            return ["pp.incline-row", "cal.incline-pushup", "ld.goblet-20", "cal.plank-30"]
        case .vTaper:
            // V-TAPER: upper-body emphasis — push + pull + core roots.
            return ["pp.incline-row", "cal.incline-pushup", "cal.plank-30"]
        }
    }
}
