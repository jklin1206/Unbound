// UNBOUND/Models/SkillTreeContent/Tiers/OahSkillTiers.swift
//
// Tier criteria for the one-arm-handstand apex family (oah.*, 2 skills) — GENERATED
// from real-data anchors (OneArmHandstandSkillAnchors + SkillTierGenerator), replacing
// the old hand-authored tables. Both nodes are world-class one-arm handstand holds, so
// both are .feat: the first held second jumps you to a high floor, ranks below are
// "not yet". A 3–5 s OAH is genuinely elite hand-balance; a full one-arm handstand is
// near the ceiling of the discipline. Mirrors the pull family (PpSkillTiers). Hold
// seconds grounded in docs/standards-statics.md §5 + OAH coach consensus.
//
// oah has NO orphans — both nodes are real.

import Foundation

#if DEBUG
private let _oahCountCheck: Int = {
    assert(
        OneArmHandstandSkillAnchors.table.count == 2,
        "oah cluster should have 2 entries, has \(OneArmHandstandSkillAnchors.table.count)"
    )
    for (id, tiers) in OahSkillTiers.table {
        assert(tiers.count == 9, "\(id) needs 9 tiers, has \(tiers.count)")
        for tier in SkillTier.allCases {
            assert(tiers[tier] != nil, "\(id) missing tier \(tier)")
        }
    }
    return OneArmHandstandSkillAnchors.table.count
}()
#endif

enum OneArmHandstandSkillAnchors {
    static let table: [String: SkillAnchor] = [
        // A 3–5 s one-arm handstand is world-class — vessel entry.
        "oah.one-arm-handstand-5s":   .init(exerciseName: "one-arm handstand",      metric: .seconds, spec: .scaled(to: 30)), // floor 6 → 3 vals
        // Full one-arm handstand — apex of the discipline — unbound entry.
        "oah.full-one-arm-handstand": .init(exerciseName: "full one arm handstand", metric: .seconds, spec: .scaled(to: 28)),    // floor 7 → 2 vals
    ]
}

enum OahSkillTiers {
    /// Generated from `OneArmHandstandSkillAnchors` — each anchor's real-data ladder → 9 tiers.
    static let table: [String: [SkillTier: TierCriterion]] =
        OneArmHandstandSkillAnchors.table.mapValues { SkillTierGenerator.generate($0) }
}
