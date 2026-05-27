// UNBOUND/Models/SkillTreeContent/Tiers/HspuSkillTiers.swift
//
// Tier criteria for every skill with prefix `hspu.` (10 skills).
// Handstand push-up progression chain. See CalSkillTiers.swift for pattern.
//
// Cascade: pike pushup → elevated pike pushup → wall hspu negative →
//   first wall hspu → wall hspu (3 / 5 volume) → deficit wall hspu →
//   freestanding hspu negative → first freestanding hspu → freestanding volume.
//
// Lower tiers of early-chain skills use .reps("pushup") as a proxy progression,
// transitioning to the actual exercise at mid tiers. Upper tiers of wall work
// compound with the next-step exercise to gate forward momentum. Elite
// (freestanding) top tiers require deficit or volume work that reads as
// genuinely rare.

import Foundation

#if DEBUG
private let _hspuCountCheck: Int = {
    assert(
        HspuSkillTiers.table.count == 10,
        "hspu cluster should have 10 entries, has \(HspuSkillTiers.table.count)"
    )
    for (id, tiers) in HspuSkillTiers.table {
        assert(tiers.count == 9, "\(id) needs 9 tiers, has \(tiers.count)")
        for tier in SkillTier.allCases {
            assert(tiers[tier] != nil, "\(id) missing tier \(tier)")
        }
    }
    return HspuSkillTiers.table.count
}()
#endif

enum HspuSkillTiers {
    static let table: [String: [SkillTier: TierCriterion]] = [

        // MARK: - Foundation: Pike Push-Ups

        // hspu.pike-pushup-10 — Pike Push-Up; anchor: 10 reps = Forged.
        // Entry to overhead pressing. Lower tiers use pushup as a proxy
        // (same pressing pattern, lighter load). Mid tiers confirm the
        // actual pike pushup. Upper tiers compound with elevated pike pushup
        // to confirm the user is already progressing toward the harder variant.
        "hspu.pike-pushup-10": [
            .initiate:   .reps(5,  exerciseName: "pushup"),
            .novice:     .reps(8,  exerciseName: "pushup"),
            .apprentice: .reps(5,  exerciseName: "pike pushup"),
            .forged:     .reps(10, exerciseName: "pike pushup"),
            .veteran:    .reps(15, exerciseName: "pike pushup"),
            .master:      .reps(20, exerciseName: "pike pushup"),
            .vessel:     .compound([.reps(20, exerciseName: "pike pushup"), .reps(5, exerciseName: "elevated pike pushup")]),
            .unbound:    .compound([.reps(25, exerciseName: "pike pushup"), .reps(8, exerciseName: "elevated pike pushup")]),
            .ascendant:  .compound([.reps(30, exerciseName: "pike pushup"), .reps(10, exerciseName: "elevated pike pushup")]),
        ],

        // hspu.elevated-pike-pushup-10 — Elevated Pike Push-Up; anchor: 10 reps = Forged.
        // Harder pike angle — feet on box/bench. Lower tiers proxy through
        // pike pushup. Mid tiers confirm the actual elevated variant.
        // Upper tiers compound with wall hspu negative to confirm entry
        // into true inversion work.
        "hspu.elevated-pike-pushup-10": [
            .initiate:   .reps(5,  exerciseName: "pike pushup"),
            .novice:     .reps(8,  exerciseName: "pike pushup"),
            .apprentice: .reps(5,  exerciseName: "elevated pike pushup"),
            .forged:     .reps(10, exerciseName: "elevated pike pushup"),
            .veteran:    .reps(15, exerciseName: "elevated pike pushup"),
            .master:      .reps(20, exerciseName: "elevated pike pushup"),
            .vessel:     .compound([.reps(20, exerciseName: "elevated pike pushup"), .reps(3, exerciseName: "wall hspu negative")]),
            .unbound:    .compound([.reps(25, exerciseName: "elevated pike pushup"), .reps(5, exerciseName: "wall hspu negative")]),
            .ascendant:  .compound([.reps(30, exerciseName: "elevated pike pushup"), .reps(1, exerciseName: "wall hspu")]),
        ],

        // MARK: - Wall HSPU Entry

        // hspu.wall-hspu-negative-5s — Wall HSPU Negative; anchor: 3 reps = Forged.
        // Eccentric only — lowering under control against the wall. Lower tiers
        // use elevated pike pushup as the relevant proxy. Mid tiers confirm the
        // actual negative. Upper tiers compound with first wall hspu to confirm
        // the concentric has unlocked.
        "hspu.wall-hspu-negative-5s": [
            .initiate:   .reps(5,  exerciseName: "elevated pike pushup"),
            .novice:     .reps(8,  exerciseName: "elevated pike pushup"),
            .apprentice: .reps(1,  exerciseName: "wall hspu negative"),
            .forged:     .reps(3,  exerciseName: "wall hspu negative"),
            .veteran:    .reps(5,  exerciseName: "wall hspu negative"),
            .master:      .reps(8,  exerciseName: "wall hspu negative"),
            .vessel:     .compound([.reps(8, exerciseName: "wall hspu negative"), .reps(1, exerciseName: "wall hspu")]),
            .unbound:    .compound([.reps(10, exerciseName: "wall hspu negative"), .reps(3, exerciseName: "wall hspu")]),
            .ascendant:  .compound([.reps(12, exerciseName: "wall hspu negative"), .reps(5, exerciseName: "wall hspu")]),
        ],

        // hspu.first-wall-hspu — First Wall HSPU; anchor: 1 rep = Forged.
        // The moment the concentric clicks. Lower tiers proxy through negatives
        // to confirm the eccentric base. Forged = the first clean rep. Upper
        // tiers escalate volume, confirming the milestone was repeatable.
        "hspu.first-wall-hspu": [
            .initiate:   .reps(3,  exerciseName: "wall hspu negative"),
            .novice:     .reps(5,  exerciseName: "wall hspu negative"),
            .apprentice: .reps(8,  exerciseName: "wall hspu negative"),
            .forged:     .reps(1,  exerciseName: "wall hspu"),
            .veteran:    .reps(2,  exerciseName: "wall hspu"),
            .master:      .reps(3,  exerciseName: "wall hspu"),
            .vessel:     .reps(5,  exerciseName: "wall hspu"),
            .unbound:    .reps(8,  exerciseName: "wall hspu"),
            .ascendant:  .reps(10, exerciseName: "wall hspu"),
        ],

        // MARK: - Wall HSPU Volume

        // hspu.wall-hspu-3 — Wall HSPU; anchor: 3 reps = Forged.
        // First volume target. Ladder from 1 rep at Initiate up through
        // consistent triple. Upper tiers compound with deficit wall hspu
        // to gate into the harder range-of-motion variant.
        "hspu.wall-hspu-3": [
            .initiate:   .reps(1,  exerciseName: "wall hspu"),
            .novice:     .reps(2,  exerciseName: "wall hspu"),
            .apprentice: .reps(3,  exerciseName: "wall hspu"),
            .forged:     .reps(5,  exerciseName: "wall hspu"),
            .veteran:    .reps(7,  exerciseName: "wall hspu"),
            .master:      .reps(10, exerciseName: "wall hspu"),
            .vessel:     .compound([.reps(10, exerciseName: "wall hspu"), .reps(1, exerciseName: "deficit wall hspu")]),
            .unbound:    .compound([.reps(12, exerciseName: "wall hspu"), .reps(3, exerciseName: "deficit wall hspu")]),
            .ascendant:  .compound([.reps(15, exerciseName: "wall hspu"), .reps(5, exerciseName: "deficit wall hspu")]),
        ],

        // hspu.wall-hspu-5 — Wall HSPU Volume; anchor: 5 reps = Forged.
        // Second volume tier. Prereq: hspu.wall-hspu-3. Initiates from 2 reps
        // (already above novice on the prior skill). Upper tiers compound
        // with deficit wall hspu then freestanding negatives.
        "hspu.wall-hspu-5": [
            .initiate:   .reps(2,  exerciseName: "wall hspu"),
            .novice:     .reps(3,  exerciseName: "wall hspu"),
            .apprentice: .reps(5,  exerciseName: "wall hspu"),
            .forged:     .reps(7,  exerciseName: "wall hspu"),
            .veteran:    .reps(10, exerciseName: "wall hspu"),
            .master:      .reps(12, exerciseName: "wall hspu"),
            .vessel:     .compound([.reps(12, exerciseName: "wall hspu"), .reps(3, exerciseName: "deficit wall hspu")]),
            .unbound:    .compound([.reps(15, exerciseName: "wall hspu"), .reps(5, exerciseName: "deficit wall hspu")]),
            .ascendant:  .compound([.reps(15, exerciseName: "wall hspu"), .reps(3, exerciseName: "freestanding hspu negative")]),
        ],

        // MARK: - Deficit & Freestanding Bridge

        // hspu.deficit-wall-hspu-3 — Deficit Wall HSPU; anchor: 3 reps = Forged.
        // Deeper range of motion with parallettes/plates against wall. Lower tiers
        // confirm the standard wall hspu base. Upper tiers compound with
        // freestanding hspu negative to confirm the transition to open balance.
        "hspu.deficit-wall-hspu-3": [
            .initiate:   .reps(5,  exerciseName: "wall hspu"),
            .novice:     .reps(8,  exerciseName: "wall hspu"),
            .apprentice: .reps(1,  exerciseName: "deficit wall hspu"),
            .forged:     .reps(3,  exerciseName: "deficit wall hspu"),
            .veteran:    .reps(5,  exerciseName: "deficit wall hspu"),
            .master:      .reps(7,  exerciseName: "deficit wall hspu"),
            .vessel:     .compound([.reps(7, exerciseName: "deficit wall hspu"), .reps(1, exerciseName: "freestanding hspu negative")]),
            .unbound:    .compound([.reps(10, exerciseName: "deficit wall hspu"), .reps(3, exerciseName: "freestanding hspu negative")]),
            .ascendant:  .compound([.reps(10, exerciseName: "deficit wall hspu"), .reps(1, exerciseName: "freestanding hspu")]),
        ],

        // hspu.freestanding-hspu-negative-5s — Freestanding HSPU Negative; anchor: 3 reps = Forged.
        // Eccentric-only HSPU with no wall — balance is now the constraint.
        // Lower tiers confirm deficit wall work as the base. Upper tiers
        // compound with first freestanding hspu rep.
        "hspu.freestanding-hspu-negative-5s": [
            .initiate:   .reps(5,  exerciseName: "deficit wall hspu"),
            .novice:     .reps(7,  exerciseName: "deficit wall hspu"),
            .apprentice: .reps(1,  exerciseName: "freestanding hspu negative"),
            .forged:     .reps(3,  exerciseName: "freestanding hspu negative"),
            .veteran:    .reps(5,  exerciseName: "freestanding hspu negative"),
            .master:      .reps(7,  exerciseName: "freestanding hspu negative"),
            .vessel:     .compound([.reps(7, exerciseName: "freestanding hspu negative"), .reps(1, exerciseName: "freestanding hspu")]),
            .unbound:    .compound([.reps(10, exerciseName: "freestanding hspu negative"), .reps(2, exerciseName: "freestanding hspu")]),
            .ascendant:  .compound([.reps(10, exerciseName: "freestanding hspu negative"), .reps(3, exerciseName: "freestanding hspu")]),
        ],

        // MARK: - Freestanding HSPU

        // hspu.first-freestanding-hspu — Freestanding HSPU; anchor: 1 rep = Forged.
        // Elite milestone — full handstand pushup with no wall support. Lower tiers
        // confirm the negative base. Forged = the first clean rep. Upper tiers
        // escalate volume; Ascendant compounds with deficit freestanding to confirm
        // the move is deeply owned.
        "hspu.first-freestanding-hspu": [
            .initiate:   .reps(3,  exerciseName: "freestanding hspu negative"),
            .novice:     .reps(5,  exerciseName: "freestanding hspu negative"),
            .apprentice: .reps(8,  exerciseName: "freestanding hspu negative"),
            .forged:     .reps(1,  exerciseName: "freestanding hspu"),
            .veteran:    .reps(2,  exerciseName: "freestanding hspu"),
            .master:      .reps(3,  exerciseName: "freestanding hspu"),
            .vessel:     .reps(5,  exerciseName: "freestanding hspu"),
            .unbound:    .reps(7,  exerciseName: "freestanding hspu"),
            .ascendant:  .compound([.reps(7, exerciseName: "freestanding hspu"), .reps(3, exerciseName: "deficit freestanding hspu")]),
        ],

        // hspu.freestanding-hspu-3 — Freestanding HSPU Volume; anchor: 3 reps = Forged.
        // Volume on the elite move. Prereq: hspu.first-freestanding-hspu. Starts
        // from 1 rep at Initiate — already past the first-rep threshold. Top tiers
        // require deficit freestanding and a 10-rep ceiling — representing a
        // genuinely world-class pressing benchmark.
        "hspu.freestanding-hspu-3": [
            .initiate:   .reps(1,  exerciseName: "freestanding hspu"),
            .novice:     .reps(2,  exerciseName: "freestanding hspu"),
            .apprentice: .reps(3,  exerciseName: "freestanding hspu"),
            .forged:     .reps(5,  exerciseName: "freestanding hspu"),
            .veteran:    .reps(7,  exerciseName: "freestanding hspu"),
            .master:      .reps(10, exerciseName: "freestanding hspu"),
            .vessel:     .compound([.reps(10, exerciseName: "freestanding hspu"), .reps(3, exerciseName: "deficit freestanding hspu")]),
            .unbound:    .compound([.reps(10, exerciseName: "freestanding hspu"), .reps(5, exerciseName: "deficit freestanding hspu")]),
            .ascendant:  .compound([.reps(10, exerciseName: "freestanding hspu"), .reps(10, exerciseName: "deficit freestanding hspu")]),
        ],
    ]
}
