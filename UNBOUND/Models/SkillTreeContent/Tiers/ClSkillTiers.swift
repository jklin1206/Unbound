// UNBOUND/Models/SkillTreeContent/Tiers/ClSkillTiers.swift
//
// Tier criteria for every skill with prefix `cl.` (37 skills).
// Core / lever family. See CalSkillTiers.swift for the established pattern.
//
// Hold-type skills (hollow body, planks, l-sit, v-sit, levers, etc.):
//   .variant("exercise-name") is used for lower tiers since holds are logged
//   as named exercises. Upper tiers compound with a related rep progression
//   to confirm the movement strength underlying the hold.
//
// Lever progressions (front lever, back lever, victorian):
//   Cascade through tuck → straddle → full variant chain, with .compound
//   at upper tiers requiring both the target hold variant AND a supporting
//   compression/pulling rep progression.
//
// Elite/mythic skills (victorian, 360-degree pulls, dragon flag):
//   Cascade through prerequisite variants before reaching the target.

import Foundation

#if DEBUG
private let _clCountCheck: Int = {
    assert(
        ClSkillTiers.table.count == 37,
        "cl cluster should have 37 entries, has \(ClSkillTiers.table.count)"
    )
    for (id, tiers) in ClSkillTiers.table {
        assert(tiers.count == 9, "\(id) needs 9 tiers, has \(tiers.count)")
        for tier in SkillTier.allCases {
            assert(tiers[tier] != nil, "\(id) missing tier \(tier)")
        }
    }
    return ClSkillTiers.table.count
}()
#endif

enum ClSkillTiers {
    static let table: [String: [SkillTier: TierCriterion]] = [

        // MARK: - Hollow Body Core Gate

        // cl.hollow-body-30 — universal core gate; hold-type, duration not tracked.
        // Lower tiers confirm any hollow body training. Upper tiers compound
        // with hanging knee raise to confirm active core strength.
        "cl.hollow-body-30": [
            .initiate:   .variant("hollow body hold"),
            .novice:     .variant("hollow body hold"),
            .apprentice: .variant("hollow body hold"),
            .forged:     .compound([.variant("hollow body hold"), .reps(5, exerciseName: "hanging knee raise")]),
            .veteran:    .compound([.variant("hollow body hold"), .reps(10, exerciseName: "hanging knee raise")]),
            .master:      .compound([.variant("hollow body hold"), .reps(15, exerciseName: "hanging knee raise")]),
            .vessel:     .compound([.variant("hollow body hold"), .reps(20, exerciseName: "hanging knee raise")]),
            .unbound:    .compound([.variant("hollow body hold"), .reps(25, exerciseName: "hanging knee raise")]),
            .ascendant:  .compound([.variant("hollow body hold"), .reps(30, exerciseName: "hanging knee raise")]),
        ],

        // cl.hollow-body-60 — extended hollow body; prereq: cl.hollow-body-30.
        // Starts from compound entry to confirm hollow body + knee raise base.
        // Upper tiers escalate to hanging leg raise for stronger confirmation.
        "cl.hollow-body-60": [
            .initiate:   .variant("hollow body hold"),
            .novice:     .compound([.variant("hollow body hold"), .reps(5, exerciseName: "hanging knee raise")]),
            .apprentice: .compound([.variant("hollow body hold"), .reps(10, exerciseName: "hanging knee raise")]),
            .forged:     .compound([.variant("hollow body hold"), .reps(5, exerciseName: "hanging leg raise")]),
            .veteran:    .compound([.variant("hollow body hold"), .reps(8, exerciseName: "hanging leg raise")]),
            .master:      .compound([.variant("hollow body hold"), .reps(12, exerciseName: "hanging leg raise")]),
            .vessel:     .compound([.variant("hollow body hold"), .reps(15, exerciseName: "hanging leg raise")]),
            .unbound:    .compound([.variant("hollow body hold"), .reps(20, exerciseName: "hanging leg raise")]),
            .ascendant:  .compound([.variant("hollow body hold"), .reps(25, exerciseName: "hanging leg raise")]),
        ],

        // MARK: - Hanging Core

        // cl.hanging-knee-raise — entry-level hang; anchor: 10 reps = Forged
        "cl.hanging-knee-raise": [
            .initiate:   .reps(3,  exerciseName: "hanging knee raise"),
            .novice:     .reps(5,  exerciseName: "hanging knee raise"),
            .apprentice: .reps(8,  exerciseName: "hanging knee raise"),
            .forged:     .reps(10, exerciseName: "hanging knee raise"),
            .veteran:    .reps(15, exerciseName: "hanging knee raise"),
            .master:      .reps(20, exerciseName: "hanging knee raise"),
            .vessel:     .reps(25, exerciseName: "hanging knee raise"),
            .unbound:    .reps(30, exerciseName: "hanging knee raise"),
            .ascendant:  .reps(40, exerciseName: "hanging knee raise"),
        ],

        // cl.hanging-leg-raise — straighter legs = harder; anchor: 10 reps = Forged
        "cl.hanging-leg-raise": [
            .initiate:   .reps(2,  exerciseName: "hanging leg raise"),
            .novice:     .reps(4,  exerciseName: "hanging leg raise"),
            .apprentice: .reps(6,  exerciseName: "hanging leg raise"),
            .forged:     .reps(10, exerciseName: "hanging leg raise"),
            .veteran:    .reps(15, exerciseName: "hanging leg raise"),
            .master:      .reps(20, exerciseName: "hanging leg raise"),
            .vessel:     .reps(25, exerciseName: "hanging leg raise"),
            .unbound:    .reps(30, exerciseName: "hanging leg raise"),
            .ascendant:  .reps(40, exerciseName: "hanging leg raise"),
        ],

        // cl.toes-to-bar — max hip flexion hang; anchor: 5 reps = Forged
        "cl.toes-to-bar": [
            .initiate:   .reps(1,  exerciseName: "toes to bar"),
            .novice:     .reps(2,  exerciseName: "toes to bar"),
            .apprentice: .reps(3,  exerciseName: "toes to bar"),
            .forged:     .reps(5,  exerciseName: "toes to bar"),
            .veteran:    .reps(8,  exerciseName: "toes to bar"),
            .master:      .reps(12, exerciseName: "toes to bar"),
            .vessel:     .reps(15, exerciseName: "toes to bar"),
            .unbound:    .reps(20, exerciseName: "toes to bar"),
            .ascendant:  .reps(25, exerciseName: "toes to bar"),
        ],

        // cl.knee-raise — floor/parallel-bar knee raise entry before hanging work.
        "cl.knee-raise": [
            .initiate:   .reps(5,  exerciseName: "knee raise"),
            .novice:     .reps(8,  exerciseName: "knee raise"),
            .apprentice: .reps(12, exerciseName: "knee raise"),
            .forged:     .reps(15, exerciseName: "knee raise"),
            .veteran:    .reps(20, exerciseName: "knee raise"),
            .master:      .reps(25, exerciseName: "knee raise"),
            .vessel:     .compound([.reps(25, exerciseName: "knee raise"), .reps(8, exerciseName: "hanging knee raise")]),
            .unbound:    .compound([.reps(30, exerciseName: "knee raise"), .reps(12, exerciseName: "hanging knee raise")]),
            .ascendant:  .compound([.reps(40, exerciseName: "knee raise"), .reps(15, exerciseName: "hanging knee raise")]),
        ],

        // cl.leg-raise — straight-leg ground/parallel-bar raise.
        "cl.leg-raise": [
            .initiate:   .reps(3,  exerciseName: "leg raise"),
            .novice:     .reps(5,  exerciseName: "leg raise"),
            .apprentice: .reps(8,  exerciseName: "leg raise"),
            .forged:     .reps(12, exerciseName: "leg raise"),
            .veteran:    .reps(15, exerciseName: "leg raise"),
            .master:      .reps(20, exerciseName: "leg raise"),
            .vessel:     .compound([.reps(20, exerciseName: "leg raise"), .reps(5, exerciseName: "hanging leg raise")]),
            .unbound:    .compound([.reps(25, exerciseName: "leg raise"), .reps(8, exerciseName: "hanging leg raise")]),
            .ascendant:  .compound([.reps(30, exerciseName: "leg raise"), .reps(10, exerciseName: "hanging leg raise")]),
        ],

        // MARK: - Wheel & Flag

        // cl.ab-wheel — standing ab wheel rollout; anchor: 5 reps = Forged
        "cl.ab-wheel": [
            .initiate:   .reps(1,  exerciseName: "ab wheel standing"),
            .novice:     .reps(2,  exerciseName: "ab wheel standing"),
            .apprentice: .reps(3,  exerciseName: "ab wheel standing"),
            .forged:     .reps(5,  exerciseName: "ab wheel standing"),
            .veteran:    .reps(8,  exerciseName: "ab wheel standing"),
            .master:      .reps(12, exerciseName: "ab wheel standing"),
            .vessel:     .reps(15, exerciseName: "ab wheel standing"),
            .unbound:    .reps(20, exerciseName: "ab wheel standing"),
            .ascendant:  .reps(25, exerciseName: "ab wheel standing"),
        ],

        // cl.standing-ab-rollout — live tree ID for the standing ab-wheel rollout.
        "cl.standing-ab-rollout": [
            .initiate:   .reps(1,  exerciseName: "ab wheel standing"),
            .novice:     .reps(2,  exerciseName: "ab wheel standing"),
            .apprentice: .reps(3,  exerciseName: "ab wheel standing"),
            .forged:     .reps(5,  exerciseName: "ab wheel standing"),
            .veteran:    .reps(8,  exerciseName: "ab wheel standing"),
            .master:      .reps(12, exerciseName: "ab wheel standing"),
            .vessel:     .reps(15, exerciseName: "ab wheel standing"),
            .unbound:    .reps(20, exerciseName: "ab wheel standing"),
            .ascendant:  .reps(25, exerciseName: "ab wheel standing"),
        ],

        // cl.dragon-flag-negative — eccentric dragon flag; anchor: 3 reps = Forged.
        // Lower tiers confirm hollow body base and kneeling rollout.
        "cl.dragon-flag-negative": [
            .initiate:   .reps(3,  exerciseName: "ab wheel kneeling"),
            .novice:     .compound([.variant("hollow body hold"), .reps(5, exerciseName: "ab wheel kneeling")]),
            .apprentice: .compound([.variant("hollow body hold"), .reps(8, exerciseName: "ab wheel kneeling")]),
            .forged:     .reps(3,  exerciseName: "dragon flag negative"),
            .veteran:    .reps(5,  exerciseName: "dragon flag negative"),
            .master:      .reps(8,  exerciseName: "dragon flag negative"),
            .vessel:     .reps(10, exerciseName: "dragon flag negative"),
            .unbound:    .reps(12, exerciseName: "dragon flag negative"),
            .ascendant:  .reps(15, exerciseName: "dragon flag negative"),
        ],

        // cl.dragon-flag — full dragon flag; anchor: 5 reps = Forged.
        // Cascade: negatives → dragon flag itself.
        "cl.dragon-flag": [
            .initiate:   .reps(1, exerciseName: "dragon flag negative"),
            .novice:     .reps(3, exerciseName: "dragon flag negative"),
            .apprentice: .reps(5, exerciseName: "dragon flag negative"),
            .forged:     .reps(5, exerciseName: "dragon flag"),
            .veteran:    .reps(7, exerciseName: "dragon flag"),
            .master:      .reps(10, exerciseName: "dragon flag"),
            .vessel:     .reps(12, exerciseName: "dragon flag"),
            .unbound:    .reps(15, exerciseName: "dragon flag"),
            .ascendant:  .reps(20, exerciseName: "dragon flag"),
        ],

        // MARK: - Front Lever Progression

        // cl.tuck-front-lever — entry lever hold; hold-type, duration not tracked.
        // Lower tiers confirm hollow body and hanging leg raise strength.
        "cl.tuck-front-lever": [
            .initiate:   .variant("hollow body hold"),
            .novice:     .compound([.variant("hollow body hold"), .reps(5, exerciseName: "hanging leg raise")]),
            .apprentice: .compound([.variant("hollow body hold"), .reps(10, exerciseName: "hanging leg raise")]),
            .forged:     .variant("tuck front lever"),
            .veteran:    .compound([.variant("tuck front lever"), .reps(5, exerciseName: "hanging leg raise")]),
            .master:      .compound([.variant("tuck front lever"), .reps(10, exerciseName: "hanging leg raise")]),
            .vessel:     .compound([.variant("tuck front lever"), .reps(15, exerciseName: "hanging leg raise")]),
            .unbound:    .compound([.variant("tuck front lever"), .reps(20, exerciseName: "hanging leg raise")]),
            .ascendant:  .compound([.variant("tuck front lever"), .reps(25, exerciseName: "hanging leg raise")]),
        ],

        // cl.straddle-front-lever — mid-progression; anchor: variant = Forged.
        // Cascade: tuck front lever base → straddle variant.
        "cl.straddle-front-lever": [
            .initiate:   .variant("tuck front lever"),
            .novice:     .compound([.variant("tuck front lever"), .reps(5, exerciseName: "toes to bar")]),
            .apprentice: .compound([.variant("tuck front lever"), .reps(8, exerciseName: "toes to bar")]),
            .forged:     .variant("straddle front lever"),
            .veteran:    .compound([.variant("straddle front lever"), .reps(5, exerciseName: "toes to bar")]),
            .master:      .compound([.variant("straddle front lever"), .reps(8, exerciseName: "toes to bar")]),
            .vessel:     .compound([.variant("straddle front lever"), .reps(12, exerciseName: "toes to bar")]),
            .unbound:    .compound([.variant("straddle front lever"), .reps(15, exerciseName: "toes to bar")]),
            .ascendant:  .compound([.variant("straddle front lever"), .reps(20, exerciseName: "toes to bar")]),
        ],

        // cl.full-front-lever — full horizontal hold; anchor: variant = Forged.
        // Cascade: straddle → full front lever.
        "cl.full-front-lever": [
            .initiate:   .variant("tuck front lever"),
            .novice:     .variant("straddle front lever"),
            .apprentice: .compound([.variant("straddle front lever"), .reps(5, exerciseName: "toes to bar")]),
            .forged:     .variant("front lever"),
            .veteran:    .compound([.variant("front lever"), .reps(5, exerciseName: "toes to bar")]),
            .master:      .compound([.variant("front lever"), .reps(8, exerciseName: "toes to bar")]),
            .vessel:     .compound([.variant("front lever"), .reps(12, exerciseName: "toes to bar")]),
            .unbound:    .compound([.variant("front lever"), .reps(15, exerciseName: "toes to bar")]),
            .ascendant:  .compound([.variant("front lever"), .reps(20, exerciseName: "toes to bar")]),
        ],

        // MARK: - Back Lever Progression

        // cl.tuck-back-lever — entry back lever; hold-type, duration not tracked.
        // Lower tiers confirm skin-the-cat and german hang as prerequisite mobility.
        "cl.tuck-back-lever": [
            .initiate:   .variant("german hang"),
            .novice:     .compound([.variant("german hang"), .reps(1, exerciseName: "skin the cat")]),
            .apprentice: .compound([.variant("german hang"), .reps(3, exerciseName: "skin the cat")]),
            .forged:     .variant("tuck back lever"),
            .veteran:    .compound([.variant("tuck back lever"), .reps(3, exerciseName: "skin the cat")]),
            .master:      .compound([.variant("tuck back lever"), .reps(5, exerciseName: "skin the cat")]),
            .vessel:     .compound([.variant("tuck back lever"), .reps(8, exerciseName: "skin the cat")]),
            .unbound:    .compound([.variant("tuck back lever"), .reps(10, exerciseName: "skin the cat")]),
            .ascendant:  .compound([.variant("tuck back lever"), .reps(12, exerciseName: "skin the cat")]),
        ],

        // cl.straddle-back-lever — mid back lever; cascade from tuck.
        "cl.straddle-back-lever": [
            .initiate:   .variant("tuck back lever"),
            .novice:     .compound([.variant("tuck back lever"), .reps(3, exerciseName: "skin the cat")]),
            .apprentice: .compound([.variant("tuck back lever"), .reps(5, exerciseName: "skin the cat")]),
            .forged:     .variant("straddle back lever"),
            .veteran:    .compound([.variant("straddle back lever"), .reps(3, exerciseName: "skin the cat")]),
            .master:      .compound([.variant("straddle back lever"), .reps(5, exerciseName: "skin the cat")]),
            .vessel:     .compound([.variant("straddle back lever"), .reps(8, exerciseName: "skin the cat")]),
            .unbound:    .compound([.variant("straddle back lever"), .reps(10, exerciseName: "skin the cat")]),
            .ascendant:  .compound([.variant("straddle back lever"), .reps(12, exerciseName: "skin the cat")]),
        ],

        // cl.full-back-lever — full back lever; cascade from straddle.
        "cl.full-back-lever": [
            .initiate:   .variant("tuck back lever"),
            .novice:     .variant("straddle back lever"),
            .apprentice: .compound([.variant("straddle back lever"), .reps(5, exerciseName: "skin the cat")]),
            .forged:     .variant("back lever"),
            .veteran:    .compound([.variant("back lever"), .reps(3, exerciseName: "skin the cat")]),
            .master:      .compound([.variant("back lever"), .reps(5, exerciseName: "skin the cat")]),
            .vessel:     .compound([.variant("back lever"), .reps(8, exerciseName: "skin the cat")]),
            .unbound:    .compound([.variant("back lever"), .reps(10, exerciseName: "skin the cat")]),
            .ascendant:  .compound([.variant("back lever"), .reps(12, exerciseName: "skin the cat")]),
        ],

        // MARK: - Victorian (Mythic Hold)

        // cl.victorian — near-impossible inverted support; hold-type, duration not tracked.
        // Cascade through full front lever + full back lever to the victorian itself.
        // Elite mastery: target = 1 s hold.
        "cl.victorian": [
            .initiate:   .variant("tuck front lever"),
            .novice:     .variant("tuck back lever"),
            .apprentice: .compound([.variant("straddle front lever"), .variant("straddle back lever")]),
            .forged:     .compound([.variant("front lever"), .variant("back lever")]),
            .veteran:    .compound([.variant("front lever"), .variant("back lever")]),
            .master:      .variant("victorian"),
            .vessel:     .compound([.variant("victorian"), .reps(5, exerciseName: "toes to bar")]),
            .unbound:    .compound([.variant("victorian"), .reps(10, exerciseName: "toes to bar")]),
            .ascendant:  .compound([.variant("victorian"), .reps(15, exerciseName: "toes to bar")]),
        ],

        // MARK: - Ground Core Basics

        // cl.crunch — standard crunch; anchor: 20 reps = Forged
        "cl.crunch": [
            .initiate:   .reps(5,  exerciseName: "crunch"),
            .novice:     .reps(10, exerciseName: "crunch"),
            .apprentice: .reps(15, exerciseName: "crunch"),
            .forged:     .reps(20, exerciseName: "crunch"),
            .veteran:    .reps(30, exerciseName: "crunch"),
            .master:      .reps(40, exerciseName: "crunch"),
            .vessel:     .reps(55, exerciseName: "crunch"),
            .unbound:    .reps(70, exerciseName: "crunch"),
            .ascendant:  .reps(100, exerciseName: "crunch"),
        ],

        // cl.reverse-crunch — posterior pelvic tilt focus; anchor: 15 reps = Forged
        "cl.reverse-crunch": [
            .initiate:   .reps(5,  exerciseName: "reverse crunch"),
            .novice:     .reps(8,  exerciseName: "reverse crunch"),
            .apprentice: .reps(10, exerciseName: "reverse crunch"),
            .forged:     .reps(15, exerciseName: "reverse crunch"),
            .veteran:    .reps(20, exerciseName: "reverse crunch"),
            .master:      .reps(25, exerciseName: "reverse crunch"),
            .vessel:     .reps(35, exerciseName: "reverse crunch"),
            .unbound:    .reps(45, exerciseName: "reverse crunch"),
            .ascendant:  .reps(60, exerciseName: "reverse crunch"),
        ],

        // cl.straight-crunch — straight-leg crunch; anchor: 20 reps = Forged
        "cl.straight-crunch": [
            .initiate:   .reps(5,  exerciseName: "straight crunch"),
            .novice:     .reps(8,  exerciseName: "straight crunch"),
            .apprentice: .reps(12, exerciseName: "straight crunch"),
            .forged:     .reps(20, exerciseName: "straight crunch"),
            .veteran:    .reps(30, exerciseName: "straight crunch"),
            .master:      .reps(40, exerciseName: "straight crunch"),
            .vessel:     .reps(55, exerciseName: "straight crunch"),
            .unbound:    .reps(70, exerciseName: "straight crunch"),
            .ascendant:  .reps(100, exerciseName: "straight crunch"),
        ],

        // cl.decline-situp — decline bench sit-up; anchor: 15 reps = Forged
        "cl.decline-situp": [
            .initiate:   .reps(5,  exerciseName: "decline sit-up"),
            .novice:     .reps(8,  exerciseName: "decline sit-up"),
            .apprentice: .reps(10, exerciseName: "decline sit-up"),
            .forged:     .reps(15, exerciseName: "decline sit-up"),
            .veteran:    .reps(20, exerciseName: "decline sit-up"),
            .master:      .reps(25, exerciseName: "decline sit-up"),
            .vessel:     .reps(35, exerciseName: "decline sit-up"),
            .unbound:    .reps(45, exerciseName: "decline sit-up"),
            .ascendant:  .reps(60, exerciseName: "decline sit-up"),
        ],

        // MARK: - Plank Variants (Hold-Type)

        // cl.superman-plank — superman extension hold; hold-type.
        // Lower tiers: variant confirms training. Upper tiers compound with
        // bird dog plank for stabiliser confirmation.
        "cl.superman-plank": [
            .initiate:   .variant("superman plank"),
            .novice:     .variant("superman plank"),
            .apprentice: .variant("superman plank"),
            .forged:     .compound([.variant("superman plank"), .variant("bird dog plank")]),
            .veteran:    .compound([.variant("superman plank"), .reps(10, exerciseName: "crunch")]),
            .master:      .compound([.variant("superman plank"), .reps(20, exerciseName: "crunch")]),
            .vessel:     .compound([.variant("superman plank"), .reps(30, exerciseName: "crunch")]),
            .unbound:    .compound([.variant("superman plank"), .reps(40, exerciseName: "crunch")]),
            .ascendant:  .compound([.variant("superman plank"), .reps(50, exerciseName: "crunch")]),
        ],

        // cl.standing-plank — standing plank (wall/bar); hold-type.
        // Upper tiers compound with extended plank for full-hollow confirmation.
        "cl.standing-plank": [
            .initiate:   .variant("standing plank"),
            .novice:     .variant("standing plank"),
            .apprentice: .variant("standing plank"),
            .forged:     .compound([.variant("standing plank"), .variant("hollow body hold")]),
            .veteran:    .compound([.variant("standing plank"), .reps(5, exerciseName: "hanging knee raise")]),
            .master:      .compound([.variant("standing plank"), .reps(10, exerciseName: "hanging knee raise")]),
            .vessel:     .compound([.variant("standing plank"), .reps(15, exerciseName: "hanging knee raise")]),
            .unbound:    .compound([.variant("standing plank"), .reps(20, exerciseName: "hanging knee raise")]),
            .ascendant:  .compound([.variant("standing plank"), .reps(25, exerciseName: "hanging knee raise")]),
        ],

        // cl.extended-plank — longer lever plank; hold-type.
        // Upper tiers compound with ab wheel kneeling for extended compression.
        "cl.extended-plank": [
            .initiate:   .variant("extended plank"),
            .novice:     .variant("extended plank"),
            .apprentice: .variant("extended plank"),
            .forged:     .compound([.variant("extended plank"), .reps(5, exerciseName: "ab wheel kneeling")]),
            .veteran:    .compound([.variant("extended plank"), .reps(8, exerciseName: "ab wheel kneeling")]),
            .master:      .compound([.variant("extended plank"), .reps(12, exerciseName: "ab wheel kneeling")]),
            .vessel:     .compound([.variant("extended plank"), .reps(15, exerciseName: "ab wheel kneeling")]),
            .unbound:    .compound([.variant("extended plank"), .reps(20, exerciseName: "ab wheel kneeling")]),
            .ascendant:  .compound([.variant("extended plank"), .reps(25, exerciseName: "ab wheel kneeling")]),
        ],

        // cl.bird-dog-plank — unilateral stability hold; hold-type.
        // Upper tiers compound with superman plank for cross-body stabiliser.
        "cl.bird-dog-plank": [
            .initiate:   .variant("bird dog plank"),
            .novice:     .variant("bird dog plank"),
            .apprentice: .variant("bird dog plank"),
            .forged:     .compound([.variant("bird dog plank"), .variant("superman plank")]),
            .veteran:    .compound([.variant("bird dog plank"), .reps(10, exerciseName: "reverse crunch")]),
            .master:      .compound([.variant("bird dog plank"), .reps(15, exerciseName: "reverse crunch")]),
            .vessel:     .compound([.variant("bird dog plank"), .reps(20, exerciseName: "reverse crunch")]),
            .unbound:    .compound([.variant("bird dog plank"), .reps(25, exerciseName: "reverse crunch")]),
            .ascendant:  .compound([.variant("bird dog plank"), .reps(30, exerciseName: "reverse crunch")]),
        ],

        // MARK: - Ab Rollout Variants

        // cl.knee-ab-rollout — kneeling ab wheel; anchor: 8 reps = Forged
        "cl.knee-ab-rollout": [
            .initiate:   .reps(2,  exerciseName: "ab wheel kneeling"),
            .novice:     .reps(4,  exerciseName: "ab wheel kneeling"),
            .apprentice: .reps(6,  exerciseName: "ab wheel kneeling"),
            .forged:     .reps(8,  exerciseName: "ab wheel kneeling"),
            .veteran:    .reps(12, exerciseName: "ab wheel kneeling"),
            .master:      .reps(15, exerciseName: "ab wheel kneeling"),
            .vessel:     .reps(20, exerciseName: "ab wheel kneeling"),
            .unbound:    .reps(25, exerciseName: "ab wheel kneeling"),
            .ascendant:  .reps(30, exerciseName: "ab wheel kneeling"),
        ],

        // MARK: - Advanced Core Moves

        // cl.levitation-crunch — hip-float crunch; anchor: 8 reps = Forged.
        // Lower tiers cascade from reverse crunch.
        "cl.levitation-crunch": [
            .initiate:   .reps(5,  exerciseName: "reverse crunch"),
            .novice:     .reps(8,  exerciseName: "reverse crunch"),
            .apprentice: .reps(10, exerciseName: "reverse crunch"),
            .forged:     .reps(8,  exerciseName: "levitation crunch"),
            .veteran:    .reps(10, exerciseName: "levitation crunch"),
            .master:      .reps(12, exerciseName: "levitation crunch"),
            .vessel:     .reps(15, exerciseName: "levitation crunch"),
            .unbound:    .reps(20, exerciseName: "levitation crunch"),
            .ascendant:  .reps(25, exerciseName: "levitation crunch"),
        ],

        // cl.inverted-situp — inverted hang sit-up; anchor: 5 reps = Forged.
        // Lower tiers confirm decline sit-up base.
        "cl.inverted-situp": [
            .initiate:   .reps(3,  exerciseName: "decline sit-up"),
            .novice:     .reps(5,  exerciseName: "decline sit-up"),
            .apprentice: .reps(8,  exerciseName: "decline sit-up"),
            .forged:     .reps(5,  exerciseName: "inverted sit-up"),
            .veteran:    .reps(8,  exerciseName: "inverted sit-up"),
            .master:      .reps(10, exerciseName: "inverted sit-up"),
            .vessel:     .reps(12, exerciseName: "inverted sit-up"),
            .unbound:    .reps(15, exerciseName: "inverted sit-up"),
            .ascendant:  .reps(20, exerciseName: "inverted sit-up"),
        ],

        // MARK: - Shoulder Mobility / Dislocates

        // cl.skin-the-cat — full rotation through hang; anchor: 3 reps = Forged.
        // Lower tiers confirm german hang mobility entry.
        "cl.skin-the-cat": [
            .initiate:   .reps(1, exerciseName: "german hang"),
            .novice:     .variant("german hang"),
            .apprentice: .variant("german hang"),
            .forged:     .reps(3,  exerciseName: "skin the cat"),
            .veteran:    .reps(5,  exerciseName: "skin the cat"),
            .master:      .reps(8,  exerciseName: "skin the cat"),
            .vessel:     .reps(10, exerciseName: "skin the cat"),
            .unbound:    .reps(12, exerciseName: "skin the cat"),
            .ascendant:  .reps(15, exerciseName: "skin the cat"),
        ],

        // cl.german-hang — passive shoulder flexion hold; hold-type.
        // Lower tiers: variant confirms training. Upper tiers compound with
        // skin-the-cat to confirm dynamic shoulder mobility.
        "cl.german-hang": [
            .initiate:   .variant("german hang"),
            .novice:     .variant("german hang"),
            .apprentice: .variant("german hang"),
            .forged:     .compound([.variant("german hang"), .reps(1, exerciseName: "skin the cat")]),
            .veteran:    .compound([.variant("german hang"), .reps(3, exerciseName: "skin the cat")]),
            .master:      .compound([.variant("german hang"), .reps(5, exerciseName: "skin the cat")]),
            .vessel:     .compound([.variant("german hang"), .reps(8, exerciseName: "skin the cat")]),
            .unbound:    .compound([.variant("german hang"), .reps(10, exerciseName: "skin the cat")]),
            .ascendant:  .compound([.variant("german hang"), .reps(12, exerciseName: "skin the cat")]),
        ],

        // MARK: - Explosive Elite

        // cl.three-sixty-pulls — 360° pull; anchor: 1 rep = Forged. Explosive/elite.
        // Cascade from toes-to-bar and hanging leg raise.
        "cl.three-sixty-pulls": [
            .initiate:   .reps(5,  exerciseName: "hanging leg raise"),
            .novice:     .reps(5,  exerciseName: "toes to bar"),
            .apprentice: .reps(10, exerciseName: "toes to bar"),
            .forged:     .reps(1,  exerciseName: "360-degree pulls"),
            .veteran:    .reps(2,  exerciseName: "360-degree pulls"),
            .master:      .reps(3,  exerciseName: "360-degree pulls"),
            .vessel:     .reps(5,  exerciseName: "360-degree pulls"),
            .unbound:    .reps(7,  exerciseName: "360-degree pulls"),
            .ascendant:  .reps(10, exerciseName: "360-degree pulls"),
        ],

        // MARK: - Compression Holds

        // cl.v-sit — v-sit hold; hold-type.
        // Lower tiers cascade from l-sit and straddle l-sit.
        "cl.v-sit": [
            .initiate:   .variant("hollow body hold"),
            .novice:     .compound([.variant("hollow body hold"), .reps(5, exerciseName: "hanging leg raise")]),
            .apprentice: .variant("straddle l-sit"),
            .forged:     .variant("v-sit"),
            .veteran:    .compound([.variant("v-sit"), .reps(5, exerciseName: "toes to bar")]),
            .master:      .compound([.variant("v-sit"), .reps(8, exerciseName: "toes to bar")]),
            .vessel:     .compound([.variant("v-sit"), .reps(12, exerciseName: "toes to bar")]),
            .unbound:    .compound([.variant("v-sit"), .reps(15, exerciseName: "toes to bar")]),
            .ascendant:  .compound([.variant("v-sit"), .reps(20, exerciseName: "toes to bar")]),
        ],

        // cl.straddle-l-sit — straddled l-sit hold; hold-type.
        // Lower tiers use hollow body + hanging leg raise; upper tiers compound
        // with toes-to-bar for hip flexor depth confirmation.
        "cl.straddle-l-sit": [
            .initiate:   .variant("hollow body hold"),
            .novice:     .compound([.variant("hollow body hold"), .reps(5, exerciseName: "hanging knee raise")]),
            .apprentice: .compound([.variant("hollow body hold"), .reps(5, exerciseName: "hanging leg raise")]),
            .forged:     .variant("straddle l-sit"),
            .veteran:    .compound([.variant("straddle l-sit"), .reps(5, exerciseName: "hanging leg raise")]),
            .master:      .compound([.variant("straddle l-sit"), .reps(8, exerciseName: "hanging leg raise")]),
            .vessel:     .compound([.variant("straddle l-sit"), .reps(12, exerciseName: "hanging leg raise")]),
            .unbound:    .compound([.variant("straddle l-sit"), .reps(15, exerciseName: "hanging leg raise")]),
            .ascendant:  .compound([.variant("straddle l-sit"), .reps(20, exerciseName: "hanging leg raise")]),
        ],

        // cl.semi-straddle-l-sit — bridge between L-sit and straddle L-sit.
        "cl.semi-straddle-l-sit": [
            .initiate:   .variant("l-sit"),
            .novice:     .compound([.variant("l-sit"), .reps(5, exerciseName: "leg raise")]),
            .apprentice: .compound([.variant("l-sit"), .reps(10, exerciseName: "leg raise")]),
            .forged:     .variant("semi-straddle l-sit"),
            .veteran:    .compound([.variant("semi-straddle l-sit"), .reps(5, exerciseName: "hanging leg raise")]),
            .master:      .compound([.variant("semi-straddle l-sit"), .reps(8, exerciseName: "hanging leg raise")]),
            .vessel:     .compound([.variant("semi-straddle l-sit"), .variant("straddle l-sit")]),
            .unbound:    .compound([.variant("semi-straddle l-sit"), .reps(12, exerciseName: "hanging leg raise")]),
            .ascendant:  .compound([.variant("semi-straddle l-sit"), .reps(15, exerciseName: "toes to bar")]),
        ],

        // cl.vertical-l-sit — highest compression L-sit family member.
        "cl.vertical-l-sit": [
            .initiate:   .variant("straddle l-sit"),
            .novice:     .compound([.variant("straddle l-sit"), .reps(5, exerciseName: "hanging leg raise")]),
            .apprentice: .variant("v-sit"),
            .forged:     .variant("vertical l-sit"),
            .veteran:    .compound([.variant("vertical l-sit"), .reps(5, exerciseName: "toes to bar")]),
            .master:      .compound([.variant("vertical l-sit"), .reps(8, exerciseName: "toes to bar")]),
            .vessel:     .compound([.variant("vertical l-sit"), .reps(12, exerciseName: "toes to bar")]),
            .unbound:    .compound([.variant("vertical l-sit"), .reps(15, exerciseName: "toes to bar")]),
            .ascendant:  .compound([.variant("vertical l-sit"), .reps(20, exerciseName: "toes to bar")]),
        ],

        // MARK: - Dragon Flag Hip Raise

        // cl.dragon-flag-hip-raise — partial dragon flag range; anchor: 8 reps = Forged.
        // Bridge between reverse crunch and dragon flag negatives.
        "cl.dragon-flag-hip-raise": [
            .initiate:   .reps(3,  exerciseName: "reverse crunch"),
            .novice:     .reps(5,  exerciseName: "reverse crunch"),
            .apprentice: .reps(8,  exerciseName: "reverse crunch"),
            .forged:     .reps(8,  exerciseName: "dragon flag hip raise"),
            .veteran:    .reps(10, exerciseName: "dragon flag hip raise"),
            .master:      .reps(12, exerciseName: "dragon flag hip raise"),
            .vessel:     .reps(15, exerciseName: "dragon flag hip raise"),
            .unbound:    .reps(20, exerciseName: "dragon flag hip raise"),
            .ascendant:  .reps(25, exerciseName: "dragon flag hip raise"),
        ],
    ]
}
