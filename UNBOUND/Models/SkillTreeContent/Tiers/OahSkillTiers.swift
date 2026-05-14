// UNBOUND/Models/SkillTreeContent/Tiers/OahSkillTiers.swift
//
// Tier criteria for every skill with prefix `oah.` (2 skills).
// One-arm handstand family — the most elite skills in the entire tree.
// See HsSkillTiers.swift and HspuSkillTiers.swift for upstream prerequisites.
//
// Both skills sit at the absolute ceiling of the calisthenics skill tree.
// Even Initiate requires deep handstand competence — users arriving here have
// already passed through the full hs.* and hspu.* chains.
//
// oah.one-arm-handstand-5s (hold-type):
//   Lower tiers gate on freestanding handstand + wall HSPU volume to confirm
//   the overhead press base that stabilises a one-arm hold. Mid tiers
//   introduce the wall-supported one-arm handstand (from hs.*). Upper tiers
//   compound with freestanding HSPU reps — the strength limit for maintaining
//   a free OAH. Ascendant requires freestanding HSPU volume + a wall-supported
//   one-arm hold still active.
//
// oah.one-arm-hspu (rep-type):
//   Lower tiers cascade through freestanding HSPU (both standard and deficit)
//   and the wall-supported OAH — you must own all sub-components before the
//   first one-arm HSPU is attempted. Mid tiers confirm the single rep.
//   Upper tiers escalate via compound of one-arm hspu + freestanding hspu
//   volume. Ascendant is the most elite criterion in the entire app:
//   one-arm hspu × 3 reps + freestanding hspu × 10 reps.

import Foundation

#if DEBUG
private let _oahCountCheck: Int = {
    assert(
        OahSkillTiers.table.count == 2,
        "oah cluster should have 2 entries, has \(OahSkillTiers.table.count)"
    )
    for (id, tiers) in OahSkillTiers.table {
        assert(tiers.count == 9, "\(id) needs 9 tiers, has \(tiers.count)")
        for tier in SkillTier.allCases {
            assert(tiers[tier] != nil, "\(id) missing tier \(tier)")
        }
    }
    return OahSkillTiers.table.count
}()
#endif

enum OahSkillTiers {
    static let table: [String: [SkillTier: TierCriterion]] = [

        // MARK: - One-Arm Handstand

        // oah.one-arm-handstand-5s — One-Arm Handstand; hold target: 5 s.
        // Hold-type. Hardest static handstand in the tree. Even at Initiate
        // the user must already have a deep freestanding HS base and solid
        // wall HSPU volume. Mid tiers introduce wall-supported one-arm work.
        // Upper tiers compound with freestanding HSPU reps — shoulder stability
        // under pressing load is the direct limiter for a free one-arm hold.
        "oah.one-arm-handstand-5s": [
            .initiate:   .compound([.variant("freestanding handstand"), .reps(8, exerciseName: "wall hspu")]),
            .novice:     .compound([.variant("freestanding handstand"), .reps(12, exerciseName: "wall hspu")]),
            .apprentice: .compound([.variant("wall-supported one-arm handstand"), .reps(5, exerciseName: "freestanding hspu")]),
            .forged:     .compound([.variant("wall-supported one-arm handstand"), .reps(7, exerciseName: "freestanding hspu")]),
            .veteran:    .compound([.variant("one-arm handstand"), .reps(3, exerciseName: "freestanding hspu")]),
            .honed:      .compound([.variant("one-arm handstand"), .reps(5, exerciseName: "freestanding hspu")]),
            .vessel:     .compound([.variant("one-arm handstand"), .reps(7, exerciseName: "freestanding hspu")]),
            .unbound:    .compound([.variant("one-arm handstand"), .reps(10, exerciseName: "freestanding hspu")]),
            .ascendant:  .compound([.variant("one-arm handstand"), .variant("wall-supported one-arm handstand"), .reps(10, exerciseName: "freestanding hspu")]),
        ],

        // MARK: - One-Arm HSPU

        // oah.one-arm-hspu — One-Arm HSPU; anchor: 1 rep = Veteran.
        // Rep-type. The most elite criterion in the entire app. Lower tiers
        // require the full freestanding HSPU chain — both standard and deficit
        // reps — plus wall-supported one-arm handstand to confirm unilateral
        // balance. Forged = the first clean one-arm HSPU rep. Upper tiers
        // compound with freestanding HSPU volume to confirm the bilateral
        // base remains deeply owned. Ascendant = 3 one-arm HSPUs + 10
        // freestanding HSPUs: a genuinely world-class pressing standard.
        "oah.one-arm-hspu": [
            .initiate:   .compound([.variant("freestanding handstand"), .reps(5, exerciseName: "freestanding hspu")]),
            .novice:     .compound([.variant("wall-supported one-arm handstand"), .reps(7, exerciseName: "freestanding hspu")]),
            .apprentice: .compound([.variant("wall-supported one-arm handstand"), .reps(3, exerciseName: "deficit freestanding hspu")]),
            .forged:     .reps(1, exerciseName: "one-arm hspu"),
            .veteran:    .compound([.reps(1, exerciseName: "one-arm hspu"), .reps(5, exerciseName: "freestanding hspu")]),
            .honed:      .compound([.reps(2, exerciseName: "one-arm hspu"), .reps(7, exerciseName: "freestanding hspu")]),
            .vessel:     .compound([.reps(2, exerciseName: "one-arm hspu"), .reps(10, exerciseName: "freestanding hspu")]),
            .unbound:    .compound([.reps(3, exerciseName: "one-arm hspu"), .reps(7, exerciseName: "freestanding hspu")]),
            .ascendant:  .compound([.reps(3, exerciseName: "one-arm hspu"), .reps(10, exerciseName: "freestanding hspu")]),
        ],
    ]
}
