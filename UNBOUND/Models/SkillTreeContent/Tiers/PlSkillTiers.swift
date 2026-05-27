// UNBOUND/Models/SkillTreeContent/Tiers/PlSkillTiers.swift
//
// Tier criteria for every skill with prefix `pl.` (10 skills).
// Planche family — horizontal push compression. See CalSkillTiers for pattern.
//
// Progression chain (weakest → strongest):
//   pseudo-planche-pushup → tuck-planche → tuck-planche-pushup →
//   straddle-planche → half-lay-planche → full-planche →
//   full-planche-pushup → ninety-degree-pushup →
//   bent-arm-planche → one-arm-planche (mythic)
//
// All planche holds are body-weight-only; no kg/ratio criteria needed.
// Hold-type skills: lower tiers use .variant("...") — confirms any logged
// session. Upper tiers compound with upstream hold variants + pushup volume
// to confirm strength and not just balance entry.
//
// Rep-type skills (pseudo-planche pushup, tuck planche pushup, full planche
// pushup, 90° pushup): lower tiers build volume on the exercise itself.
// Upper tiers compound with the hold variant the pushup derives from — you
// must own the hold position to maximise the rep skill.
//
// bent-arm-planche: diagonal hold between tuck planche and full planche.
// Treated identically to other hold-type planches but gated behind tuck and
// straddle planche prerequisites at lower tiers.
//
// one-arm-planche: mythic elite hold. Lower tiers cascade through the full
// planche chain; Ascendant is a compound of the hold itself with full
// planche pushup volume confirming bilateral mastery.

import Foundation

#if DEBUG
private let _plCountCheck: Int = {
    assert(
        PlSkillTiers.table.count == 10,
        "pl cluster should have 10 entries, has \(PlSkillTiers.table.count)"
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

enum PlSkillTiers {
    static let table: [String: [SkillTier: TierCriterion]] = [

        // MARK: - Entry: Pseudo-Planche Push-Up

        // pl.pseudo-planche-pushup — Pseudo-Planche Push-Up; anchor: 5 reps = Forged.
        // Rep-type. Hands shifted to hips with protracted shoulders — the entry
        // to planche-specific compression. Lower tiers start from standard pushup
        // volume to confirm the pressing base. Upper tiers compound with tuck
        // planche to confirm the user can sustain the horizontal shoulder angle.
        "pl.pseudo-planche-pushup": [
            .initiate:   .reps(5,  exerciseName: "pushup"),
            .novice:     .reps(10, exerciseName: "pushup"),
            .apprentice: .reps(5,  exerciseName: "pseudo-planche pushup"),
            .forged:     .reps(10, exerciseName: "pseudo-planche pushup"),
            .veteran:    .reps(15, exerciseName: "pseudo-planche pushup"),
            .master:      .reps(20, exerciseName: "pseudo-planche pushup"),
            .vessel:     .compound([.reps(20, exerciseName: "pseudo-planche pushup"), .variant("tuck planche")]),
            .unbound:    .compound([.reps(25, exerciseName: "pseudo-planche pushup"), .variant("tuck planche")]),
            .ascendant:  .compound([.reps(30, exerciseName: "pseudo-planche pushup"), .reps(3, exerciseName: "tuck planche pushup")]),
        ],

        // MARK: - Tuck Planche

        // pl.tuck-planche — Tuck Planche; hold target: 5 s.
        // Hold-type. First real planche shape. Lower tiers confirm pseudo-planche
        // pushup volume as the pressing base. Mid tiers confirm the actual hold.
        // Upper tiers compound with tuck planche pushup — dynamic confirms static
        // is deeply owned.
        "pl.tuck-planche": [
            .initiate:   .reps(10, exerciseName: "pseudo-planche pushup"),
            .novice:     .reps(15, exerciseName: "pseudo-planche pushup"),
            .apprentice: .variant("tuck planche"),
            .forged:     .compound([.variant("tuck planche"), .reps(5, exerciseName: "pseudo-planche pushup")]),
            .veteran:    .compound([.variant("tuck planche"), .reps(10, exerciseName: "pseudo-planche pushup")]),
            .master:      .compound([.variant("tuck planche"), .reps(1, exerciseName: "tuck planche pushup")]),
            .vessel:     .compound([.variant("tuck planche"), .reps(3, exerciseName: "tuck planche pushup")]),
            .unbound:    .compound([.variant("tuck planche"), .reps(5, exerciseName: "tuck planche pushup")]),
            .ascendant:  .compound([.variant("tuck planche"), .reps(5, exerciseName: "tuck planche pushup"), .variant("straddle planche")]),
        ],

        // MARK: - Tuck Planche Push-Up

        // pl.tuck-planche-pushup — Tuck Planche Push-Up; anchor: 3 reps = Forged.
        // Rep-type. Dynamic pressing from tuck planche position. Lower tiers gate
        // on tuck planche hold to confirm the static base. Upper tiers compound
        // with straddle planche to confirm horizontal progression beyond the tuck.
        "pl.tuck-planche-pushup": [
            .initiate:   .variant("tuck planche"),
            .novice:     .compound([.variant("tuck planche"), .reps(10, exerciseName: "pseudo-planche pushup")]),
            .apprentice: .reps(1,  exerciseName: "tuck planche pushup"),
            .forged:     .reps(3,  exerciseName: "tuck planche pushup"),
            .veteran:    .reps(5,  exerciseName: "tuck planche pushup"),
            .master:      .reps(7,  exerciseName: "tuck planche pushup"),
            .vessel:     .compound([.reps(7, exerciseName: "tuck planche pushup"), .variant("straddle planche")]),
            .unbound:    .compound([.reps(10, exerciseName: "tuck planche pushup"), .variant("straddle planche")]),
            .ascendant:  .compound([.reps(10, exerciseName: "tuck planche pushup"), .variant("full planche")]),
        ],

        // MARK: - Straddle Planche

        // pl.straddle-planche — Straddle Planche; hold target: 5 s.
        // Hold-type. Legs apart reduces lever arm — harder than tuck but
        // easier than full. Lower tiers cascade through tuck planche hold
        // and pushup volume. Upper tiers compound with full planche to gate
        // forward progression.
        "pl.straddle-planche": [
            .initiate:   .variant("tuck planche"),
            .novice:     .compound([.variant("tuck planche"), .reps(5, exerciseName: "tuck planche pushup")]),
            .apprentice: .variant("straddle planche"),
            .forged:     .compound([.variant("straddle planche"), .reps(5, exerciseName: "tuck planche pushup")]),
            .veteran:    .compound([.variant("straddle planche"), .reps(8, exerciseName: "tuck planche pushup")]),
            .master:      .compound([.variant("straddle planche"), .reps(10, exerciseName: "tuck planche pushup")]),
            .vessel:     .compound([.variant("straddle planche"), .variant("full planche")]),
            .unbound:    .compound([.variant("straddle planche"), .reps(1, exerciseName: "full planche pushup")]),
            .ascendant:  .compound([.variant("straddle planche"), .reps(3, exerciseName: "full planche pushup")]),
        ],

        // MARK: - Full Planche

        // pl.full-planche — Full Planche; hold target: 5 s.
        // Hold-type. Legs together, body fully horizontal — the canonical
        // planche. Lower tiers require straddle planche as prerequisite.
        // Upper tiers compound with full planche pushup — the most direct
        // dynamic confirmation of static hold ownership.
        "pl.full-planche": [
            .initiate:   .variant("straddle planche"),
            .novice:     .compound([.variant("straddle planche"), .reps(5, exerciseName: "tuck planche pushup")]),
            .apprentice: .variant("full planche"),
            .forged:     .compound([.variant("full planche"), .reps(10, exerciseName: "tuck planche pushup")]),
            .veteran:    .compound([.variant("full planche"), .variant("straddle planche")]),
            .master:      .compound([.variant("full planche"), .reps(1, exerciseName: "full planche pushup")]),
            .vessel:     .compound([.variant("full planche"), .reps(2, exerciseName: "full planche pushup")]),
            .unbound:    .compound([.variant("full planche"), .reps(3, exerciseName: "full planche pushup")]),
            .ascendant:  .compound([.variant("full planche"), .reps(5, exerciseName: "full planche pushup")]),
        ],

        // MARK: - Full Planche Push-Up

        // pl.full-planche-pushup — Full Planche Push-Up; anchor: 1 rep = Forged.
        // Rep-type. Elite dynamic planche move. Lower tiers cascade through
        // straddle planche and full planche to confirm static mastery first.
        // Upper tiers compound with full planche hold — you must maintain the
        // static as you scale the dynamic.
        "pl.full-planche-pushup": [
            .initiate:   .variant("straddle planche"),
            .novice:     .variant("full planche"),
            .apprentice: .compound([.variant("full planche"), .reps(5, exerciseName: "tuck planche pushup")]),
            .forged:     .reps(1, exerciseName: "full planche pushup"),
            .veteran:    .reps(2, exerciseName: "full planche pushup"),
            .master:      .reps(3, exerciseName: "full planche pushup"),
            .vessel:     .compound([.reps(3, exerciseName: "full planche pushup"), .variant("full planche")]),
            .unbound:    .compound([.reps(5, exerciseName: "full planche pushup"), .variant("full planche")]),
            .ascendant:  .compound([.reps(5, exerciseName: "full planche pushup"), .reps(1, exerciseName: "90 degree pushup")]),
        ],

        // MARK: - Ninety-Degree Push-Up

        // pl.ninety-degree-pushup — Ninety-Degree Push-Up; anchor: 1 rep = Forged.
        // Rep-type. Straight-arm dip inverted — requires both full planche
        // compression and L-sit / straight-arm pressing power. Lower tiers
        // cascade through full planche hold and pushup volume. Upper tiers
        // compound with full planche pushup confirming the raw planche press.
        "pl.ninety-degree-pushup": [
            .initiate:   .variant("full planche"),
            .novice:     .compound([.variant("full planche"), .reps(3, exerciseName: "full planche pushup")]),
            .apprentice: .compound([.variant("full planche"), .reps(5, exerciseName: "full planche pushup")]),
            .forged:     .reps(1, exerciseName: "90 degree pushup"),
            .veteran:    .reps(2, exerciseName: "90 degree pushup"),
            .master:      .reps(3, exerciseName: "90 degree pushup"),
            .vessel:     .compound([.reps(3, exerciseName: "90 degree pushup"), .reps(3, exerciseName: "full planche pushup")]),
            .unbound:    .compound([.reps(5, exerciseName: "90 degree pushup"), .reps(3, exerciseName: "full planche pushup")]),
            .ascendant:  .compound([.reps(5, exerciseName: "90 degree pushup"), .reps(5, exerciseName: "full planche pushup")]),
        ],

        // MARK: - Bent-Arm Planche

        // pl.bent-arm-planche — Bent Arm Planche; hold target: 3 s.
        // Hold-type. Horizontal planche with elbows bent — diagonal strength
        // bridging tuck and full. Lower tiers require tuck planche and
        // straddle planche to confirm horizontal pressing is established.
        // Upper tiers compound with full planche pushup for dynamic
        // confirmation of the compression strength required.
        "pl.bent-arm-planche": [
            .initiate:   .variant("tuck planche"),
            .novice:     .variant("straddle planche"),
            .apprentice: .variant("bent arm planche"),
            .forged:     .compound([.variant("bent arm planche"), .reps(5, exerciseName: "tuck planche pushup")]),
            .veteran:    .compound([.variant("bent arm planche"), .variant("full planche")]),
            .master:      .compound([.variant("bent arm planche"), .reps(1, exerciseName: "full planche pushup")]),
            .vessel:     .compound([.variant("bent arm planche"), .reps(3, exerciseName: "full planche pushup")]),
            .unbound:    .compound([.variant("bent arm planche"), .reps(5, exerciseName: "full planche pushup")]),
            .ascendant:  .compound([.variant("bent arm planche"), .reps(5, exerciseName: "full planche pushup"), .reps(1, exerciseName: "90 degree pushup")]),
        ],

        // MARK: - Half-Lay Planche

        // pl.half-lay-planche — Half-Lay Planche; hold target: 3 s.
        // Hold-type. One leg extended, one tucked — bridges straddle and full.
        // Lower tiers require straddle planche hold. Upper tiers compound with
        // full planche to confirm the complete lever has been reached.
        "pl.half-lay-planche": [
            .initiate:   .variant("tuck planche"),
            .novice:     .compound([.variant("straddle planche"), .reps(5, exerciseName: "tuck planche pushup")]),
            .apprentice: .variant("half-lay planche"),
            .forged:     .compound([.variant("half-lay planche"), .variant("straddle planche")]),
            .veteran:    .compound([.variant("half-lay planche"), .reps(5, exerciseName: "tuck planche pushup")]),
            .master:      .compound([.variant("half-lay planche"), .variant("full planche")]),
            .vessel:     .compound([.variant("half-lay planche"), .reps(1, exerciseName: "full planche pushup")]),
            .unbound:    .compound([.variant("half-lay planche"), .reps(3, exerciseName: "full planche pushup")]),
            .ascendant:  .compound([.variant("half-lay planche"), .reps(5, exerciseName: "full planche pushup")]),
        ],

        // MARK: - One-Arm Planche

        // pl.one-arm-planche — One-Arm Planche; hold target: 1 s.
        // Hold-type. Mythic. Unilateral full horizontal hold — one of the
        // hardest bodyweight skills in existence. Lower tiers require the
        // complete bilateral planche chain to be deeply owned, including
        // pushup reps on the full planche. Upper tiers compound with the
        // most demanding bilateral exercises. Ascendant confirms world-class
        // bilateral planche mastery alongside any one-arm hold.
        "pl.one-arm-planche": [
            .initiate:   .variant("full planche"),
            .novice:     .compound([.variant("full planche"), .reps(3, exerciseName: "full planche pushup")]),
            .apprentice: .compound([.variant("full planche"), .reps(5, exerciseName: "full planche pushup")]),
            .forged:     .compound([.variant("full planche"), .reps(1, exerciseName: "90 degree pushup")]),
            .veteran:    .variant("one-arm planche"),
            .master:      .compound([.variant("one-arm planche"), .reps(3, exerciseName: "full planche pushup")]),
            .vessel:     .compound([.variant("one-arm planche"), .reps(5, exerciseName: "full planche pushup")]),
            .unbound:    .compound([.variant("one-arm planche"), .reps(3, exerciseName: "90 degree pushup")]),
            .ascendant:  .compound([.variant("one-arm planche"), .reps(5, exerciseName: "full planche pushup"), .reps(3, exerciseName: "90 degree pushup")]),
        ],
    ]
}
