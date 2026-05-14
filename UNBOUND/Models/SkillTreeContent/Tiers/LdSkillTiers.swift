// UNBOUND/Models/SkillTreeContent/Tiers/LdSkillTiers.swift
//
// Tier criteria for every skill with prefix `ld.` (31 skills).
// Lower body / legs / glutes / pistol family. See CalSkillTiers for pattern.
//
// Progression chains encoded here:
//   Squat ladder : glute-bridge → goblet-20 → tempo-squat → bw-front-squat →
//                  jumping-squat → floor-to-ceiling-squat
//   Pistol ladder: shrimp → assisted-pistol → pistol → weighted-pistol →
//                  heighted-pistol → dragon-pistol → jumping-pistol
//   Bulgarian    : bulgarian-split → heighted-split-squat → weighted-bss
//   Hamstring    : hip-hinge → nordic-hip-hinge → advancing-nordic-curl →
//                  nordic-curl (elite)
//   Glute        : glute-bridge → single-leg-glute-bridge → fire-hydrant →
//                  flying-kickback
//   Calves       : calf-raise → weighted-sl-calf
//   Solo         : step-up, deep-squat (hold), sissy-squat, single-leg-rdl,
//                  100-lunges, box-jump
//
// Hold-type skill (deep-squat):
//   .variant("deep squat") confirms any logged session. Upper tiers compound
//   with goblet squat reps to confirm active mobility + quad strength.
//
// Loaded skills (bw-front-squat, weighted-pistol, weighted-sl-calf, weighted-bss):
//   Lower tiers use .variant to confirm any logged session.
//   Upper tiers use .compound([.variant(name), .bodyweightRatio(r)]) so the
//   exercise is confirmed before the ratio gate fires — prevents false-positives
//   from unrelated heavy lifts. Pattern from CalSkillTiers cal.weighted-dip.

import Foundation

#if DEBUG
private let _ldCountCheck: Int = {
    assert(
        LdSkillTiers.table.count == 31,
        "ld cluster should have 31 entries, has \(LdSkillTiers.table.count)"
    )
    for (id, tiers) in LdSkillTiers.table {
        assert(tiers.count == 9, "\(id) needs 9 tiers, has \(tiers.count)")
        for tier in SkillTier.allCases {
            assert(tiers[tier] != nil, "\(id) missing tier \(tier)")
        }
    }
    return LdSkillTiers.table.count
}()
#endif

enum LdSkillTiers {
    static let table: [String: [SkillTier: TierCriterion]] = [

        // MARK: - Squat Ladder — Base

        // ld.glute-bridge — ground-level posterior-chain entry; anchor: 15 reps = Forged
        "ld.glute-bridge": [
            .initiate:   .reps(5,  exerciseName: "glute bridge"),
            .novice:     .reps(8,  exerciseName: "glute bridge"),
            .apprentice: .reps(10, exerciseName: "glute bridge"),
            .forged:     .reps(15, exerciseName: "glute bridge"),
            .veteran:    .reps(20, exerciseName: "glute bridge"),
            .honed:      .reps(30, exerciseName: "glute bridge"),
            .vessel:     .reps(40, exerciseName: "glute bridge"),
            .unbound:    .reps(55, exerciseName: "glute bridge"),
            .ascendant:  .reps(75, exerciseName: "glute bridge"),
        ],

        // ld.goblet-20 — goblet squat with load (0.5× bw); lower tiers confirm
        // any goblet squat session; upper tiers add bodyweightRatio gate.
        "ld.goblet-20": [
            .initiate:   .variant("goblet squat"),
            .novice:     .compound([.variant("goblet squat"), .bodyweightRatio(0.10)]),
            .apprentice: .compound([.variant("goblet squat"), .bodyweightRatio(0.20)]),
            .forged:     .compound([.variant("goblet squat"), .bodyweightRatio(0.30)]),
            .veteran:    .compound([.variant("goblet squat"), .bodyweightRatio(0.40)]),
            .honed:      .compound([.variant("goblet squat"), .bodyweightRatio(0.50)]),
            .vessel:     .compound([.variant("goblet squat"), .bodyweightRatio(0.65)]),
            .unbound:    .compound([.variant("goblet squat"), .bodyweightRatio(0.80)]),
            .ascendant:  .compound([.variant("goblet squat"), .bodyweightRatio(1.00)]),
        ],

        // ld.tempo-squat — controlled eccentric squat; anchor: 10 reps = Forged
        "ld.tempo-squat": [
            .initiate:   .reps(3,  exerciseName: "tempo squat"),
            .novice:     .reps(5,  exerciseName: "tempo squat"),
            .apprentice: .reps(7,  exerciseName: "tempo squat"),
            .forged:     .reps(10, exerciseName: "tempo squat"),
            .veteran:    .reps(15, exerciseName: "tempo squat"),
            .honed:      .reps(20, exerciseName: "tempo squat"),
            .vessel:     .reps(25, exerciseName: "tempo squat"),
            .unbound:    .reps(30, exerciseName: "tempo squat"),
            .ascendant:  .reps(40, exerciseName: "tempo squat"),
        ],

        // ld.bw-front-squat — front squat at bodyweight; lower tiers confirm
        // any front squat. Upper tiers add bodyweightRatio gate (1.0×+ loads).
        "ld.bw-front-squat": [
            .initiate:   .variant("front squat"),
            .novice:     .compound([.variant("front squat"), .bodyweightRatio(0.30)]),
            .apprentice: .compound([.variant("front squat"), .bodyweightRatio(0.50)]),
            .forged:     .compound([.variant("front squat"), .bodyweightRatio(0.75)]),
            .veteran:    .compound([.variant("front squat"), .bodyweightRatio(1.00)]),
            .honed:      .compound([.variant("front squat"), .bodyweightRatio(1.25)]),
            .vessel:     .compound([.variant("front squat"), .bodyweightRatio(1.50)]),
            .unbound:    .compound([.variant("front squat"), .bodyweightRatio(1.75)]),
            .ascendant:  .compound([.variant("front squat"), .bodyweightRatio(2.00)]),
        ],

        // ld.jumping-squat — plyometric squat; anchor: 10 reps = Forged
        "ld.jumping-squat": [
            .initiate:   .reps(3,  exerciseName: "jumping squat"),
            .novice:     .reps(5,  exerciseName: "jumping squat"),
            .apprentice: .reps(7,  exerciseName: "jumping squat"),
            .forged:     .reps(10, exerciseName: "jumping squat"),
            .veteran:    .reps(15, exerciseName: "jumping squat"),
            .honed:      .reps(20, exerciseName: "jumping squat"),
            .vessel:     .reps(25, exerciseName: "jumping squat"),
            .unbound:    .reps(30, exerciseName: "jumping squat"),
            .ascendant:  .reps(40, exerciseName: "jumping squat"),
        ],

        // ld.floor-to-ceiling-squat — elite mobility squat; anchor: 1 rep = Forged
        "ld.floor-to-ceiling-squat": [
            .initiate:   .reps(1, exerciseName: "floor to ceiling squat"),
            .novice:     .reps(2, exerciseName: "floor to ceiling squat"),
            .apprentice: .reps(3, exerciseName: "floor to ceiling squat"),
            .forged:     .reps(4, exerciseName: "floor to ceiling squat"),
            .veteran:    .reps(5, exerciseName: "floor to ceiling squat"),
            .honed:      .reps(7, exerciseName: "floor to ceiling squat"),
            .vessel:     .reps(10, exerciseName: "floor to ceiling squat"),
            .unbound:    .reps(13, exerciseName: "floor to ceiling squat"),
            .ascendant:  .reps(16, exerciseName: "floor to ceiling squat"),
        ],

        // MARK: - Pistol Ladder

        // ld.shrimp-squat — single-leg squat regression; anchor: 3 reps = Forged
        "ld.shrimp-squat": [
            .initiate:   .reps(1,  exerciseName: "shrimp squat"),
            .novice:     .reps(2,  exerciseName: "shrimp squat"),
            .apprentice: .reps(3,  exerciseName: "shrimp squat"),
            .forged:     .reps(5,  exerciseName: "shrimp squat"),
            .veteran:    .reps(8,  exerciseName: "shrimp squat"),
            .honed:      .reps(10, exerciseName: "shrimp squat"),
            .vessel:     .reps(12, exerciseName: "shrimp squat"),
            .unbound:    .reps(15, exerciseName: "shrimp squat"),
            .ascendant:  .reps(20, exerciseName: "shrimp squat"),
        ],

        // ld.assisted-pistol — banded/assisted pistol squat; anchor: 5 reps = Forged
        "ld.assisted-pistol": [
            .initiate:   .reps(2,  exerciseName: "assisted pistol"),
            .novice:     .reps(3,  exerciseName: "assisted pistol"),
            .apprentice: .reps(4,  exerciseName: "assisted pistol"),
            .forged:     .reps(5,  exerciseName: "assisted pistol"),
            .veteran:    .reps(8,  exerciseName: "assisted pistol"),
            .honed:      .reps(10, exerciseName: "assisted pistol"),
            .vessel:     .reps(12, exerciseName: "assisted pistol"),
            .unbound:    .reps(15, exerciseName: "assisted pistol"),
            .ascendant:  .reps(20, exerciseName: "assisted pistol"),
        ],

        // ld.pistol-squat — full pistol squat; anchor: 5 reps = Forged
        "ld.pistol-squat": [
            .initiate:   .reps(1,  exerciseName: "pistol squat"),
            .novice:     .reps(2,  exerciseName: "pistol squat"),
            .apprentice: .reps(3,  exerciseName: "pistol squat"),
            .forged:     .reps(5,  exerciseName: "pistol squat"),
            .veteran:    .reps(8,  exerciseName: "pistol squat"),
            .honed:      .reps(10, exerciseName: "pistol squat"),
            .vessel:     .reps(12, exerciseName: "pistol squat"),
            .unbound:    .reps(15, exerciseName: "pistol squat"),
            .ascendant:  .reps(20, exerciseName: "pistol squat"),
        ],

        // ld.weighted-pistol — loaded pistol at 0.5× bw; lower tiers confirm any
        // weighted pistol. Upper tiers gate on bodyweightRatio.
        "ld.weighted-pistol": [
            .initiate:   .variant("weighted pistol"),
            .novice:     .compound([.variant("weighted pistol"), .bodyweightRatio(0.10)]),
            .apprentice: .compound([.variant("weighted pistol"), .bodyweightRatio(0.20)]),
            .forged:     .compound([.variant("weighted pistol"), .bodyweightRatio(0.35)]),
            .veteran:    .compound([.variant("weighted pistol"), .bodyweightRatio(0.50)]),
            .honed:      .compound([.variant("weighted pistol"), .bodyweightRatio(0.65)]),
            .vessel:     .compound([.variant("weighted pistol"), .bodyweightRatio(0.80)]),
            .unbound:    .compound([.variant("weighted pistol"), .bodyweightRatio(1.00)]),
            .ascendant:  .compound([.variant("weighted pistol"), .bodyweightRatio(1.25)]),
        ],

        // ld.heighted-pistol — elevated/deficit pistol squat; anchor: 3 reps = Forged
        "ld.heighted-pistol": [
            .initiate:   .reps(1, exerciseName: "elevated pistol"),
            .novice:     .reps(2, exerciseName: "elevated pistol"),
            .apprentice: .reps(3, exerciseName: "elevated pistol"),
            .forged:     .reps(4, exerciseName: "elevated pistol"),
            .veteran:    .reps(5, exerciseName: "elevated pistol"),
            .honed:      .reps(7, exerciseName: "elevated pistol"),
            .vessel:     .reps(8, exerciseName: "elevated pistol"),
            .unbound:    .reps(10, exerciseName: "elevated pistol"),
            .ascendant:  .reps(12, exerciseName: "elevated pistol"),
        ],

        // ld.dragon-pistol — dragon pistol squat (rear leg extended); anchor: 1 rep = Forged
        "ld.dragon-pistol": [
            .initiate:   .reps(1, exerciseName: "dragon pistol"),
            .novice:     .reps(2, exerciseName: "dragon pistol"),
            .apprentice: .reps(3, exerciseName: "dragon pistol"),
            .forged:     .reps(4, exerciseName: "dragon pistol"),
            .veteran:    .reps(5, exerciseName: "dragon pistol"),
            .honed:      .reps(6, exerciseName: "dragon pistol"),
            .vessel:     .reps(8, exerciseName: "dragon pistol"),
            .unbound:    .reps(10, exerciseName: "dragon pistol"),
            .ascendant:  .reps(12, exerciseName: "dragon pistol"),
        ],

        // ld.jumping-pistol — explosive single-leg squat + jump; anchor: 3 reps = Forged
        "ld.jumping-pistol": [
            .initiate:   .reps(1, exerciseName: "jumping pistol"),
            .novice:     .reps(2, exerciseName: "jumping pistol"),
            .apprentice: .reps(3, exerciseName: "jumping pistol"),
            .forged:     .reps(4, exerciseName: "jumping pistol"),
            .veteran:    .reps(5, exerciseName: "jumping pistol"),
            .honed:      .reps(6, exerciseName: "jumping pistol"),
            .vessel:     .reps(8, exerciseName: "jumping pistol"),
            .unbound:    .reps(10, exerciseName: "jumping pistol"),
            .ascendant:  .reps(12, exerciseName: "jumping pistol"),
        ],

        // MARK: - Bulgarian Split Squat Ladder

        // ld.bulgarian-split-squat — rear-foot-elevated split squat; anchor: 10 reps = Forged
        "ld.bulgarian-split-squat": [
            .initiate:   .reps(3,  exerciseName: "bulgarian split squat"),
            .novice:     .reps(5,  exerciseName: "bulgarian split squat"),
            .apprentice: .reps(7,  exerciseName: "bulgarian split squat"),
            .forged:     .reps(10, exerciseName: "bulgarian split squat"),
            .veteran:    .reps(15, exerciseName: "bulgarian split squat"),
            .honed:      .reps(20, exerciseName: "bulgarian split squat"),
            .vessel:     .reps(25, exerciseName: "bulgarian split squat"),
            .unbound:    .reps(30, exerciseName: "bulgarian split squat"),
            .ascendant:  .reps(40, exerciseName: "bulgarian split squat"),
        ],

        // ld.heighted-split-squat — elevated bulgarian split squat; anchor: 8 reps = Forged
        "ld.heighted-split-squat": [
            .initiate:   .reps(3,  exerciseName: "elevated bulgarian split squat"),
            .novice:     .reps(4,  exerciseName: "elevated bulgarian split squat"),
            .apprentice: .reps(6,  exerciseName: "elevated bulgarian split squat"),
            .forged:     .reps(8,  exerciseName: "elevated bulgarian split squat"),
            .veteran:    .reps(12, exerciseName: "elevated bulgarian split squat"),
            .honed:      .reps(15, exerciseName: "elevated bulgarian split squat"),
            .vessel:     .reps(20, exerciseName: "elevated bulgarian split squat"),
            .unbound:    .reps(25, exerciseName: "elevated bulgarian split squat"),
            .ascendant:  .reps(30, exerciseName: "elevated bulgarian split squat"),
        ],

        // ld.weighted-bss — weighted bulgarian split squat (0.5× bw); lower tiers
        // confirm any weighted bss session. Upper tiers gate on bodyweightRatio.
        "ld.weighted-bss": [
            .initiate:   .variant("weighted bss"),
            .novice:     .compound([.variant("weighted bss"), .bodyweightRatio(0.15)]),
            .apprentice: .compound([.variant("weighted bss"), .bodyweightRatio(0.30)]),
            .forged:     .compound([.variant("weighted bss"), .bodyweightRatio(0.50)]),
            .veteran:    .compound([.variant("weighted bss"), .bodyweightRatio(0.70)]),
            .honed:      .compound([.variant("weighted bss"), .bodyweightRatio(0.90)]),
            .vessel:     .compound([.variant("weighted bss"), .bodyweightRatio(1.10)]),
            .unbound:    .compound([.variant("weighted bss"), .bodyweightRatio(1.30)]),
            .ascendant:  .compound([.variant("weighted bss"), .bodyweightRatio(1.60)]),
        ],

        // MARK: - Hamstring Chain

        // ld.hip-hinge — hinge pattern base; anchor: 15 reps = Forged
        "ld.hip-hinge": [
            .initiate:   .reps(5,  exerciseName: "hip hinge"),
            .novice:     .reps(8,  exerciseName: "hip hinge"),
            .apprentice: .reps(10, exerciseName: "hip hinge"),
            .forged:     .reps(15, exerciseName: "hip hinge"),
            .veteran:    .reps(20, exerciseName: "hip hinge"),
            .honed:      .reps(25, exerciseName: "hip hinge"),
            .vessel:     .reps(30, exerciseName: "hip hinge"),
            .unbound:    .reps(40, exerciseName: "hip hinge"),
            .ascendant:  .reps(50, exerciseName: "hip hinge"),
        ],

        // ld.nordic-hip-hinge — nordic hip hinge (partner-anchored or band);
        // anchor: 8 reps = Forged
        "ld.nordic-hip-hinge": [
            .initiate:   .reps(3,  exerciseName: "nordic hip hinge"),
            .novice:     .reps(4,  exerciseName: "nordic hip hinge"),
            .apprentice: .reps(5,  exerciseName: "nordic hip hinge"),
            .forged:     .reps(8,  exerciseName: "nordic hip hinge"),
            .veteran:    .reps(10, exerciseName: "nordic hip hinge"),
            .honed:      .reps(12, exerciseName: "nordic hip hinge"),
            .vessel:     .reps(15, exerciseName: "nordic hip hinge"),
            .unbound:    .reps(18, exerciseName: "nordic hip hinge"),
            .ascendant:  .reps(20, exerciseName: "nordic hip hinge"),
        ],

        // ld.advancing-nordic-curl — eccentric nordic curl progression;
        // anchor: 3 reps = Forged
        "ld.advancing-nordic-curl": [
            .initiate:   .reps(1, exerciseName: "nordic curl"),
            .novice:     .reps(2, exerciseName: "nordic curl"),
            .apprentice: .reps(3, exerciseName: "nordic curl"),
            .forged:     .reps(4, exerciseName: "nordic curl"),
            .veteran:    .reps(5, exerciseName: "nordic curl"),
            .honed:      .reps(6, exerciseName: "nordic curl"),
            .vessel:     .reps(8, exerciseName: "nordic curl"),
            .unbound:    .reps(10, exerciseName: "nordic curl"),
            .ascendant:  .reps(12, exerciseName: "nordic curl"),
        ],

        // ld.nordic-curl — full nordic curl (elite hamstring); anchor: 3 reps = Forged
        "ld.nordic-curl": [
            .initiate:   .reps(1,  exerciseName: "nordic curl"),
            .novice:     .reps(2,  exerciseName: "nordic curl"),
            .apprentice: .reps(3,  exerciseName: "nordic curl"),
            .forged:     .reps(5,  exerciseName: "nordic curl"),
            .veteran:    .reps(7,  exerciseName: "nordic curl"),
            .honed:      .reps(10, exerciseName: "nordic curl"),
            .vessel:     .reps(12, exerciseName: "nordic curl"),
            .unbound:    .reps(15, exerciseName: "nordic curl"),
            .ascendant:  .reps(20, exerciseName: "nordic curl"),
        ],

        // MARK: - Glute Chain

        // ld.single-leg-glute-bridge — unilateral glute bridge; anchor: 10 reps = Forged
        "ld.single-leg-glute-bridge": [
            .initiate:   .reps(3,  exerciseName: "single-leg glute bridge"),
            .novice:     .reps(5,  exerciseName: "single-leg glute bridge"),
            .apprentice: .reps(7,  exerciseName: "single-leg glute bridge"),
            .forged:     .reps(10, exerciseName: "single-leg glute bridge"),
            .veteran:    .reps(15, exerciseName: "single-leg glute bridge"),
            .honed:      .reps(20, exerciseName: "single-leg glute bridge"),
            .vessel:     .reps(25, exerciseName: "single-leg glute bridge"),
            .unbound:    .reps(30, exerciseName: "single-leg glute bridge"),
            .ascendant:  .reps(40, exerciseName: "single-leg glute bridge"),
        ],

        // ld.fire-hydrant — hip abduction exercise; anchor: 15 reps = Forged
        "ld.fire-hydrant": [
            .initiate:   .reps(5,  exerciseName: "fire hydrant"),
            .novice:     .reps(8,  exerciseName: "fire hydrant"),
            .apprentice: .reps(10, exerciseName: "fire hydrant"),
            .forged:     .reps(15, exerciseName: "fire hydrant"),
            .veteran:    .reps(20, exerciseName: "fire hydrant"),
            .honed:      .reps(25, exerciseName: "fire hydrant"),
            .vessel:     .reps(30, exerciseName: "fire hydrant"),
            .unbound:    .reps(40, exerciseName: "fire hydrant"),
            .ascendant:  .reps(50, exerciseName: "fire hydrant"),
        ],

        // ld.flying-kickback — glute kickback (logged as "fire kickback");
        // anchor: 12 reps = Forged
        "ld.flying-kickback": [
            .initiate:   .reps(5,  exerciseName: "fire kickback"),
            .novice:     .reps(7,  exerciseName: "fire kickback"),
            .apprentice: .reps(10, exerciseName: "fire kickback"),
            .forged:     .reps(12, exerciseName: "fire kickback"),
            .veteran:    .reps(15, exerciseName: "fire kickback"),
            .honed:      .reps(20, exerciseName: "fire kickback"),
            .vessel:     .reps(25, exerciseName: "fire kickback"),
            .unbound:    .reps(30, exerciseName: "fire kickback"),
            .ascendant:  .reps(40, exerciseName: "fire kickback"),
        ],

        // MARK: - Calves

        // ld.calf-raise — bilateral calf raise; anchor: 20 reps = Forged
        "ld.calf-raise": [
            .initiate:   .reps(8,  exerciseName: "calf raise"),
            .novice:     .reps(12, exerciseName: "calf raise"),
            .apprentice: .reps(15, exerciseName: "calf raise"),
            .forged:     .reps(20, exerciseName: "calf raise"),
            .veteran:    .reps(30, exerciseName: "calf raise"),
            .honed:      .reps(40, exerciseName: "calf raise"),
            .vessel:     .reps(60, exerciseName: "calf raise"),
            .unbound:    .reps(80, exerciseName: "calf raise"),
            .ascendant:  .reps(100, exerciseName: "calf raise"),
        ],

        // ld.weighted-sl-calf — weighted single-leg calf raise (0.5× bw); lower
        // tiers confirm any single-leg calf raise. Upper tiers gate on bodyweightRatio.
        "ld.weighted-sl-calf": [
            .initiate:   .variant("single-leg calf raise"),
            .novice:     .compound([.variant("single-leg calf raise"), .bodyweightRatio(0.10)]),
            .apprentice: .compound([.variant("single-leg calf raise"), .bodyweightRatio(0.20)]),
            .forged:     .compound([.variant("single-leg calf raise"), .bodyweightRatio(0.35)]),
            .veteran:    .compound([.variant("single-leg calf raise"), .bodyweightRatio(0.50)]),
            .honed:      .compound([.variant("single-leg calf raise"), .bodyweightRatio(0.70)]),
            .vessel:     .compound([.variant("single-leg calf raise"), .bodyweightRatio(0.90)]),
            .unbound:    .compound([.variant("single-leg calf raise"), .bodyweightRatio(1.10)]),
            .ascendant:  .compound([.variant("single-leg calf raise"), .bodyweightRatio(1.40)]),
        ],

        // MARK: - Solo Skills

        // ld.100-lunges — lunge walk endurance; anchor: 40 reps = Forged
        // (no .steps type; logged as reps against "walking lunge")
        "ld.100-lunges": [
            .initiate:   .reps(10,  exerciseName: "walking lunge"),
            .novice:     .reps(20,  exerciseName: "walking lunge"),
            .apprentice: .reps(30,  exerciseName: "walking lunge"),
            .forged:     .reps(40,  exerciseName: "walking lunge"),
            .veteran:    .reps(60,  exerciseName: "walking lunge"),
            .honed:      .reps(80,  exerciseName: "walking lunge"),
            .vessel:     .reps(100, exerciseName: "walking lunge"),
            .unbound:    .reps(120, exerciseName: "walking lunge"),
            .ascendant:  .reps(150, exerciseName: "walking lunge"),
        ],

        // ld.single-leg-rdl — single-leg Romanian deadlift; anchor: 10 reps = Forged
        "ld.single-leg-rdl": [
            .initiate:   .reps(3,  exerciseName: "single-leg rdl"),
            .novice:     .reps(5,  exerciseName: "single-leg rdl"),
            .apprentice: .reps(7,  exerciseName: "single-leg rdl"),
            .forged:     .reps(10, exerciseName: "single-leg rdl"),
            .veteran:    .reps(12, exerciseName: "single-leg rdl"),
            .honed:      .reps(15, exerciseName: "single-leg rdl"),
            .vessel:     .reps(18, exerciseName: "single-leg rdl"),
            .unbound:    .reps(20, exerciseName: "single-leg rdl"),
            .ascendant:  .reps(25, exerciseName: "single-leg rdl"),
        ],

        // ld.box-jump — plyometric jump; anchor: 5 reps = Forged
        "ld.box-jump": [
            .initiate:   .reps(2,  exerciseName: "box jump"),
            .novice:     .reps(3,  exerciseName: "box jump"),
            .apprentice: .reps(4,  exerciseName: "box jump"),
            .forged:     .reps(5,  exerciseName: "box jump"),
            .veteran:    .reps(8,  exerciseName: "box jump"),
            .honed:      .reps(10, exerciseName: "box jump"),
            .vessel:     .reps(15, exerciseName: "box jump"),
            .unbound:    .reps(20, exerciseName: "box jump"),
            .ascendant:  .reps(25, exerciseName: "box jump"),
        ],

        // ld.step-up — unilateral step-up; anchor: 15 reps = Forged
        "ld.step-up": [
            .initiate:   .reps(5,  exerciseName: "step up"),
            .novice:     .reps(8,  exerciseName: "step up"),
            .apprentice: .reps(10, exerciseName: "step up"),
            .forged:     .reps(15, exerciseName: "step up"),
            .veteran:    .reps(20, exerciseName: "step up"),
            .honed:      .reps(25, exerciseName: "step up"),
            .vessel:     .reps(30, exerciseName: "step up"),
            .unbound:    .reps(40, exerciseName: "step up"),
            .ascendant:  .reps(50, exerciseName: "step up"),
        ],

        // ld.deep-squat — hold-type passive mobility squat; duration not tracked.
        // Lower tiers confirm any logged deep squat session. Upper tiers compound
        // with goblet squat to confirm active strength in the deep range.
        "ld.deep-squat": [
            .initiate:   .variant("deep squat"),
            .novice:     .variant("deep squat"),
            .apprentice: .variant("deep squat"),
            .forged:     .compound([.variant("deep squat"), .reps(10, exerciseName: "goblet squat")]),
            .veteran:    .compound([.variant("deep squat"), .reps(15, exerciseName: "goblet squat")]),
            .honed:      .compound([.variant("deep squat"), .reps(20, exerciseName: "goblet squat")]),
            .vessel:     .compound([.variant("deep squat"), .reps(25, exerciseName: "goblet squat")]),
            .unbound:    .compound([.variant("deep squat"), .reps(30, exerciseName: "goblet squat")]),
            .ascendant:  .compound([.variant("deep squat"), .reps(40, exerciseName: "goblet squat")]),
        ],

        // ld.sissy-squat — quad-dominant extreme knee flexion; anchor: 8 reps = Forged
        "ld.sissy-squat": [
            .initiate:   .reps(2,  exerciseName: "sissy squat"),
            .novice:     .reps(3,  exerciseName: "sissy squat"),
            .apprentice: .reps(5,  exerciseName: "sissy squat"),
            .forged:     .reps(8,  exerciseName: "sissy squat"),
            .veteran:    .reps(12, exerciseName: "sissy squat"),
            .honed:      .reps(15, exerciseName: "sissy squat"),
            .vessel:     .reps(20, exerciseName: "sissy squat"),
            .unbound:    .reps(25, exerciseName: "sissy squat"),
            .ascendant:  .reps(30, exerciseName: "sissy squat"),
        ],
    ]
}
