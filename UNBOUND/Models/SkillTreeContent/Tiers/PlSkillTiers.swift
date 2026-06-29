// UNBOUND/Models/SkillTreeContent/Tiers/PlSkillTiers.swift
//
// Tier criteria for the planche family (pl.*, 5 real hold-stage nodes) — GENERATED
// from real-data anchors (PlancheSkillAnchors + SkillTierGenerator), replacing the
// old hand-authored 9-tier-per-node tables. Planche is the HARDEST static family in
// the standards doc: the full planche sits above every rep anchor, an 8 s hold is
// elite, and ~15 s approaches the recorded WR ceiling (docs/standards-statics.md §4).
//
// Difficulty order (easiest → hardest): bent-arm < tuck < straddle < half-lay < full.
//   • bent-arm + tuck planche are the GRIND on-ramps — real second-count range, so
//     .full spreads 5 hold standards across the 9 tiers.
//   • straddle / half-lay / full are FEATS — owning them at all is advanced→elite, so
//     each starts at a difficulty FLOOR (first hold jumps you there) and climbs a short
//     ladder floor…peak. Floors rise with difficulty; full planche has the highest floor
//     (Vessel) so it ranks above every other planche stage, per the brief.
//
// Five orphan rep-nodes (full-planche-pushup, ninety-degree-pushup, one-arm-planche,
// pseudo-planche-pushup, tuck-planche-pushup) were confirmed dead (zero consumers) and
// dropped — the cluster now ships exactly the 5 real hold stages.
//
// The node's difficulty (SkillNode.tier, used by trials) is unchanged — only the
// per-node rank ladder is generated here. See docs/standards-statics.md §4.

import Foundation

import Foundation

#if DEBUG
private let _plCountCheck: Int = {
    assert(
        PlSkillTiers.table.count == 5,
        "pl cluster should have 5 entries, has \(PlSkillTiers.table.count)"
    )
    for (id, tiers) in PlSkillTiers.table {
        assert(tiers.count == 9, "\(id) needs 9 tiers, has \(tiers.count)")
        for tier in SkillTier.allCases {
            assert(tiers[tier] != nil, "\(id) missing tier \(tier)")
        }
    }
    return PlSkillTiers.table.count
}()
#endif

// MARK: - Planche family anchors (canonical hold nodes — real data)
//
// Keyed by real pl.* node ids. All metric .seconds (timed holds). Grind on-ramps use
// .full (5 hold standards from docs/standards-statics.md §4); the advanced→elite stages
// use .feat (a floor rank from the move's difficulty + a short second-count ladder).

enum PlancheSkillAnchors {
    static let table: [String: SkillAnchor] = [
        // Grind on-ramps — real second-count range, full 9-tier spread.
        "pl.bent-arm-planche": .init(exerciseName: "bent arm planche", metric: .seconds, spec: .full([2, 3, 5, 8, 12])),   // bent-arm = easier entry, the on-ramp
        "pl.tuck-planche":     .init(exerciseName: "tuck planche",     metric: .seconds, spec: .full([3, 5, 10, 20, 30])), // tuck stds: Nov 5 / Int 10 / Adv 20 / Elite 30

        // Feats — owning the stage at all is advanced→elite; start at a difficulty floor,
        // climb a short ladder floor…peak (count == 9 - floor.rawValue). Floors rise with
        // difficulty; full planche is highest (Vessel), ranking it above every other stage.
        "pl.straddle-planche": .init(exerciseName: "straddle planche", metric: .seconds, spec: .scaled(to: 35)), // floor 4 → 5 vals; advanced/elite stage
        "pl.half-lay-planche": .init(exerciseName: "half-lay planche", metric: .seconds, spec: .scaled(to: 26)),     // floor 5 → 4 vals; between straddle and full
        "pl.full-planche":     .init(exerciseName: "full planche",     metric: .seconds, spec: .scaled(to: 18)),         // floor 6 → 3 vals; 1 s = Vessel, 8 s elite, peak ~world-class
    ]
}

enum PlSkillTiers {
    /// Generated from `PlancheSkillAnchors` — each anchor's real-data ladder → 9 tiers.
    static let table: [String: [SkillTier: TierCriterion]] =
        PlancheSkillAnchors.table.mapValues { SkillTierGenerator.generate($0) }
}
