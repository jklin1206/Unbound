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
// oah.full-one-arm-handstand (hold-type):
//   The active mythic terminal for one-arm handbalancing. It extends the
//   5-second one-arm standard into longer, cleaner holds with wall-supported
//   one-arm work and freestanding HSPU volume used as stability proof.

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
            .master:      .compound([.variant("one-arm handstand"), .reps(5, exerciseName: "freestanding hspu")]),
            .vessel:     .compound([.variant("one-arm handstand"), .reps(7, exerciseName: "freestanding hspu")]),
            .unbound:    .compound([.variant("one-arm handstand"), .reps(10, exerciseName: "freestanding hspu")]),
            .ascendant:  .compound([.variant("one-arm handstand"), .variant("wall-supported one-arm handstand"), .reps(10, exerciseName: "freestanding hspu")]),
        ],

        // MARK: - Full One-Arm Handstand

        // oah.full-one-arm-handstand — Full One-Arm Handstand; hold target: 5+ s.
        // Hold-type. Active mythic terminal. Lower tiers confirm the standard
        // one-arm hold and wall-supported one-arm control. Upper tiers extend
        // duration while preserving the bilateral pressing base.
        "oah.full-one-arm-handstand": [
            .initiate:   .compound([.variant("one-arm handstand"), .variant("wall-supported one-arm handstand")]),
            .novice:     .compound([.variant("one-arm handstand"), .reps(3, exerciseName: "freestanding hspu")]),
            .apprentice: .compound([.variant("one-arm handstand"), .reps(5, exerciseName: "freestanding hspu")]),
            .forged:     .compound([.variant("full one arm handstand"), .reps(5, exerciseName: "freestanding hspu")]),
            .veteran:    .compound([.variant("full one arm handstand"), .reps(7, exerciseName: "freestanding hspu")]),
            .master:      .compound([.variant("full one arm handstand"), .reps(10, exerciseName: "freestanding hspu")]),
            .vessel:     .compound([.variant("full one arm handstand"), .variant("wall-supported one-arm handstand"), .reps(10, exerciseName: "freestanding hspu")]),
            .unbound:    .compound([.variant("full one arm handstand"), .reps(12, exerciseName: "freestanding hspu")]),
            .ascendant:  .compound([.variant("full one arm handstand"), .variant("one-arm handstand"), .reps(15, exerciseName: "freestanding hspu")]),
        ],
    ]
}
