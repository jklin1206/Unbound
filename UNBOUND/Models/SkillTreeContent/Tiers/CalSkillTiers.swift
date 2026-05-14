// UNBOUND/Models/SkillTreeContent/Tiers/CalSkillTiers.swift
//
// Tier criteria for every skill with prefix `cal.` (27 skills).
//
// Each skill climbs from a quiet entry threshold (Initiate) to a Vessel/
// Unbound moment that reads as elite for that specific move. Criteria are
// auto-evaluated by TierCriterionEvaluator against the user's logs.
//
// Hold-type skills (plank, l-sit, iron-cross, ring-support, maltese):
//   .variant("exercise-name") is used for lower tiers since holds are logged
//   as named exercises. The base exercise name (e.g. "plank") matches what
//   TierCriterionEvaluator checks case-insensitively. Upper tiers use
//   .compound to require both the base hold variant AND a related rep
//   progression, confirming mastery of the underlying movement pattern.
//
// Weighted-dip: uses .compound([.variant("weighted dip"), .bodyweightRatio(r)])
//   so the exercise variant is confirmed before the weight ratio is checked.
//   .bodyweightRatio alone would match any heavy lift across all history.
//
// Azarian / Iron Cross (elite/mythic holds): cascade through related easier
//   variants on the way up, with .compound at upper tiers requiring both
//   the target variant AND a supporting rep progression.

import Foundation

#if DEBUG
private let _calCountCheck: Int = {
    assert(
        CalSkillTiers.table.count == 27,
        "cal cluster should have 27 entries, has \(CalSkillTiers.table.count)"
    )
    for (id, tiers) in CalSkillTiers.table {
        assert(tiers.count == 9, "\(id) needs 9 tiers, has \(tiers.count)")
        for tier in SkillTier.allCases {
            assert(tiers[tier] != nil, "\(id) missing tier \(tier)")
        }
    }
    return CalSkillTiers.table.count
}()
#endif

enum CalSkillTiers {
    static let table: [String: [SkillTier: TierCriterion]] = [

        // MARK: - Ground Work: Push-Ups

        // cal.pushup  — anchor: 10 reps = Forged
        "cal.pushup": [
            .initiate:   .reps(3,   exerciseName: "pushup"),
            .novice:     .reps(5,   exerciseName: "pushup"),
            .apprentice: .reps(8,   exerciseName: "pushup"),
            .forged:     .reps(15,  exerciseName: "pushup"),
            .veteran:    .reps(25,  exerciseName: "pushup"),
            .honed:      .reps(40,  exerciseName: "pushup"),
            .vessel:     .reps(60,  exerciseName: "pushup"),
            .unbound:    .reps(80,  exerciseName: "pushup"),
            .ascendant:  .reps(100, exerciseName: "pushup"),
        ],

        // cal.incline-pushup — easiest pushup variant; anchor: 10 reps = Forged
        "cal.incline-pushup": [
            .initiate:   .reps(5,   exerciseName: "incline pushup"),
            .novice:     .reps(8,   exerciseName: "incline pushup"),
            .apprentice: .reps(12,  exerciseName: "incline pushup"),
            .forged:     .reps(20,  exerciseName: "incline pushup"),
            .veteran:    .reps(30,  exerciseName: "incline pushup"),
            .honed:      .reps(40,  exerciseName: "incline pushup"),
            .vessel:     .reps(60,  exerciseName: "incline pushup"),
            .unbound:    .reps(80,  exerciseName: "incline pushup"),
            .ascendant:  .reps(100, exerciseName: "incline pushup"),
        ],

        // cal.decline-pushup — harder angle; anchor: 10 reps = Forged
        "cal.decline-pushup": [
            .initiate:   .reps(3,  exerciseName: "decline pushup"),
            .novice:     .reps(5,  exerciseName: "decline pushup"),
            .apprentice: .reps(8,  exerciseName: "decline pushup"),
            .forged:     .reps(12, exerciseName: "decline pushup"),
            .veteran:    .reps(20, exerciseName: "decline pushup"),
            .honed:      .reps(30, exerciseName: "decline pushup"),
            .vessel:     .reps(40, exerciseName: "decline pushup"),
            .unbound:    .reps(55, exerciseName: "decline pushup"),
            .ascendant:  .reps(75, exerciseName: "decline pushup"),
        ],

        // cal.slow-pushup — tempo variation; anchor: 10 reps = Forged
        "cal.slow-pushup": [
            .initiate:   .reps(3,  exerciseName: "slow pushup"),
            .novice:     .reps(5,  exerciseName: "slow pushup"),
            .apprentice: .reps(7,  exerciseName: "slow pushup"),
            .forged:     .reps(10, exerciseName: "slow pushup"),
            .veteran:    .reps(15, exerciseName: "slow pushup"),
            .honed:      .reps(20, exerciseName: "slow pushup"),
            .vessel:     .reps(30, exerciseName: "slow pushup"),
            .unbound:    .reps(40, exerciseName: "slow pushup"),
            .ascendant:  .reps(50, exerciseName: "slow pushup"),
        ],

        // cal.diamond-pushup — tricep focus; anchor: 10 reps = Forged
        "cal.diamond-pushup": [
            .initiate:   .reps(3,  exerciseName: "diamond pushup"),
            .novice:     .reps(5,  exerciseName: "diamond pushup"),
            .apprentice: .reps(7,  exerciseName: "diamond pushup"),
            .forged:     .reps(10, exerciseName: "diamond pushup"),
            .veteran:    .reps(15, exerciseName: "diamond pushup"),
            .honed:      .reps(22, exerciseName: "diamond pushup"),
            .vessel:     .reps(30, exerciseName: "diamond pushup"),
            .unbound:    .reps(40, exerciseName: "diamond pushup"),
            .ascendant:  .reps(50, exerciseName: "diamond pushup"),
        ],

        // cal.sphinx-pushup — low tricep/elbow push; anchor: 8 reps = Forged
        "cal.sphinx-pushup": [
            .initiate:   .reps(2,  exerciseName: "sphinx pushup"),
            .novice:     .reps(4,  exerciseName: "sphinx pushup"),
            .apprentice: .reps(6,  exerciseName: "sphinx pushup"),
            .forged:     .reps(8,  exerciseName: "sphinx pushup"),
            .veteran:    .reps(12, exerciseName: "sphinx pushup"),
            .honed:      .reps(18, exerciseName: "sphinx pushup"),
            .vessel:     .reps(25, exerciseName: "sphinx pushup"),
            .unbound:    .reps(35, exerciseName: "sphinx pushup"),
            .ascendant:  .reps(50, exerciseName: "sphinx pushup"),
        ],

        // cal.archer-pushup — lateral load; anchor: 3 reps = Forged
        "cal.archer-pushup": [
            .initiate:   .reps(1,  exerciseName: "archer pushup"),
            .novice:     .reps(2,  exerciseName: "archer pushup"),
            .apprentice: .reps(3,  exerciseName: "archer pushup"),
            .forged:     .reps(5,  exerciseName: "archer pushup"),
            .veteran:    .reps(8,  exerciseName: "archer pushup"),
            .honed:      .reps(12, exerciseName: "archer pushup"),
            .vessel:     .reps(16, exerciseName: "archer pushup"),
            .unbound:    .reps(20, exerciseName: "archer pushup"),
            .ascendant:  .reps(25, exerciseName: "archer pushup"),
        ],

        // cal.one-arm-pushup — single arm; anchor: 1 rep = Forged
        "cal.one-arm-pushup": [
            .initiate:   .reps(1, exerciseName: "one-arm pushup"),
            .novice:     .reps(2, exerciseName: "one-arm pushup"),
            .apprentice: .reps(3, exerciseName: "one-arm pushup"),
            .forged:     .reps(5, exerciseName: "one-arm pushup"),
            .veteran:    .reps(8, exerciseName: "one-arm pushup"),
            .honed:      .reps(10, exerciseName: "one-arm pushup"),
            .vessel:     .reps(12, exerciseName: "one-arm pushup"),
            .unbound:    .reps(15, exerciseName: "one-arm pushup"),
            .ascendant:  .reps(20, exerciseName: "one-arm pushup"),
        ],

        // cal.explosive-pushup — power/plyometric; anchor: 5 reps = Forged
        "cal.explosive-pushup": [
            .initiate:   .reps(2,  exerciseName: "explosive pushup"),
            .novice:     .reps(3,  exerciseName: "explosive pushup"),
            .apprentice: .reps(4,  exerciseName: "explosive pushup"),
            .forged:     .reps(5,  exerciseName: "explosive pushup"),
            .veteran:    .reps(8,  exerciseName: "explosive pushup"),
            .honed:      .reps(12, exerciseName: "explosive pushup"),
            .vessel:     .reps(16, exerciseName: "explosive pushup"),
            .unbound:    .reps(20, exerciseName: "explosive pushup"),
            .ascendant:  .reps(25, exerciseName: "explosive pushup"),
        ],

        // cal.clapping-pushup — launch + catch; anchor: 3 reps = Forged
        "cal.clapping-pushup": [
            .initiate:   .reps(1,  exerciseName: "clapping pushup"),
            .novice:     .reps(2,  exerciseName: "clapping pushup"),
            .apprentice: .reps(3,  exerciseName: "clapping pushup"),
            .forged:     .reps(5,  exerciseName: "clapping pushup"),
            .veteran:    .reps(8,  exerciseName: "clapping pushup"),
            .honed:      .reps(10, exerciseName: "clapping pushup"),
            .vessel:     .reps(15, exerciseName: "clapping pushup"),
            .unbound:    .reps(20, exerciseName: "clapping pushup"),
            .ascendant:  .reps(25, exerciseName: "clapping pushup"),
        ],

        // cal.triple-clap-pushup — triple airtime clap; anchor: 1 rep = Forged
        "cal.triple-clap-pushup": [
            .initiate:   .reps(1, exerciseName: "triple clap pushup"),
            .novice:     .reps(2, exerciseName: "triple clap pushup"),
            .apprentice: .reps(3, exerciseName: "triple clap pushup"),
            .forged:     .reps(4, exerciseName: "triple clap pushup"),
            .veteran:    .reps(5, exerciseName: "triple clap pushup"),
            .honed:      .reps(7, exerciseName: "triple clap pushup"),
            .vessel:     .reps(10, exerciseName: "triple clap pushup"),
            .unbound:    .reps(12, exerciseName: "triple clap pushup"),
            .ascendant:  .reps(15, exerciseName: "triple clap pushup"),
        ],

        // cal.floating-pike-pushup — pike compression + hover; anchor: 3 reps = Forged
        "cal.floating-pike-pushup": [
            .initiate:   .reps(1, exerciseName: "floating pike pushup"),
            .novice:     .reps(2, exerciseName: "floating pike pushup"),
            .apprentice: .reps(3, exerciseName: "floating pike pushup"),
            .forged:     .reps(4, exerciseName: "floating pike pushup"),
            .veteran:    .reps(5, exerciseName: "floating pike pushup"),
            .honed:      .reps(7, exerciseName: "floating pike pushup"),
            .vessel:     .reps(10, exerciseName: "floating pike pushup"),
            .unbound:    .reps(13, exerciseName: "floating pike pushup"),
            .ascendant:  .reps(16, exerciseName: "floating pike pushup"),
        ],

        // MARK: - The Dip

        // cal.bench-dip — easiest dip variant; anchor: 10 reps = Forged
        "cal.bench-dip": [
            .initiate:   .reps(5,  exerciseName: "bench dip"),
            .novice:     .reps(8,  exerciseName: "bench dip"),
            .apprentice: .reps(10, exerciseName: "bench dip"),
            .forged:     .reps(15, exerciseName: "bench dip"),
            .veteran:    .reps(20, exerciseName: "bench dip"),
            .honed:      .reps(30, exerciseName: "bench dip"),
            .vessel:     .reps(40, exerciseName: "bench dip"),
            .unbound:    .reps(55, exerciseName: "bench dip"),
            .ascendant:  .reps(75, exerciseName: "bench dip"),
        ],

        // cal.5-dips — standard parallel bar dip; anchor: 5 reps = Forged
        "cal.5-dips": [
            .initiate:   .reps(2,  exerciseName: "dip"),
            .novice:     .reps(3,  exerciseName: "dip"),
            .apprentice: .reps(4,  exerciseName: "dip"),
            .forged:     .reps(5,  exerciseName: "dip"),
            .veteran:    .reps(10, exerciseName: "dip"),
            .honed:      .reps(15, exerciseName: "dip"),
            .vessel:     .reps(20, exerciseName: "dip"),
            .unbound:    .reps(25, exerciseName: "dip"),
            .ascendant:  .reps(30, exerciseName: "dip"),
        ],

        // cal.tempo-dip — controlled eccentric; anchor: 5 reps = Forged
        "cal.tempo-dip": [
            .initiate:   .reps(2,  exerciseName: "tempo dip"),
            .novice:     .reps(3,  exerciseName: "tempo dip"),
            .apprentice: .reps(4,  exerciseName: "tempo dip"),
            .forged:     .reps(5,  exerciseName: "tempo dip"),
            .veteran:    .reps(8,  exerciseName: "tempo dip"),
            .honed:      .reps(10, exerciseName: "tempo dip"),
            .vessel:     .reps(12, exerciseName: "tempo dip"),
            .unbound:    .reps(15, exerciseName: "tempo dip"),
            .ascendant:  .reps(20, exerciseName: "tempo dip"),
        ],

        // cal.weighted-dip — added load; anchor: 0.25× bodyweight = Forged
        // Uses .compound to confirm the exercise was actually logged before
        // checking the bodyweight ratio (bestWeight in history is not
        // exercise-scoped, so a lone .bodyweightRatio would false-positive
        // on any heavy lift).
        "cal.weighted-dip": [
            .initiate:   .variant("weighted dip"),
            .novice:     .compound([.variant("weighted dip"), .bodyweightRatio(0.10)]),
            .apprentice: .compound([.variant("weighted dip"), .bodyweightRatio(0.15)]),
            .forged:     .compound([.variant("weighted dip"), .bodyweightRatio(0.25)]),
            .veteran:    .compound([.variant("weighted dip"), .bodyweightRatio(0.35)]),
            .honed:      .compound([.variant("weighted dip"), .bodyweightRatio(0.50)]),
            .vessel:     .compound([.variant("weighted dip"), .bodyweightRatio(0.65)]),
            .unbound:    .compound([.variant("weighted dip"), .bodyweightRatio(0.80)]),
            .ascendant:  .compound([.variant("weighted dip"), .bodyweightRatio(1.00)]),
        ],

        // cal.l-sit-dip — dip with compressed L-sit; anchor: 3 reps = Forged
        "cal.l-sit-dip": [
            .initiate:   .reps(1, exerciseName: "l-sit dip"),
            .novice:     .reps(2, exerciseName: "l-sit dip"),
            .apprentice: .reps(3, exerciseName: "l-sit dip"),
            .forged:     .reps(4, exerciseName: "l-sit dip"),
            .veteran:    .reps(5, exerciseName: "l-sit dip"),
            .honed:      .reps(7, exerciseName: "l-sit dip"),
            .vessel:     .reps(8, exerciseName: "l-sit dip"),
            .unbound:    .reps(10, exerciseName: "l-sit dip"),
            .ascendant:  .reps(12, exerciseName: "l-sit dip"),
        ],

        // cal.ring-dip — rings add instability; anchor: 5 reps = Forged
        "cal.ring-dip": [
            .initiate:   .reps(1,  exerciseName: "ring dip"),
            .novice:     .reps(2,  exerciseName: "ring dip"),
            .apprentice: .reps(3,  exerciseName: "ring dip"),
            .forged:     .reps(5,  exerciseName: "ring dip"),
            .veteran:    .reps(8,  exerciseName: "ring dip"),
            .honed:      .reps(10, exerciseName: "ring dip"),
            .vessel:     .reps(12, exerciseName: "ring dip"),
            .unbound:    .reps(15, exerciseName: "ring dip"),
            .ascendant:  .reps(20, exerciseName: "ring dip"),
        ],

        // MARK: - Lock-In: Holds

        // cal.plank-30 — hold-type; anchor: logging any plank = Forged (the
        // node target is 30 s but duration is not tracked per SetLog). Lower
        // tiers prove the user has trained the plank. Upper tiers compound
        // with pushup progression to confirm a strong pressing base.
        "cal.plank-30": [
            .initiate:   .variant("plank"),
            .novice:     .variant("plank"),
            .apprentice: .variant("plank"),
            .forged:     .compound([.variant("plank"), .reps(5, exerciseName: "pushup")]),
            .veteran:    .compound([.variant("plank"), .reps(10, exerciseName: "pushup")]),
            .honed:      .compound([.variant("plank"), .reps(20, exerciseName: "pushup")]),
            .vessel:     .compound([.variant("plank"), .reps(40, exerciseName: "pushup")]),
            .unbound:    .compound([.variant("plank"), .reps(60, exerciseName: "pushup")]),
            .ascendant:  .compound([.variant("plank"), .reps(80, exerciseName: "pushup")]),
        ],

        // cal.l-sit-10 — compressed hip-flexor hold; lower tiers: variant
        // confirms any l-sit log. Upper tiers compound with leg-raise to
        // confirm active hip flexor strength.
        "cal.l-sit-10": [
            .initiate:   .variant("l-sit"),
            .novice:     .variant("l-sit"),
            .apprentice: .variant("l-sit"),
            .forged:     .compound([.variant("l-sit"), .variant("leg raise")]),
            .veteran:    .compound([.variant("l-sit"), .reps(5, exerciseName: "leg raise")]),
            .honed:      .compound([.variant("l-sit"), .reps(10, exerciseName: "leg raise")]),
            .vessel:     .compound([.variant("l-sit"), .reps(15, exerciseName: "leg raise")]),
            .unbound:    .compound([.variant("l-sit"), .reps(20, exerciseName: "leg raise")]),
            .ascendant:  .compound([.variant("l-sit"), .reps(25, exerciseName: "leg raise")]),
        ],

        // cal.l-sit-20 — extended l-sit hold; prereq: cal.l-sit-10.
        // Same approach: variant confirms training, upper tiers add stronger
        // rep-based signals for an extended hold.
        "cal.l-sit-20": [
            .initiate:   .variant("l-sit"),
            .novice:     .compound([.variant("l-sit"), .variant("leg raise")]),
            .apprentice: .compound([.variant("l-sit"), .reps(5, exerciseName: "leg raise")]),
            .forged:     .compound([.variant("l-sit"), .reps(10, exerciseName: "leg raise")]),
            .veteran:    .compound([.variant("l-sit"), .reps(15, exerciseName: "leg raise")]),
            .honed:      .compound([.variant("l-sit"), .reps(20, exerciseName: "leg raise")]),
            .vessel:     .compound([.variant("l-sit"), .reps(25, exerciseName: "leg raise")]),
            .unbound:    .compound([.variant("l-sit"), .reps(30, exerciseName: "leg raise")]),
            .ascendant:  .compound([.variant("l-sit"), .reps(35, exerciseName: "leg raise")]),
        ],

        // MARK: - Ring King

        // cal.ring-support-10 — static ring support; anchor: variant = Forged.
        // Hold-type: duration not tracked. Lower tiers: variant proves entry.
        // Upper tiers compound with ring dip to confirm ring pressing strength.
        "cal.ring-support-10": [
            .initiate:   .variant("ring support hold"),
            .novice:     .variant("ring support hold"),
            .apprentice: .variant("ring support hold"),
            .forged:     .compound([.variant("ring support hold"), .reps(3, exerciseName: "ring dip")]),
            .veteran:    .compound([.variant("ring support hold"), .reps(5, exerciseName: "ring dip")]),
            .honed:      .compound([.variant("ring support hold"), .reps(8, exerciseName: "ring dip")]),
            .vessel:     .compound([.variant("ring support hold"), .reps(10, exerciseName: "ring dip")]),
            .unbound:    .compound([.variant("ring support hold"), .reps(12, exerciseName: "ring dip")]),
            .ascendant:  .compound([.variant("ring support hold"), .reps(15, exerciseName: "ring dip")]),
        ],

        // cal.iron-cross-3s — elite ring cross; hold-type, duration not tracked.
        // Cascade: ring-support → ring dip → iron cross variant.
        // Lower tiers prove ring pressing base; upper tiers prove the cross itself.
        "cal.iron-cross-3s": [
            .initiate:   .variant("ring support hold"),
            .novice:     .compound([.variant("ring support hold"), .reps(5, exerciseName: "ring dip")]),
            .apprentice: .compound([.variant("ring support hold"), .reps(10, exerciseName: "ring dip")]),
            .forged:     .compound([.variant("ring support hold"), .variant("iron cross")]),
            .veteran:    .compound([.variant("iron cross"), .reps(10, exerciseName: "ring dip")]),
            .honed:      .compound([.variant("iron cross"), .reps(15, exerciseName: "ring dip")]),
            .vessel:     .compound([.variant("iron cross"), .reps(20, exerciseName: "ring dip")]),
            .unbound:    .compound([.variant("iron cross"), .reps(25, exerciseName: "ring dip")]),
            .ascendant:  .compound([.variant("iron cross"), .reps(30, exerciseName: "ring dip")]),
        ],

        // cal.iron-cross-10s — extended cross hold; prereq: iron-cross-3s.
        // Even deeper compound: needs the cross variant at all lower tiers,
        // then escalates ring-dip counts for sustained hold capability.
        "cal.iron-cross-10s": [
            .initiate:   .variant("iron cross"),
            .novice:     .compound([.variant("iron cross"), .reps(5, exerciseName: "ring dip")]),
            .apprentice: .compound([.variant("iron cross"), .reps(10, exerciseName: "ring dip")]),
            .forged:     .compound([.variant("iron cross"), .reps(15, exerciseName: "ring dip")]),
            .veteran:    .compound([.variant("iron cross"), .reps(20, exerciseName: "ring dip")]),
            .honed:      .compound([.variant("iron cross"), .reps(25, exerciseName: "ring dip")]),
            .vessel:     .compound([.variant("iron cross"), .reps(30, exerciseName: "ring dip")]),
            .unbound:    .compound([.variant("iron cross"), .reps(35, exerciseName: "ring dip")]),
            .ascendant:  .compound([.variant("iron cross"), .reps(40, exerciseName: "ring dip")]),
        ],

        // MARK: - Mythic

        // cal.maltese — near-impossible planche-like hold on rings.
        // Hold-type, duration not tracked. Cascade from ring support through
        // iron cross to maltese itself. Ascendant requires maltese + highest
        // ring-dip count.
        "cal.maltese": [
            .initiate:   .variant("ring support hold"),
            .novice:     .compound([.variant("ring support hold"), .reps(5, exerciseName: "ring dip")]),
            .apprentice: .variant("iron cross"),
            .forged:     .compound([.variant("iron cross"), .reps(15, exerciseName: "ring dip")]),
            .veteran:    .compound([.variant("iron cross"), .reps(25, exerciseName: "ring dip")]),
            .honed:      .variant("maltese"),
            .vessel:     .compound([.variant("maltese"), .reps(10, exerciseName: "ring dip")]),
            .unbound:    .compound([.variant("maltese"), .reps(20, exerciseName: "ring dip")]),
            .ascendant:  .compound([.variant("maltese"), .reps(30, exerciseName: "ring dip")]),
        ],

        // cal.azarian — azarian press (one-arm ring press-out). Mythic.
        // Cascade through archer pushup → one-arm pushup → ring dip → ring
        // support → azarian variant.
        "cal.azarian": [
            .initiate:   .reps(3, exerciseName: "archer pushup"),
            .novice:     .reps(1, exerciseName: "one-arm pushup"),
            .apprentice: .compound([.reps(5, exerciseName: "ring dip"), .reps(1, exerciseName: "one-arm pushup")]),
            .forged:     .compound([.variant("ring support hold"), .reps(10, exerciseName: "ring dip")]),
            .veteran:    .compound([.variant("ring support hold"), .reps(15, exerciseName: "ring dip")]),
            .honed:      .variant("azarian"),
            .vessel:     .compound([.variant("azarian"), .reps(10, exerciseName: "ring dip")]),
            .unbound:    .compound([.variant("azarian"), .reps(15, exerciseName: "ring dip")]),
            .ascendant:  .compound([.variant("azarian"), .reps(20, exerciseName: "ring dip")]),
        ],

        // cal.bent-arm-press — bent arm press to handstand; anchor: 3 reps = Forged
        "cal.bent-arm-press": [
            .initiate:   .reps(1, exerciseName: "bent arm press"),
            .novice:     .reps(2, exerciseName: "bent arm press"),
            .apprentice: .reps(3, exerciseName: "bent arm press"),
            .forged:     .reps(4, exerciseName: "bent arm press"),
            .veteran:    .reps(5, exerciseName: "bent arm press"),
            .honed:      .reps(6, exerciseName: "bent arm press"),
            .vessel:     .reps(8, exerciseName: "bent arm press"),
            .unbound:    .reps(10, exerciseName: "bent arm press"),
            .ascendant:  .reps(12, exerciseName: "bent arm press"),
        ],
    ]
}
