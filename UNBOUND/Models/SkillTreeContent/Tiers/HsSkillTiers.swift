// UNBOUND/Models/SkillTreeContent/Tiers/HsSkillTiers.swift
//
// Tier criteria for every skill with prefix `hs.` (20 skills).
// Handstand family — wall/freestanding/headstand/press/arm balance variants.
// See CalSkillTiers.swift for the established pattern.
//
// Hold-type skills (wrist-conditioning, wall-plank, wall-handstand,
// headstand, tuck-handstand, freestanding variants, arm balances, elbow levers):
//   .variant("exercise-name") is used for lower tiers since holds are logged
//   as named exercises. Upper tiers compound with a pressing strength marker
//   (handstand pushup or pushup reps) to confirm the strength base underlying
//   the hold.
//
// Freestanding hold cascade: wall-plank → wall-handstand → headstand →
//   tuck-handstand → freestanding-hs-10 → freestanding-hs-30 → freestanding-hs-60.
//   Upper tiers of longer holds compound with press-to-handstand variants,
//   confirming true press strength rather than just kicking up.
//
// Press skills (tuck-press, straddle-press, press-to-handstand):
//   Compound upper tiers with handstand pushup counts — pressing overhead
//   strength is the limiting factor for these moves.
//
// Arm balance cascade (crow → crane → flying-crow, frog → elbow-lever →
//   one-arm-elbow-lever): each level compounds with the prior-tier variant
//   as a prerequisite at mid/upper tiers.
//
// Handstand walk: reps ("steps") are not a logged quantity. Lower tiers use
//   .variant("handstand walk") for entry confirmation. Upper tiers compound
//   with freestanding handstand hold and press work.

import Foundation

#if DEBUG
private let _hsCountCheck: Int = {
    assert(
        HsSkillTiers.table.count == 20,
        "hs cluster should have 20 entries, has \(HsSkillTiers.table.count)"
    )
    for (id, tiers) in HsSkillTiers.table {
        assert(tiers.count == 9, "\(id) needs 9 tiers, has \(tiers.count)")
        for tier in SkillTier.allCases {
            assert(tiers[tier] != nil, "\(id) missing tier \(tier)")
        }
    }
    return HsSkillTiers.table.count
}()
#endif

enum HsSkillTiers {
    static let table: [String: [SkillTier: TierCriterion]] = [

        // MARK: - Foundation: Wrist & Wall Prep

        // hs.wrist-conditioning — Reverse-Hand Plank hold; entry-level wrist prep.
        // Hold-type: duration not tracked. Lower tiers confirm any training of
        // the move. Upper tiers compound with pushup volume to confirm wrist
        // load tolerance under pressing volume.
        "hs.wrist-conditioning": [
            .initiate:   .variant("reverse-hand plank"),
            .novice:     .variant("reverse-hand plank"),
            .apprentice: .variant("reverse-hand plank"),
            .forged:     .compound([.variant("reverse-hand plank"), .reps(10, exerciseName: "pushup")]),
            .veteran:    .compound([.variant("reverse-hand plank"), .reps(20, exerciseName: "pushup")]),
            .honed:      .compound([.variant("reverse-hand plank"), .reps(30, exerciseName: "pushup")]),
            .vessel:     .compound([.variant("reverse-hand plank"), .reps(50, exerciseName: "pushup")]),
            .unbound:    .compound([.variant("reverse-hand plank"), .reps(70, exerciseName: "pushup")]),
            .ascendant:  .compound([.variant("reverse-hand plank"), .reps(100, exerciseName: "pushup")]),
        ],

        // hs.wall-plank — Wall Plank (feet on wall, body inverted at ~45°).
        // Hold-type. Gateway to wall handstand. Upper tiers compound with
        // handstand pushup to confirm overhead pressing base.
        "hs.wall-plank": [
            .initiate:   .variant("wall plank"),
            .novice:     .variant("wall plank"),
            .apprentice: .variant("wall plank"),
            .forged:     .compound([.variant("wall plank"), .reps(3, exerciseName: "handstand pushup")]),
            .veteran:    .compound([.variant("wall plank"), .reps(5, exerciseName: "handstand pushup")]),
            .honed:      .compound([.variant("wall plank"), .reps(8, exerciseName: "handstand pushup")]),
            .vessel:     .compound([.variant("wall plank"), .reps(12, exerciseName: "handstand pushup")]),
            .unbound:    .compound([.variant("wall plank"), .reps(16, exerciseName: "handstand pushup")]),
            .ascendant:  .compound([.variant("wall plank"), .reps(20, exerciseName: "handstand pushup")]),
        ],

        // hs.wall-handstand-30 — Wall Handstand hold target: 30 s.
        // Hold-type. Lower tiers: variant confirms any wall handstand log.
        // Upper tiers compound with handstand pushup reps — inverted pressing
        // strength is the direct strength limiter for hold duration.
        "hs.wall-handstand-30": [
            .initiate:   .variant("wall handstand"),
            .novice:     .variant("wall handstand"),
            .apprentice: .variant("wall handstand"),
            .forged:     .compound([.variant("wall handstand"), .reps(3, exerciseName: "handstand pushup")]),
            .veteran:    .compound([.variant("wall handstand"), .reps(5, exerciseName: "handstand pushup")]),
            .honed:      .compound([.variant("wall handstand"), .reps(8, exerciseName: "handstand pushup")]),
            .vessel:     .compound([.variant("wall handstand"), .reps(12, exerciseName: "handstand pushup")]),
            .unbound:    .compound([.variant("wall handstand"), .reps(16, exerciseName: "handstand pushup")]),
            .ascendant:  .compound([.variant("wall handstand"), .reps(20, exerciseName: "handstand pushup")]),
        ],

        // hs.wall-handstand-60 — Wall Handstand Hold target: 60 s.
        // Prereq: hs.wall-handstand-30. Starts from compound entry. Upper tiers
        // compound with higher HSPU counts for the longer hold demand.
        "hs.wall-handstand-60": [
            .initiate:   .variant("wall handstand"),
            .novice:     .compound([.variant("wall handstand"), .reps(3, exerciseName: "handstand pushup")]),
            .apprentice: .compound([.variant("wall handstand"), .reps(5, exerciseName: "handstand pushup")]),
            .forged:     .compound([.variant("wall handstand"), .reps(8, exerciseName: "handstand pushup")]),
            .veteran:    .compound([.variant("wall handstand"), .reps(10, exerciseName: "handstand pushup")]),
            .honed:      .compound([.variant("wall handstand"), .reps(12, exerciseName: "handstand pushup")]),
            .vessel:     .compound([.variant("wall handstand"), .reps(15, exerciseName: "handstand pushup")]),
            .unbound:    .compound([.variant("wall handstand"), .reps(18, exerciseName: "handstand pushup")]),
            .ascendant:  .compound([.variant("wall handstand"), .reps(22, exerciseName: "handstand pushup")]),
        ],

        // MARK: - Headstand & Tuck Bridge

        // hs.headstand — Headstand hold target: 30 s.
        // Hold-type. Bridge between wall work and freestanding. Lower tiers
        // confirm headstand training. Upper tiers compound with wall handstand
        // to confirm the full inverted strength base.
        "hs.headstand": [
            .initiate:   .variant("headstand"),
            .novice:     .variant("headstand"),
            .apprentice: .variant("headstand"),
            .forged:     .compound([.variant("headstand"), .variant("wall handstand")]),
            .veteran:    .compound([.variant("headstand"), .reps(3, exerciseName: "handstand pushup")]),
            .honed:      .compound([.variant("headstand"), .reps(5, exerciseName: "handstand pushup")]),
            .vessel:     .compound([.variant("headstand"), .reps(8, exerciseName: "handstand pushup")]),
            .unbound:    .compound([.variant("headstand"), .reps(12, exerciseName: "handstand pushup")]),
            .ascendant:  .compound([.variant("headstand"), .reps(16, exerciseName: "handstand pushup")]),
        ],

        // hs.tuck-handstand — Tuck Handstand hold target: 5 s.
        // Hold-type. First freestanding inverted shape. Lower tiers confirm
        // any tuck handstand log. Upper tiers compound with freestanding
        // handstand variant to confirm progression beyond the tuck.
        "hs.tuck-handstand": [
            .initiate:   .variant("tuck handstand"),
            .novice:     .variant("tuck handstand"),
            .apprentice: .variant("tuck handstand"),
            .forged:     .compound([.variant("tuck handstand"), .variant("freestanding handstand")]),
            .veteran:    .compound([.variant("tuck handstand"), .reps(5, exerciseName: "handstand pushup")]),
            .honed:      .compound([.variant("tuck handstand"), .reps(8, exerciseName: "handstand pushup")]),
            .vessel:     .compound([.variant("tuck handstand"), .reps(12, exerciseName: "handstand pushup")]),
            .unbound:    .compound([.variant("tuck handstand"), .reps(16, exerciseName: "handstand pushup")]),
            .ascendant:  .compound([.variant("tuck handstand"), .reps(20, exerciseName: "handstand pushup")]),
        ],

        // MARK: - Freestanding Handstand Progression

        // hs.freestanding-hs-10 — Freestanding Handstand Opener target: 10 s.
        // Hold-type. First true freestanding benchmark. Lower tiers confirm any
        // freestanding handstand log. Upper tiers compound with tuck press to
        // confirm press-entry capability.
        "hs.freestanding-hs-10": [
            .initiate:   .variant("freestanding handstand"),
            .novice:     .variant("freestanding handstand"),
            .apprentice: .variant("freestanding handstand"),
            .forged:     .compound([.variant("freestanding handstand"), .reps(3, exerciseName: "handstand pushup")]),
            .veteran:    .compound([.variant("freestanding handstand"), .reps(5, exerciseName: "handstand pushup")]),
            .honed:      .compound([.variant("freestanding handstand"), .variant("tuck press")]),
            .vessel:     .compound([.variant("freestanding handstand"), .reps(1, exerciseName: "tuck press")]),
            .unbound:    .compound([.variant("freestanding handstand"), .reps(3, exerciseName: "tuck press")]),
            .ascendant:  .compound([.variant("freestanding handstand"), .reps(5, exerciseName: "tuck press")]),
        ],

        // hs.freestanding-hs-30 — Steady Handstand target: 30 s.
        // Hold-type. Prereq: freestanding-hs-10. Starts compound from novice.
        // Upper tiers cascade through tuck press → straddle press.
        "hs.freestanding-hs-30": [
            .initiate:   .variant("freestanding handstand"),
            .novice:     .compound([.variant("freestanding handstand"), .reps(3, exerciseName: "handstand pushup")]),
            .apprentice: .compound([.variant("freestanding handstand"), .reps(5, exerciseName: "handstand pushup")]),
            .forged:     .compound([.variant("freestanding handstand"), .reps(3, exerciseName: "tuck press")]),
            .veteran:    .compound([.variant("freestanding handstand"), .reps(5, exerciseName: "tuck press")]),
            .honed:      .compound([.variant("freestanding handstand"), .reps(3, exerciseName: "straddle press")]),
            .vessel:     .compound([.variant("freestanding handstand"), .reps(5, exerciseName: "straddle press")]),
            .unbound:    .compound([.variant("freestanding handstand"), .reps(1, exerciseName: "press to handstand")]),
            .ascendant:  .compound([.variant("freestanding handstand"), .reps(3, exerciseName: "press to handstand")]),
        ],

        // hs.freestanding-hs-60 — Full Handstand target: 60 s.
        // Hold-type. Prereq: freestanding-hs-30. Deeper press requirement.
        // Top tiers require the clean press-to-handstand.
        "hs.freestanding-hs-60": [
            .initiate:   .variant("freestanding handstand"),
            .novice:     .compound([.variant("freestanding handstand"), .reps(5, exerciseName: "handstand pushup")]),
            .apprentice: .compound([.variant("freestanding handstand"), .reps(3, exerciseName: "tuck press")]),
            .forged:     .compound([.variant("freestanding handstand"), .reps(5, exerciseName: "tuck press")]),
            .veteran:    .compound([.variant("freestanding handstand"), .reps(3, exerciseName: "straddle press")]),
            .honed:      .compound([.variant("freestanding handstand"), .reps(5, exerciseName: "straddle press")]),
            .vessel:     .compound([.variant("freestanding handstand"), .reps(1, exerciseName: "press to handstand")]),
            .unbound:    .compound([.variant("freestanding handstand"), .reps(3, exerciseName: "press to handstand")]),
            .ascendant:  .compound([.variant("freestanding handstand"), .reps(5, exerciseName: "press to handstand")]),
        ],

        // MARK: - Handstand Walk

        // hs.handstand-walk-10m — Handstand Walk target: 10 m / 10 steps.
        // Steps are not tracked per SetLog. Lower tiers confirm the variant was
        // logged at all. Upper tiers compound with freestanding handstand hold
        // and press variants — balance duration and press entry are the limiting
        // factors for sustained walk distance.
        "hs.handstand-walk-10m": [
            .initiate:   .variant("handstand walk"),
            .novice:     .variant("handstand walk"),
            .apprentice: .variant("handstand walk"),
            .forged:     .compound([.variant("handstand walk"), .variant("freestanding handstand")]),
            .veteran:    .compound([.variant("handstand walk"), .reps(3, exerciseName: "tuck press")]),
            .honed:      .compound([.variant("handstand walk"), .reps(5, exerciseName: "tuck press")]),
            .vessel:     .compound([.variant("handstand walk"), .reps(3, exerciseName: "straddle press")]),
            .unbound:    .compound([.variant("handstand walk"), .reps(5, exerciseName: "straddle press")]),
            .ascendant:  .compound([.variant("handstand walk"), .reps(1, exerciseName: "press to handstand")]),
        ],

        // MARK: - Press Ladder

        // hs.tuck-press — Tuck Press to Handstand; anchor: 3 reps = Forged.
        // Rep-type. Lower tiers confirm entry. Upper tiers compound with
        // handstand pushup volume — inverted pressing strength is the direct
        // limiter for pressing into and out of the tuck shape.
        "hs.tuck-press": [
            .initiate:   .reps(1, exerciseName: "tuck press"),
            .novice:     .reps(2, exerciseName: "tuck press"),
            .apprentice: .reps(3, exerciseName: "tuck press"),
            .forged:     .reps(5, exerciseName: "tuck press"),
            .veteran:    .reps(7, exerciseName: "tuck press"),
            .honed:      .compound([.reps(7, exerciseName: "tuck press"), .reps(8, exerciseName: "handstand pushup")]),
            .vessel:     .compound([.reps(10, exerciseName: "tuck press"), .reps(10, exerciseName: "handstand pushup")]),
            .unbound:    .compound([.reps(12, exerciseName: "tuck press"), .reps(12, exerciseName: "handstand pushup")]),
            .ascendant:  .compound([.reps(15, exerciseName: "tuck press"), .reps(15, exerciseName: "handstand pushup")]),
        ],

        // hs.straddle-press — Straddle Press to Handstand; anchor: 3 reps = Forged.
        // Rep-type. Harder than tuck press; prereq: hs.tuck-press. Lower tiers
        // start from straddle press entry. Upper tiers compound with
        // press-to-handstand to confirm full compression strength.
        "hs.straddle-press": [
            .initiate:   .reps(1, exerciseName: "straddle press"),
            .novice:     .reps(2, exerciseName: "straddle press"),
            .apprentice: .reps(3, exerciseName: "straddle press"),
            .forged:     .reps(5, exerciseName: "straddle press"),
            .veteran:    .reps(7, exerciseName: "straddle press"),
            .honed:      .compound([.reps(7, exerciseName: "straddle press"), .reps(8, exerciseName: "handstand pushup")]),
            .vessel:     .compound([.reps(10, exerciseName: "straddle press"), .reps(1, exerciseName: "press to handstand")]),
            .unbound:    .compound([.reps(12, exerciseName: "straddle press"), .reps(3, exerciseName: "press to handstand")]),
            .ascendant:  .compound([.reps(15, exerciseName: "straddle press"), .reps(5, exerciseName: "press to handstand")]),
        ],

        // hs.press-to-handstand — Press to Handstand (straight legs); anchor: 1 rep = Forged.
        // Rep-type. Elite move. Lower tiers cascade through tuck press and straddle
        // press as proof of compression base. Upper tiers compound with higher
        // rep counts and handstand pushup volume.
        "hs.press-to-handstand": [
            .initiate:   .reps(1, exerciseName: "tuck press"),
            .novice:     .reps(3, exerciseName: "tuck press"),
            .apprentice: .reps(1, exerciseName: "straddle press"),
            .forged:     .reps(1, exerciseName: "press to handstand"),
            .veteran:    .reps(2, exerciseName: "press to handstand"),
            .honed:      .reps(3, exerciseName: "press to handstand"),
            .vessel:     .compound([.reps(5, exerciseName: "press to handstand"), .reps(10, exerciseName: "handstand pushup")]),
            .unbound:    .compound([.reps(7, exerciseName: "press to handstand"), .reps(12, exerciseName: "handstand pushup")]),
            .ascendant:  .compound([.reps(10, exerciseName: "press to handstand"), .reps(15, exerciseName: "handstand pushup")]),
        ],

        // MARK: - Arm Balances

        // hs.frog-pose — Frog Pose hold target: 15 s.
        // Hold-type. Entry-level arm balance. Lower tiers confirm any frog
        // pose log. Upper tiers compound with crow pose — the natural next
        // arm balance in the progression.
        "hs.frog-pose": [
            .initiate:   .variant("frog pose"),
            .novice:     .variant("frog pose"),
            .apprentice: .variant("frog pose"),
            .forged:     .compound([.variant("frog pose"), .reps(10, exerciseName: "pushup")]),
            .veteran:    .compound([.variant("frog pose"), .reps(20, exerciseName: "pushup")]),
            .honed:      .compound([.variant("frog pose"), .variant("crow pose")]),
            .vessel:     .compound([.variant("frog pose"), .reps(5, exerciseName: "pushup")]),
            .unbound:    .compound([.variant("frog pose"), .variant("crane pose")]),
            .ascendant:  .compound([.variant("frog pose"), .variant("flying crow")]),
        ],

        // hs.crow-pose — Crow Pose hold target: 15 s.
        // Hold-type. Classic arm balance. Lower tiers confirm any crow pose log.
        // Upper tiers compound with crane pose — the straight-arm extension.
        "hs.crow-pose": [
            .initiate:   .variant("crow pose"),
            .novice:     .variant("crow pose"),
            .apprentice: .variant("crow pose"),
            .forged:     .compound([.variant("crow pose"), .reps(10, exerciseName: "pushup")]),
            .veteran:    .compound([.variant("crow pose"), .reps(20, exerciseName: "pushup")]),
            .honed:      .compound([.variant("crow pose"), .variant("crane pose")]),
            .vessel:     .compound([.variant("crow pose"), .reps(3, exerciseName: "handstand pushup")]),
            .unbound:    .compound([.variant("crow pose"), .reps(5, exerciseName: "handstand pushup")]),
            .ascendant:  .compound([.variant("crow pose"), .variant("flying crow")]),
        ],

        // hs.crane-pose — Crane Pose hold target: 10 s.
        // Hold-type. Straight-arm crow; harder than crow pose. Lower tiers
        // confirm crow base. Upper tiers compound with flying crow.
        "hs.crane-pose": [
            .initiate:   .variant("crow pose"),
            .novice:     .compound([.variant("crow pose"), .reps(10, exerciseName: "pushup")]),
            .apprentice: .variant("crane pose"),
            .forged:     .compound([.variant("crane pose"), .reps(5, exerciseName: "handstand pushup")]),
            .veteran:    .compound([.variant("crane pose"), .reps(8, exerciseName: "handstand pushup")]),
            .honed:      .compound([.variant("crane pose"), .reps(10, exerciseName: "handstand pushup")]),
            .vessel:     .compound([.variant("crane pose"), .variant("flying crow")]),
            .unbound:    .compound([.variant("crane pose"), .reps(3, exerciseName: "tuck press")]),
            .ascendant:  .compound([.variant("crane pose"), .reps(5, exerciseName: "tuck press")]),
        ],

        // hs.flying-crow — Flying Crow Pose hold target: 5 s.
        // Hold-type. Advanced asymmetric arm balance. Prereq: crane pose.
        // Lower tiers cascade through crane. Upper tiers compound with
        // freestanding handstand to confirm full overhead balance capability.
        "hs.flying-crow": [
            .initiate:   .variant("crow pose"),
            .novice:     .variant("crane pose"),
            .apprentice: .variant("flying crow"),
            .forged:     .compound([.variant("flying crow"), .reps(5, exerciseName: "handstand pushup")]),
            .veteran:    .compound([.variant("flying crow"), .reps(8, exerciseName: "handstand pushup")]),
            .honed:      .compound([.variant("flying crow"), .reps(10, exerciseName: "handstand pushup")]),
            .vessel:     .compound([.variant("flying crow"), .variant("freestanding handstand")]),
            .unbound:    .compound([.variant("flying crow"), .reps(3, exerciseName: "tuck press")]),
            .ascendant:  .compound([.variant("flying crow"), .reps(5, exerciseName: "tuck press")]),
        ],

        // MARK: - Elbow Levers

        // hs.elbow-lever — Elbow Lever hold target: 10 s.
        // Hold-type. Horizontal arm balance on elbows. Lower tiers confirm any
        // elbow lever log. Upper tiers compound with freestanding handstand —
        // shoulder and wrist balance awareness transfers directly.
        "hs.elbow-lever": [
            .initiate:   .variant("elbow lever"),
            .novice:     .variant("elbow lever"),
            .apprentice: .variant("elbow lever"),
            .forged:     .compound([.variant("elbow lever"), .reps(10, exerciseName: "pushup")]),
            .veteran:    .compound([.variant("elbow lever"), .reps(20, exerciseName: "pushup")]),
            .honed:      .compound([.variant("elbow lever"), .variant("freestanding handstand")]),
            .vessel:     .compound([.variant("elbow lever"), .reps(5, exerciseName: "handstand pushup")]),
            .unbound:    .compound([.variant("elbow lever"), .reps(8, exerciseName: "handstand pushup")]),
            .ascendant:  .compound([.variant("elbow lever"), .variant("one-arm elbow lever")]),
        ],

        // hs.one-arm-elbow-lever — One-Arm Elbow Lever hold target: 5 s.
        // Hold-type. Mythic horizontal balance. Cascade from two-arm elbow
        // lever. Upper tiers compound with freestanding handstand and press
        // skills for full upper-body mastery confirmation.
        "hs.one-arm-elbow-lever": [
            .initiate:   .variant("elbow lever"),
            .novice:     .compound([.variant("elbow lever"), .reps(10, exerciseName: "pushup")]),
            .apprentice: .variant("one-arm elbow lever"),
            .forged:     .compound([.variant("one-arm elbow lever"), .reps(5, exerciseName: "handstand pushup")]),
            .veteran:    .compound([.variant("one-arm elbow lever"), .reps(8, exerciseName: "handstand pushup")]),
            .honed:      .compound([.variant("one-arm elbow lever"), .reps(10, exerciseName: "handstand pushup")]),
            .vessel:     .compound([.variant("one-arm elbow lever"), .variant("freestanding handstand")]),
            .unbound:    .compound([.variant("one-arm elbow lever"), .reps(3, exerciseName: "tuck press")]),
            .ascendant:  .compound([.variant("one-arm elbow lever"), .reps(5, exerciseName: "tuck press")]),
        ],

        // MARK: - One-Arm Wall Supported

        // hs.wall-supported-oah — Wall Supported One-Arm Handstand hold target: 5 s.
        // Hold-type. Entry to one-arm work with wall assistance. Cascade through
        // freestanding handstand and press skills. Upper tiers compound with
        // one-arm elbow lever — wrist/shoulder unilateral strength confirmation.
        "hs.wall-supported-oah": [
            .initiate:   .variant("wall handstand"),
            .novice:     .compound([.variant("wall handstand"), .reps(8, exerciseName: "handstand pushup")]),
            .apprentice: .variant("wall-supported one-arm handstand"),
            .forged:     .compound([.variant("wall-supported one-arm handstand"), .reps(5, exerciseName: "handstand pushup")]),
            .veteran:    .compound([.variant("wall-supported one-arm handstand"), .reps(8, exerciseName: "handstand pushup")]),
            .honed:      .compound([.variant("wall-supported one-arm handstand"), .reps(10, exerciseName: "handstand pushup")]),
            .vessel:     .compound([.variant("wall-supported one-arm handstand"), .variant("freestanding handstand")]),
            .unbound:    .compound([.variant("wall-supported one-arm handstand"), .variant("one-arm elbow lever")]),
            .ascendant:  .compound([.variant("wall-supported one-arm handstand"), .reps(3, exerciseName: "press to handstand")]),
        ],
    ]
}
