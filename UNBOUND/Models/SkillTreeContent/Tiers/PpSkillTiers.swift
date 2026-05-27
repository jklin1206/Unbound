// UNBOUND/Models/SkillTreeContent/Tiers/PpSkillTiers.swift
//
// Tier criteria for every skill with prefix `pp.` (38 skills).
// Pull/chin/muscle-up/row family. See CalSkillTiers.swift for the pattern.
//
// Hold-type skills (pp.dead-hang-30):
//   .variant("dead hang") confirms any hang training. Duration is not tracked
//   per SetLog. Upper tiers compound with pullup volume, mirroring the co.*
//   dead-hang pattern.
//
// Weighted skills (weighted-pullup-0.25, weighted-pullup-0.5, weighted-chin-up):
//   Uses .exerciseBodyweightRatio(r, exerciseName: name) so the load ratio
//   is measured only from the intended weighted exercise.
//
// One-arm pullup: a once-in-a-decade move. Initiate already demands strong
//   prerequisites (archer pullup base); Ascendant compounds the OAP rep
//   target with weighted pullup volume.
//
// 5-pullups vs 10-pullups: both target "pullup" but are distinct ladders.
//   5-pullups: 1→15 reps (Initiate→Ascendant), anchored on the first real
//   volume checkpoint. 10-pullups: 3→25+ reps, anchored on elite volume.

import Foundation

#if DEBUG
private let _ppCountCheck: Int = {
    assert(
        PpSkillTiers.table.count == 38,
        "pp cluster should have 38 entries, has \(PpSkillTiers.table.count)"
    )
    for (id, tiers) in PpSkillTiers.table {
        assert(tiers.count == 9, "\(id) needs 9 tiers, has \(tiers.count)")
        for tier in SkillTier.allCases {
            assert(tiers[tier] != nil, "\(id) missing tier \(tier)")
        }
    }
    return PpSkillTiers.table.count
}()
#endif

enum PpSkillTiers {
    static let table: [String: [SkillTier: TierCriterion]] = [

        // MARK: - The Grip

        // pp.dead-hang-30 — Hold-type (30 s target). Duration not tracked per
        // SetLog. Lower tiers confirm any dead hang training. Upper tiers
        // compound with pullup volume to confirm grip + pulling strength.
        "pp.dead-hang-30": [
            .initiate:   .variant("dead hang"),
            .novice:     .variant("dead hang"),
            .apprentice: .variant("dead hang"),
            .forged:     .compound([.variant("dead hang"), .reps(3,  exerciseName: "pullup")]),
            .veteran:    .compound([.variant("dead hang"), .reps(5,  exerciseName: "pullup")]),
            .master:      .compound([.variant("dead hang"), .reps(8,  exerciseName: "pullup")]),
            .vessel:     .compound([.variant("dead hang"), .reps(10, exerciseName: "pullup")]),
            .unbound:    .compound([.variant("dead hang"), .reps(12, exerciseName: "pullup")]),
            .ascendant:  .compound([.variant("dead hang"), .reps(15, exerciseName: "pullup")]),
        ],

        // pp.dead-hang — live pull-tree ID for the same grip gate.
        "pp.dead-hang": [
            .initiate:   .variant("dead hang"),
            .novice:     .variant("dead hang"),
            .apprentice: .variant("dead hang"),
            .forged:     .compound([.variant("dead hang"), .reps(3,  exerciseName: "pullup")]),
            .veteran:    .compound([.variant("dead hang"), .reps(5,  exerciseName: "pullup")]),
            .master:      .compound([.variant("dead hang"), .reps(8,  exerciseName: "pullup")]),
            .vessel:     .compound([.variant("dead hang"), .reps(10, exerciseName: "pullup")]),
            .unbound:    .compound([.variant("dead hang"), .reps(12, exerciseName: "pullup")]),
            .ascendant:  .compound([.variant("dead hang"), .reps(15, exerciseName: "pullup")]),
        ],

        // pp.negative-pullup — 3-rep target. Eccentric-only pull.
        // Anchor: 3 reps = Forged.
        "pp.negative-pullup": [
            .initiate:   .reps(1,  exerciseName: "negative pullup"),
            .novice:     .reps(2,  exerciseName: "negative pullup"),
            .apprentice: .reps(3,  exerciseName: "negative pullup"),
            .forged:     .reps(5,  exerciseName: "negative pullup"),
            .veteran:    .reps(8,  exerciseName: "negative pullup"),
            .master:      .reps(10, exerciseName: "negative pullup"),
            .vessel:     .reps(12, exerciseName: "negative pullup"),
            .unbound:    .reps(15, exerciseName: "negative pullup"),
            .ascendant:  .reps(20, exerciseName: "negative pullup"),
        ],

        // MARK: - Ascent

        // pp.pullup — First Pull-Up. anchor: 1 rep = Forged (the "first rep" node).
        // Initiate confirms the pullup is logged at all; Ascendant = 12 strict.
        "pp.pullup": [
            .initiate:   .reps(1,  exerciseName: "pullup"),
            .novice:     .reps(2,  exerciseName: "pullup"),
            .apprentice: .reps(3,  exerciseName: "pullup"),
            .forged:     .reps(5,  exerciseName: "pullup"),
            .veteran:    .reps(7,  exerciseName: "pullup"),
            .master:      .reps(8,  exerciseName: "pullup"),
            .vessel:     .reps(10, exerciseName: "pullup"),
            .unbound:    .reps(11, exerciseName: "pullup"),
            .ascendant:  .reps(12, exerciseName: "pullup"),
        ],

        // pp.5-pullups — Pull-Up (volume ladder 1→15).
        // Distinct from 10-pullups: tops at 15 reps Ascendant.
        "pp.5-pullups": [
            .initiate:   .reps(1,  exerciseName: "pullup"),
            .novice:     .reps(2,  exerciseName: "pullup"),
            .apprentice: .reps(3,  exerciseName: "pullup"),
            .forged:     .reps(5,  exerciseName: "pullup"),
            .veteran:    .reps(7,  exerciseName: "pullup"),
            .master:      .reps(9,  exerciseName: "pullup"),
            .vessel:     .reps(11, exerciseName: "pullup"),
            .unbound:    .reps(13, exerciseName: "pullup"),
            .ascendant:  .reps(15, exerciseName: "pullup"),
        ],

        // pp.10-pullups — Pull-Up Volume (elite ladder 3→25+).
        // Distinct from 5-pullups: starts at 3 reps Initiate, tops at 25+ Ascendant.
        "pp.10-pullups": [
            .initiate:   .reps(3,  exerciseName: "pullup"),
            .novice:     .reps(5,  exerciseName: "pullup"),
            .apprentice: .reps(7,  exerciseName: "pullup"),
            .forged:     .reps(10, exerciseName: "pullup"),
            .veteran:    .reps(13, exerciseName: "pullup"),
            .master:      .reps(16, exerciseName: "pullup"),
            .vessel:     .reps(19, exerciseName: "pullup"),
            .unbound:    .reps(22, exerciseName: "pullup"),
            .ascendant:  .reps(25, exerciseName: "pullup"),
        ],

        // pp.slow-pullup — Tempo Pull-Up. 5-rep anchor = Forged.
        "pp.slow-pullup": [
            .initiate:   .reps(1,  exerciseName: "slow pullup"),
            .novice:     .reps(2,  exerciseName: "slow pullup"),
            .apprentice: .reps(3,  exerciseName: "slow pullup"),
            .forged:     .reps(5,  exerciseName: "slow pullup"),
            .veteran:    .reps(7,  exerciseName: "slow pullup"),
            .master:      .reps(9,  exerciseName: "slow pullup"),
            .vessel:     .reps(12, exerciseName: "slow pullup"),
            .unbound:    .reps(15, exerciseName: "slow pullup"),
            .ascendant:  .reps(20, exerciseName: "slow pullup"),
        ],

        // pp.chest-to-bar — Chest-to-Bar Pull-Up. 5-rep anchor = Forged.
        "pp.chest-to-bar": [
            .initiate:   .reps(1,  exerciseName: "chest-to-bar pullup"),
            .novice:     .reps(2,  exerciseName: "chest-to-bar pullup"),
            .apprentice: .reps(3,  exerciseName: "chest-to-bar pullup"),
            .forged:     .reps(5,  exerciseName: "chest-to-bar pullup"),
            .veteran:    .reps(7,  exerciseName: "chest-to-bar pullup"),
            .master:      .reps(9,  exerciseName: "chest-to-bar pullup"),
            .vessel:     .reps(12, exerciseName: "chest-to-bar pullup"),
            .unbound:    .reps(15, exerciseName: "chest-to-bar pullup"),
            .ascendant:  .reps(20, exerciseName: "chest-to-bar pullup"),
        ],

        // pp.l-sit-pullup — L-Sit Pull-Up. 5-rep anchor = Forged.
        "pp.l-sit-pullup": [
            .initiate:   .reps(1,  exerciseName: "l-sit pullup"),
            .novice:     .reps(2,  exerciseName: "l-sit pullup"),
            .apprentice: .reps(3,  exerciseName: "l-sit pullup"),
            .forged:     .reps(5,  exerciseName: "l-sit pullup"),
            .veteran:    .reps(7,  exerciseName: "l-sit pullup"),
            .master:      .reps(8,  exerciseName: "l-sit pullup"),
            .vessel:     .reps(10, exerciseName: "l-sit pullup"),
            .unbound:    .reps(12, exerciseName: "l-sit pullup"),
            .ascendant:  .reps(15, exerciseName: "l-sit pullup"),
        ],

        // pp.archer-pullup — Archer Pull-Up. 3-rep anchor = Forged.
        // On-ramp to the one-arm chain.
        "pp.archer-pullup": [
            .initiate:   .reps(1,  exerciseName: "archer pullup"),
            .novice:     .reps(2,  exerciseName: "archer pullup"),
            .apprentice: .reps(3,  exerciseName: "archer pullup"),
            .forged:     .reps(4,  exerciseName: "archer pullup"),
            .veteran:    .reps(5,  exerciseName: "archer pullup"),
            .master:      .reps(7,  exerciseName: "archer pullup"),
            .vessel:     .reps(9,  exerciseName: "archer pullup"),
            .unbound:    .reps(12, exerciseName: "archer pullup"),
            .ascendant:  .reps(15, exerciseName: "archer pullup"),
        ],

        // pp.weighted-pullup-0.25 — Weighted Pull-Up (0.25× bw).
        // Uses .compound to confirm the exercise before checking the bw ratio.
        // Ladder climbs from first logged rep → 1.0× bodyweight.
        "pp.weighted-pullup-0.25": [
            .initiate:   .variant("weighted pullup"),
            .novice:     .exerciseBodyweightRatio(0.10, exerciseName: "weighted pullup"),
            .apprentice: .exerciseBodyweightRatio(0.15, exerciseName: "weighted pullup"),
            .forged:     .exerciseBodyweightRatio(0.25, exerciseName: "weighted pullup"),
            .veteran:    .exerciseBodyweightRatio(0.35, exerciseName: "weighted pullup"),
            .master:      .exerciseBodyweightRatio(0.50, exerciseName: "weighted pullup"),
            .vessel:     .exerciseBodyweightRatio(0.65, exerciseName: "weighted pullup"),
            .unbound:    .exerciseBodyweightRatio(0.80, exerciseName: "weighted pullup"),
            .ascendant:  .exerciseBodyweightRatio(1.00, exerciseName: "weighted pullup"),
        ],

        // pp.weighted-pullup-0.5 — Heavy Pull-Up (0.5× bw).
        // Prereq: weighted-pullup-0.25. Ladder starts at 0.25× and climbs to 1.25×.
        "pp.weighted-pullup-0.5": [
            .initiate:   .exerciseBodyweightRatio(0.10, exerciseName: "weighted pullup"),
            .novice:     .exerciseBodyweightRatio(0.20, exerciseName: "weighted pullup"),
            .apprentice: .exerciseBodyweightRatio(0.35, exerciseName: "weighted pullup"),
            .forged:     .exerciseBodyweightRatio(0.50, exerciseName: "weighted pullup"),
            .veteran:    .exerciseBodyweightRatio(0.65, exerciseName: "weighted pullup"),
            .master:      .exerciseBodyweightRatio(0.80, exerciseName: "weighted pullup"),
            .vessel:     .exerciseBodyweightRatio(0.90, exerciseName: "weighted pullup"),
            .unbound:    .exerciseBodyweightRatio(1.00, exerciseName: "weighted pullup"),
            .ascendant:  .exerciseBodyweightRatio(1.25, exerciseName: "weighted pullup"),
        ],

        // pp.weighted-pullup — live tree ID. Starts at the first logged weighted
        // pull and uses exercise-scoped load ratio to avoid unrelated heavy lifts.
        "pp.weighted-pullup": [
            .initiate:   .variant("weighted pullup"),
            .novice:     .exerciseBodyweightRatio(0.10, exerciseName: "weighted pullup"),
            .apprentice: .exerciseBodyweightRatio(0.20, exerciseName: "weighted pullup"),
            .forged:     .exerciseBodyweightRatio(0.35, exerciseName: "weighted pullup"),
            .veteran:    .exerciseBodyweightRatio(0.50, exerciseName: "weighted pullup"),
            .master:      .exerciseBodyweightRatio(0.65, exerciseName: "weighted pullup"),
            .vessel:     .exerciseBodyweightRatio(0.80, exerciseName: "weighted pullup"),
            .unbound:    .exerciseBodyweightRatio(1.00, exerciseName: "weighted pullup"),
            .ascendant:  .exerciseBodyweightRatio(1.25, exerciseName: "weighted pullup"),
        ],

        // pp.typewriter-pullup — Typewriter Pull-Up. 3-rep anchor = Forged.
        // Bridge between archer pullup and the one-arm chain.
        "pp.typewriter-pullup": [
            .initiate:   .reps(1,  exerciseName: "typewriter pullup"),
            .novice:     .reps(2,  exerciseName: "typewriter pullup"),
            .apprentice: .reps(3,  exerciseName: "typewriter pullup"),
            .forged:     .reps(4,  exerciseName: "typewriter pullup"),
            .veteran:    .reps(5,  exerciseName: "typewriter pullup"),
            .master:      .reps(6,  exerciseName: "typewriter pullup"),
            .vessel:     .reps(7,  exerciseName: "typewriter pullup"),
            .unbound:    .reps(9,  exerciseName: "typewriter pullup"),
            .ascendant:  .reps(12, exerciseName: "typewriter pullup"),
        ],

        // MARK: - Solo Arm

        // pp.oap-negative — One-Arm Pull-Up Negative. 3-rep anchor = Forged.
        // Last step before the full OAP.
        "pp.oap-negative": [
            .initiate:   .reps(1,  exerciseName: "one-arm pullup negative"),
            .novice:     .reps(2,  exerciseName: "one-arm pullup negative"),
            .apprentice: .reps(3,  exerciseName: "one-arm pullup negative"),
            .forged:     .reps(4,  exerciseName: "one-arm pullup negative"),
            .veteran:    .reps(5,  exerciseName: "one-arm pullup negative"),
            .master:      .reps(6,  exerciseName: "one-arm pullup negative"),
            .vessel:     .reps(7,  exerciseName: "one-arm pullup negative"),
            .unbound:    .reps(9,  exerciseName: "one-arm pullup negative"),
            .ascendant:  .reps(12, exerciseName: "one-arm pullup negative"),
        ],

        // pp.one-arm-pullup — One-Arm Pull-Up. Once-in-a-decade move.
        // Initiate already requires reaching the OAP itself. Ascendant compounds
        // the OAP rep target with weighted pullup volume to signal full mastery.
        "pp.one-arm-pullup": [
            .initiate:   .reps(1,  exerciseName: "one-arm pullup"),
            .novice:     .reps(1,  exerciseName: "one-arm pullup"),
            .apprentice: .reps(2,  exerciseName: "one-arm pullup"),
            .forged:     .reps(3,  exerciseName: "one-arm pullup"),
            .veteran:    .reps(4,  exerciseName: "one-arm pullup"),
            .master:      .reps(5,  exerciseName: "one-arm pullup"),
            .vessel:     .reps(6,  exerciseName: "one-arm pullup"),
            .unbound:    .compound([.reps(8, exerciseName: "one-arm pullup"), .exerciseBodyweightRatio(0.5, exerciseName: "weighted pullup")]),
            .ascendant:  .compound([.reps(10, exerciseName: "one-arm pullup"), .exerciseBodyweightRatio(0.75, exerciseName: "weighted pullup")]),
        ],

        // MARK: - Crossover

        // pp.muscle-up — Muscle-Up. Hard-skill ladder: lower tiers track
        // objective readiness/assistance gates, first real rep lands at Forged.
        "pp.muscle-up": [
            .initiate:   .compound([.reps(5, exerciseName: "pullup"), .reps(5, exerciseName: "straight bar dip")]),
            .novice:     .compound([.reps(3, exerciseName: "chest-to-bar pullup"), .variant("straight bar dip")]),
            .apprentice: .compound([.reps(3, exerciseName: "banded muscle-up"), .variant("low-bar muscle-up transition")]),
            .forged:     .reps(1,  exerciseName: "muscle-up"),
            .veteran:    .reps(2,  exerciseName: "muscle-up"),
            .master:      .reps(5,  exerciseName: "muscle-up"),
            .vessel:     .reps(8,  exerciseName: "muscle-up"),
            .unbound:    .reps(10, exerciseName: "muscle-up"),
            .ascendant:  .reps(12, exerciseName: "muscle-up"),
        ],

        // pp.10-muscle-ups — Muscle-Up Volume. anchor: 10 reps = Forged.
        "pp.10-muscle-ups": [
            .initiate:   .reps(3,  exerciseName: "muscle-up"),
            .novice:     .reps(5,  exerciseName: "muscle-up"),
            .apprentice: .reps(7,  exerciseName: "muscle-up"),
            .forged:     .reps(10, exerciseName: "muscle-up"),
            .veteran:    .reps(12, exerciseName: "muscle-up"),
            .master:      .reps(14, exerciseName: "muscle-up"),
            .vessel:     .reps(16, exerciseName: "muscle-up"),
            .unbound:    .reps(18, exerciseName: "muscle-up"),
            .ascendant:  .reps(20, exerciseName: "muscle-up"),
        ],

        // pp.ring-muscle-up — Ring Muscle-Up. anchor: 1 rep = Forged.
        "pp.ring-muscle-up": [
            .initiate:   .reps(1,  exerciseName: "ring muscle-up"),
            .novice:     .reps(2,  exerciseName: "ring muscle-up"),
            .apprentice: .reps(3,  exerciseName: "ring muscle-up"),
            .forged:     .reps(4,  exerciseName: "ring muscle-up"),
            .veteran:    .reps(5,  exerciseName: "ring muscle-up"),
            .master:      .reps(6,  exerciseName: "ring muscle-up"),
            .vessel:     .reps(8,  exerciseName: "ring muscle-up"),
            .unbound:    .reps(10, exerciseName: "ring muscle-up"),
            .ascendant:  .reps(12, exerciseName: "ring muscle-up"),
        ],

        // pp.5-oap-side — One-Arm Pull-Up Volume (Mythic). anchor: 5 reps = Forged.
        "pp.5-oap-side": [
            .initiate:   .reps(1,  exerciseName: "one-arm pullup"),
            .novice:     .reps(2,  exerciseName: "one-arm pullup"),
            .apprentice: .reps(3,  exerciseName: "one-arm pullup"),
            .forged:     .reps(5,  exerciseName: "one-arm pullup"),
            .veteran:    .reps(6,  exerciseName: "one-arm pullup"),
            .master:      .reps(7,  exerciseName: "one-arm pullup"),
            .vessel:     .reps(8,  exerciseName: "one-arm pullup"),
            .unbound:    .reps(9,  exerciseName: "one-arm pullup"),
            .ascendant:  .reps(10, exerciseName: "one-arm pullup"),
        ],

        // pp.explosive-pullup — Explosive Pull-Up. anchor: 3 reps = Forged.
        "pp.explosive-pullup": [
            .initiate:   .reps(1,  exerciseName: "explosive pullup"),
            .novice:     .reps(2,  exerciseName: "explosive pullup"),
            .apprentice: .reps(3,  exerciseName: "explosive pullup"),
            .forged:     .reps(4,  exerciseName: "explosive pullup"),
            .veteran:    .reps(5,  exerciseName: "explosive pullup"),
            .master:      .reps(6,  exerciseName: "explosive pullup"),
            .vessel:     .reps(8,  exerciseName: "explosive pullup"),
            .unbound:    .reps(10, exerciseName: "explosive pullup"),
            .ascendant:  .reps(12, exerciseName: "explosive pullup"),
        ],

        // pp.plyometric-pullup — Plyometric Pull-Up. anchor: 3 reps = Forged.
        "pp.plyometric-pullup": [
            .initiate:   .reps(1,  exerciseName: "plyometric pullup"),
            .novice:     .reps(2,  exerciseName: "plyometric pullup"),
            .apprentice: .reps(3,  exerciseName: "plyometric pullup"),
            .forged:     .reps(4,  exerciseName: "plyometric pullup"),
            .veteran:    .reps(5,  exerciseName: "plyometric pullup"),
            .master:      .reps(6,  exerciseName: "plyometric pullup"),
            .vessel:     .reps(8,  exerciseName: "plyometric pullup"),
            .unbound:    .reps(10, exerciseName: "plyometric pullup"),
            .ascendant:  .reps(12, exerciseName: "plyometric pullup"),
        ],

        // pp.clapping-pullup — Clapping Pull-Up. anchor: 1 rep = Forged.
        "pp.clapping-pullup": [
            .initiate:   .reps(1,  exerciseName: "clapping pullup"),
            .novice:     .reps(2,  exerciseName: "clapping pullup"),
            .apprentice: .reps(3,  exerciseName: "clapping pullup"),
            .forged:     .reps(4,  exerciseName: "clapping pullup"),
            .veteran:    .reps(5,  exerciseName: "clapping pullup"),
            .master:      .reps(6,  exerciseName: "clapping pullup"),
            .vessel:     .reps(7,  exerciseName: "clapping pullup"),
            .unbound:    .reps(9,  exerciseName: "clapping pullup"),
            .ascendant:  .reps(12, exerciseName: "clapping pullup"),
        ],

        // MARK: - Chin-Up Chain

        // pp.chin-up — Chin-Up. anchor: 1 rep = Forged.
        "pp.chin-up": [
            .initiate:   .reps(1,  exerciseName: "chin-up"),
            .novice:     .reps(2,  exerciseName: "chin-up"),
            .apprentice: .reps(3,  exerciseName: "chin-up"),
            .forged:     .reps(5,  exerciseName: "chin-up"),
            .veteran:    .reps(7,  exerciseName: "chin-up"),
            .master:      .reps(8,  exerciseName: "chin-up"),
            .vessel:     .reps(10, exerciseName: "chin-up"),
            .unbound:    .reps(11, exerciseName: "chin-up"),
            .ascendant:  .reps(12, exerciseName: "chin-up"),
        ],

        // pp.strict-chin-up — Strict Chin-Up. anchor: 8 reps = Forged.
        "pp.strict-chin-up": [
            .initiate:   .reps(1,  exerciseName: "chin-up"),
            .novice:     .reps(3,  exerciseName: "chin-up"),
            .apprentice: .reps(5,  exerciseName: "chin-up"),
            .forged:     .reps(8,  exerciseName: "chin-up"),
            .veteran:    .reps(10, exerciseName: "chin-up"),
            .master:      .reps(12, exerciseName: "chin-up"),
            .vessel:     .reps(15, exerciseName: "chin-up"),
            .unbound:    .reps(18, exerciseName: "chin-up"),
            .ascendant:  .reps(20, exerciseName: "chin-up"),
        ],

        // pp.weighted-chin-up — Weighted Chin-Up (0.25× bw target).
        // Uses .compound to confirm the exercise before checking the bw ratio.
        // Ladder climbs from first logged rep → 1.0× bodyweight.
        "pp.weighted-chin-up": [
            .initiate:   .variant("weighted chin-up"),
            .novice:     .exerciseBodyweightRatio(0.10, exerciseName: "weighted chin-up"),
            .apprentice: .exerciseBodyweightRatio(0.15, exerciseName: "weighted chin-up"),
            .forged:     .exerciseBodyweightRatio(0.25, exerciseName: "weighted chin-up"),
            .veteran:    .exerciseBodyweightRatio(0.35, exerciseName: "weighted chin-up"),
            .master:      .exerciseBodyweightRatio(0.50, exerciseName: "weighted chin-up"),
            .vessel:     .exerciseBodyweightRatio(0.65, exerciseName: "weighted chin-up"),
            .unbound:    .exerciseBodyweightRatio(0.80, exerciseName: "weighted chin-up"),
            .ascendant:  .exerciseBodyweightRatio(1.00, exerciseName: "weighted chin-up"),
        ],

        // pp.l-sit-chin-up — L-Sit Chin-Up. anchor: 3 reps = Forged.
        "pp.l-sit-chin-up": [
            .initiate:   .reps(1,  exerciseName: "l-sit chin-up"),
            .novice:     .reps(2,  exerciseName: "l-sit chin-up"),
            .apprentice: .reps(3,  exerciseName: "l-sit chin-up"),
            .forged:     .reps(4,  exerciseName: "l-sit chin-up"),
            .veteran:    .reps(5,  exerciseName: "l-sit chin-up"),
            .master:      .reps(6,  exerciseName: "l-sit chin-up"),
            .vessel:     .reps(7,  exerciseName: "l-sit chin-up"),
            .unbound:    .reps(9,  exerciseName: "l-sit chin-up"),
            .ascendant:  .reps(12, exerciseName: "l-sit chin-up"),
        ],

        // pp.wide-pullup — Wide Pull-Up. anchor: 5 reps = Forged.
        "pp.wide-pullup": [
            .initiate:   .reps(1,  exerciseName: "wide pullup"),
            .novice:     .reps(2,  exerciseName: "wide pullup"),
            .apprentice: .reps(3,  exerciseName: "wide pullup"),
            .forged:     .reps(5,  exerciseName: "wide pullup"),
            .veteran:    .reps(7,  exerciseName: "wide pullup"),
            .master:      .reps(9,  exerciseName: "wide pullup"),
            .vessel:     .reps(12, exerciseName: "wide pullup"),
            .unbound:    .reps(15, exerciseName: "wide pullup"),
            .ascendant:  .reps(20, exerciseName: "wide pullup"),
        ],

        // pp.heighted-chin-up — Heighted Chin-Up. anchor: 3 reps = Forged.
        // Solo Arm on-ramp on the chin-up chain.
        "pp.heighted-chin-up": [
            .initiate:   .reps(1,  exerciseName: "heighted chin-up"),
            .novice:     .reps(2,  exerciseName: "heighted chin-up"),
            .apprentice: .reps(3,  exerciseName: "heighted chin-up"),
            .forged:     .reps(4,  exerciseName: "heighted chin-up"),
            .veteran:    .reps(5,  exerciseName: "heighted chin-up"),
            .master:      .reps(6,  exerciseName: "heighted chin-up"),
            .vessel:     .reps(7,  exerciseName: "heighted chin-up"),
            .unbound:    .reps(9,  exerciseName: "heighted chin-up"),
            .ascendant:  .reps(12, exerciseName: "heighted chin-up"),
        ],

        // pp.one-arm-chin-up — One-Arm Chin-Up. anchor: 1 rep = Forged. Mythic.
        "pp.one-arm-chin-up": [
            .initiate:   .reps(1, exerciseName: "one-arm chin-up"),
            .novice:     .reps(1, exerciseName: "one-arm chin-up"),
            .apprentice: .reps(2, exerciseName: "one-arm chin-up"),
            .forged:     .reps(3, exerciseName: "one-arm chin-up"),
            .veteran:    .reps(4, exerciseName: "one-arm chin-up"),
            .master:      .reps(5, exerciseName: "one-arm chin-up"),
            .vessel:     .reps(6, exerciseName: "one-arm chin-up"),
            .unbound:    .reps(7, exerciseName: "one-arm chin-up"),
            .ascendant:  .reps(8, exerciseName: "one-arm chin-up"),
        ],

        // pp.strict-muscle-up — Strict Muscle-Up. anchor: 1 rep = Forged. Mythic.
        "pp.strict-muscle-up": [
            .initiate:   .reps(1, exerciseName: "strict muscle-up"),
            .novice:     .reps(1, exerciseName: "strict muscle-up"),
            .apprentice: .reps(2, exerciseName: "strict muscle-up"),
            .forged:     .reps(3, exerciseName: "strict muscle-up"),
            .veteran:    .reps(4, exerciseName: "strict muscle-up"),
            .master:      .reps(5, exerciseName: "strict muscle-up"),
            .vessel:     .reps(6, exerciseName: "strict muscle-up"),
            .unbound:    .reps(7, exerciseName: "strict muscle-up"),
            .ascendant:  .reps(8, exerciseName: "strict muscle-up"),
        ],

        // MARK: - The Row

        // pp.incline-row — Incline Row. anchor: 12 reps = Forged.
        "pp.incline-row": [
            .initiate:   .reps(5,  exerciseName: "incline row"),
            .novice:     .reps(8,  exerciseName: "incline row"),
            .apprentice: .reps(10, exerciseName: "incline row"),
            .forged:     .reps(12, exerciseName: "incline row"),
            .veteran:    .reps(15, exerciseName: "incline row"),
            .master:      .reps(20, exerciseName: "incline row"),
            .vessel:     .reps(25, exerciseName: "incline row"),
            .unbound:    .reps(30, exerciseName: "incline row"),
            .ascendant:  .reps(40, exerciseName: "incline row"),
        ],

        // pp.row — Row. anchor: 10 reps = Forged.
        "pp.row": [
            .initiate:   .reps(3,  exerciseName: "inverted row"),
            .novice:     .reps(5,  exerciseName: "inverted row"),
            .apprentice: .reps(8,  exerciseName: "inverted row"),
            .forged:     .reps(10, exerciseName: "inverted row"),
            .veteran:    .reps(12, exerciseName: "inverted row"),
            .master:      .reps(15, exerciseName: "inverted row"),
            .vessel:     .reps(20, exerciseName: "inverted row"),
            .unbound:    .reps(25, exerciseName: "inverted row"),
            .ascendant:  .reps(30, exerciseName: "inverted row"),
        ],

        // pp.decline-row — Decline Row. anchor: 10 reps = Forged.
        "pp.decline-row": [
            .initiate:   .reps(3,  exerciseName: "decline row"),
            .novice:     .reps(5,  exerciseName: "decline row"),
            .apprentice: .reps(7,  exerciseName: "decline row"),
            .forged:     .reps(10, exerciseName: "decline row"),
            .veteran:    .reps(12, exerciseName: "decline row"),
            .master:      .reps(15, exerciseName: "decline row"),
            .vessel:     .reps(20, exerciseName: "decline row"),
            .unbound:    .reps(25, exerciseName: "decline row"),
            .ascendant:  .reps(30, exerciseName: "decline row"),
        ],

        // pp.tuck-row — Tuck Row. anchor: 8 reps = Forged.
        "pp.tuck-row": [
            .initiate:   .reps(2,  exerciseName: "tuck row"),
            .novice:     .reps(3,  exerciseName: "tuck row"),
            .apprentice: .reps(5,  exerciseName: "tuck row"),
            .forged:     .reps(8,  exerciseName: "tuck row"),
            .veteran:    .reps(10, exerciseName: "tuck row"),
            .master:      .reps(12, exerciseName: "tuck row"),
            .vessel:     .reps(15, exerciseName: "tuck row"),
            .unbound:    .reps(18, exerciseName: "tuck row"),
            .ascendant:  .reps(20, exerciseName: "tuck row"),
        ],

        // pp.straddle-row — Straddle Row. anchor: 5 reps = Forged.
        // Front-lever on-ramp.
        "pp.straddle-row": [
            .initiate:   .reps(1,  exerciseName: "straddle row"),
            .novice:     .reps(2,  exerciseName: "straddle row"),
            .apprentice: .reps(3,  exerciseName: "straddle row"),
            .forged:     .reps(5,  exerciseName: "straddle row"),
            .veteran:    .reps(7,  exerciseName: "straddle row"),
            .master:      .reps(9,  exerciseName: "straddle row"),
            .vessel:     .reps(11, exerciseName: "straddle row"),
            .unbound:    .reps(13, exerciseName: "straddle row"),
            .ascendant:  .reps(15, exerciseName: "straddle row"),
        ],

        // pp.strict-pullup — live tree ID for strict pull-up volume.
        "pp.strict-pullup": [
            .initiate:   .reps(1,  exerciseName: "pullup"),
            .novice:     .reps(3,  exerciseName: "pullup"),
            .apprentice: .reps(5,  exerciseName: "pullup"),
            .forged:     .reps(8,  exerciseName: "pullup"),
            .veteran:    .reps(10, exerciseName: "pullup"),
            .master:      .reps(12, exerciseName: "pullup"),
            .vessel:     .reps(15, exerciseName: "pullup"),
            .unbound:    .reps(18, exerciseName: "pullup"),
            .ascendant:  .reps(20, exerciseName: "pullup"),
        ],

        // pp.one-arm-row — unilateral row bridge before lever rows.
        "pp.one-arm-row": [
            .initiate:   .reps(3,  exerciseName: "one-arm row"),
            .novice:     .reps(5,  exerciseName: "one-arm row"),
            .apprentice: .reps(8,  exerciseName: "one-arm row"),
            .forged:     .reps(10, exerciseName: "one-arm row"),
            .veteran:    .reps(12, exerciseName: "one-arm row"),
            .master:      .reps(15, exerciseName: "one-arm row"),
            .vessel:     .compound([.reps(15, exerciseName: "one-arm row"), .reps(5, exerciseName: "tuck row")]),
            .unbound:    .compound([.reps(20, exerciseName: "one-arm row"), .reps(8, exerciseName: "tuck row")]),
            .ascendant:  .compound([.reps(25, exerciseName: "one-arm row"), .reps(5, exerciseName: "straddle row")]),
        ],

        // pp.tuck-front-lever-pullup — lever row/pull bridge. The target is
        // harder than tuck rows, so upper ranks require straddle-row strength too.
        "pp.tuck-front-lever-pullup": [
            .initiate:   .reps(3, exerciseName: "tuck row"),
            .novice:     .reps(5, exerciseName: "tuck row"),
            .apprentice: .reps(8, exerciseName: "tuck row"),
            .forged:     .reps(3, exerciseName: "tuck front lever pullup"),
            .veteran:    .reps(5, exerciseName: "tuck front lever pullup"),
            .master:      .reps(7, exerciseName: "tuck front lever pullup"),
            .vessel:     .compound([.reps(7, exerciseName: "tuck front lever pullup"), .reps(5, exerciseName: "straddle row")]),
            .unbound:    .compound([.reps(10, exerciseName: "tuck front lever pullup"), .reps(8, exerciseName: "straddle row")]),
            .ascendant:  .compound([.reps(12, exerciseName: "tuck front lever pullup"), .variant("front lever")]),
        ],
    ]
}
