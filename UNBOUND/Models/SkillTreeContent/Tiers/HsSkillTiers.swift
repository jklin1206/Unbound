// UNBOUND/Models/SkillTreeContent/Tiers/HsSkillTiers.swift
//
// Tier criteria for the handstand family (hs.*, 14 skills) — GENERATED from real-data
// anchors (HandstandSkillAnchors + SkillTierGenerator), replacing the old hand-authored
// 9-tier-per-node tables. Hold progressions (wall plank, wall/freestanding handstand,
// headstand, arm balances, levers) spread real hold-second standards across the 9 tiers
// via .full; hard feats (one-arm holds, press-to-handstand chain) start high — the first
// rep/hold jumps to a floor rank, ranks below are "not yet". The node's difficulty
// (SkillNode.tier, used by trials) is unchanged — only the per-node rank ladder is
// generated here. Mirrors the pull family (PpSkillTiers). Hold seconds grounded in
// docs/standards-statics.md §5 (wall HS 10/30/60/90/120; freestanding HS <1/5/15/30/60;
// crow/crane/elbow-lever coach-consensus short balance holds).
//
// 6 orphan hs.* nodes (freestanding-hs-10, freestanding-hs-60, frog-pose,
// handstand-walk-10m, wall-handstand-60, wrist-conditioning) are dead (zero consumers)
// and intentionally excluded.

import Foundation

import Foundation

#if DEBUG
private let _hsCountCheck: Int = {
    assert(
        HandstandSkillAnchors.table.count == 14,
        "hs cluster should have 14 entries, has \(HandstandSkillAnchors.table.count)"
    )
    for (id, tiers) in HsSkillTiers.table {
        assert(tiers.count == 9, "\(id) needs 9 tiers, has \(tiers.count)")
        for tier in SkillTier.allCases {
            assert(tiers[tier] != nil, "\(id) missing tier \(tier)")
        }
    }
    return HandstandSkillAnchors.table.count
}()
#endif

enum HandstandSkillAnchors {
    static let table: [String: SkillAnchor] = [
        // ── HOLD progressions — real hold-second range, full 9-tier spread. ──
        "hs.wall-plank":          .init(exerciseName: "wall plank",              metric: .seconds, spec: .full([20, 40, 60, 90, 120])),
        "hs.wall-handstand-30":   .init(exerciseName: "wall handstand",          metric: .seconds, spec: .full([10, 30, 60, 90, 120])),
        "hs.headstand":           .init(exerciseName: "headstand",               metric: .seconds, spec: .full([15, 30, 60, 90, 120])),
        "hs.crow-pose":           .init(exerciseName: "crow pose",               metric: .seconds, spec: .full([5, 15, 30, 45, 60])),
        "hs.tuck-handstand":      .init(exerciseName: "tuck handstand",          metric: .seconds, spec: .full([5, 10, 20, 30, 45])),
        "hs.crane-pose":          .init(exerciseName: "crane pose",              metric: .seconds, spec: .full([5, 10, 20, 30, 45])),
        "hs.elbow-lever":         .init(exerciseName: "elbow lever",             metric: .seconds, spec: .full([5, 10, 20, 30, 45])),
        "hs.flying-crow":         .init(exerciseName: "flying crow",             metric: .seconds, spec: .full([3, 5, 10, 15, 25])),
        "hs.freestanding-hs-30":  .init(exerciseName: "freestanding handstand",  metric: .seconds, spec: .full([5, 15, 30, 45, 60])),

        // ── Hard feats — floor by eliteness (NOT node.tier); short ladder floor…peak. ──
        // One-arm elbow lever: a held one-arm balance — veteran entry.
        "hs.one-arm-elbow-lever": .init(exerciseName: "one-arm elbow lever",            metric: .seconds, spec: .scaled(to: 30)), // floor 4 → 5 vals
        // Wall-supported one-arm handstand: master entry (real OAH lead-up).
        "hs.wall-supported-oah":  .init(exerciseName: "wall-supported one-arm handstand", metric: .seconds, spec: .scaled(to: 35)),       // floor 5 → 4 vals
        // Press chain (reps) — tuck press is the press-to-handstand lead-up, veteran entry.
        "hs.tuck-press":          .init(exerciseName: "tuck press",                       metric: .reps,    spec: .scaled(to: 24)),    // floor 4 → 5 vals
        "hs.straddle-press":      .init(exerciseName: "straddle press",                   metric: .reps,    spec: .scaled(to: 21)),          // floor 6 → 3 vals
        "hs.press-to-handstand":  .init(exerciseName: "press to handstand",               metric: .reps,    spec: .scaled(to: 18)),          // floor 6 → 3 vals
    ]
}

enum HsSkillTiers {
    /// Generated from `HandstandSkillAnchors` — each anchor's real-data ladder → 9 tiers.
    static let table: [String: [SkillTier: TierCriterion]] =
        HandstandSkillAnchors.table.mapValues { SkillTierGenerator.generate($0) }
}
