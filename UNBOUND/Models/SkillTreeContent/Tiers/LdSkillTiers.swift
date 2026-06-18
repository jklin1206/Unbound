// UNBOUND/Models/SkillTreeContent/Tiers/LdSkillTiers.swift
//
// Tier criteria for the legs family (ld.*, 24 skills) — GENERATED from real-data
// anchors (LegsSkillAnchors + SkillTierGenerator), replacing the old hand-authored
// 9-tier-per-node tables (the source of the distribution mess). Grind moves spread
// real strengthlevel standards across the 9 tiers; weighted nodes gate on added
// %bw. The node's difficulty (SkillNode.tier, used by trials) is unchanged — only
// the per-node rank ladder is generated here. Mirrors PpSkillTiers (pull family).
//
// Grounding (docs/strength-standards-harvest.md, @180 lb male):
//   bodyweight squat  < 1 / 17 / 56 / 107 / 167   (Beginner "< 1" → 1)
//   pistol squat      < 1 / 3 / 13 / 25 / 38
//   lunge             < 1 / 11 / 37 / 69 / 105
//   squat jump        source rows exist, but app ladder caps it as low-rep power
//   nordic curl       source rows exist, but app ladder caps it as high-tension reps
//   weighted (added %bw, docs/standards-weighted.md): pistol 0–15/15–30/30–50/50–70/90%+
//
// Legs rep out — there are no true "1-rep-only world-class" feats in this list,
// so EVERY node is a GRIND (.full) or WEIGHTED (.bodyweightRatio .full). No .feat.
// The 10 dead orphan nodes (100-lunges, assisted-pistol, bw-front-squat,
// dragon-pistol, heighted-pistol, heighted-split-squat, hip-hinge, jumping-pistol,
// single-leg-rdl, tempo-squat) are dropped — zero consumers.

import Foundation

import Foundation

#if DEBUG
private let _ldCountCheck: Int = {
    assert(
        LdSkillTiers.table.count == 24,
        "ld cluster should have 24 entries, has \(LdSkillTiers.table.count)"
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

// MARK: - Legs family anchors (canonical nodes — real data)
//
// Keyed by real ld.* node ids. Grind moves use .full (5 strengthlevel levels);
// weighted nodes use .bodyweightRatio .full (added %bw as decimals). All 24 nodes
// are GRIND or WEIGHTED — legs rep out, no single-rep feats here.

enum LegsSkillAnchors {
    static let table: [String: SkillAnchor] = [

        // ── GRIND — full 9-tier spread off real leg standards ──

        // Loaded squat entry — goblet squat ranks by ADDED LOAD (% bodyweight held),
        // not endless reps. Beginner ~+10% bw, elite ~+50% (you move to barbell above that).
        "ld.goblet-20":               .init(exerciseName: "goblet squat",            metric: .bodyweightRatio, spec: .full([0.10, 0.15, 0.25, 0.35, 0.50])),

        // Glute / accessory high-rep bilaterals — endurance movers, run high.
        "ld.glute-bridge":            .init(exerciseName: "glute bridge",            metric: .reps, spec: .full([10, 25, 45, 70, 100])),
        "ld.calf-raise":              .init(exerciseName: "calf raise",              metric: .reps, spec: .full([15, 30, 50, 75, 100])),
        "ld.fire-hydrant":            .init(exerciseName: "fire hydrant",            metric: .reps, spec: .full([10, 22, 40, 62, 90])),

        // Step-up / split-squat / SL-glute-bridge — unilateral grinders, scale off
        // lunge [1,11,37,69,105] (one-leg endurance), tempered for the harder ones.
        "ld.step-up":                 .init(exerciseName: "step up",                 metric: .reps, spec: .full([8, 18, 35, 55, 80])),
        "ld.split-squat":             .init(exerciseName: "split squat",             metric: .reps, spec: .full([5, 14, 30, 50, 75])),
        "ld.single-leg-glute-bridge": .init(exerciseName: "single-leg glute bridge", metric: .reps, spec: .full([5, 13, 28, 45, 65])),

        // Bulgarian split squat — harder unilateral than plain split, fewer reps.
        "ld.bulgarian-split-squat":   .init(exerciseName: "bulgarian split squat",   metric: .reps, spec: .full([3, 10, 22, 38, 55])),

        // Deep squat — HOLD (seconds). Squat-hold mobility ladder.
        "ld.deep-squat":              .init(exerciseName: "deep squat",              metric: .seconds, spec: .full([30, 60, 90, 120, 180])),

        // Box jump — power/plyo, low-rep quality reps. Stop once landing or
        // height fades; this is not an endurance ladder.
        "ld.box-jump":                .init(exerciseName: "box jump",                metric: .reps, spec: .full([1, 2, 3, 4, 5])),

        // Jumping squat — power quality with a modest ceiling, not a 100-rep grind.
        "ld.jumping-squat":           .init(exerciseName: "jumping squat",           metric: .reps, spec: .full([1, 3, 5, 8, 10])),

        // Flying kickback / bodyweight leg extension — quad/glute isolation accessories.
        "ld.flying-kickback":         .init(exerciseName: "leg kickback",            metric: .reps, spec: .full([8, 18, 35, 55, 80])),
        "ld.leg-extensions":          .init(exerciseName: "bodyweight leg extension", metric: .reps, spec: .full([10, 20, 35, 55, 80])),

        // Nordic hip hinge — nordic lead-up (assisted/short-ROM), sits below the
        // full nordic curl ceiling (39) — an accessible posterior-chain grinder.
        "ld.nordic-hip-hinge":        .init(exerciseName: "nordic hip hinge",        metric: .reps, spec: .full([3, 8, 16, 26, 38])),

        // Pistol squat — pistol standard, verbatim (GRIND, reps to 38).
        "ld.pistol-squat":            .init(exerciseName: "pistol squat",            metric: .reps, spec: .full([1, 3, 13, 25, 38])),

        // Shrimp squat — harder single-leg than pistol → fewer reps than pistol.
        "ld.shrimp-squat":            .init(exerciseName: "shrimp squat",            metric: .reps, spec: .full([1, 3, 9, 18, 28])),

        // Advancing (advanced) nordic curl — high-tension hamstring work. Keep
        // the ladder low enough that each rep stays controlled.
        "ld.advancing-nordic-curl":   .init(exerciseName: "advanced nordic hip hinge", metric: .reps, spec: .full([1, 2, 3, 4, 6])),

        // Floor-to-ceiling squat — deep-ROM mobility squat. Default GRIND building
        // reps (per rubric), modest ceiling for a slow controlled ROM movement.
        "ld.floor-to-ceiling-squat":  .init(exerciseName: "floor to ceiling squat",  metric: .reps, spec: .full([1, 3, 6, 10, 15])),

        // Sissy squat — quad-dominant, extreme knee flexion. Moderate ceiling.
        "ld.sissy-squat":             .init(exerciseName: "sissy squat",             metric: .reps, spec: .full([2, 6, 14, 24, 35])),

        // Nordic curl — full high-tension hamstring curl. Quality reps beat
        // heroic volume.
        "ld.nordic-curl":             .init(exerciseName: "nordic curl",             metric: .reps, spec: .full([1, 2, 3, 5, 8])),

        // ── WEIGHTED — added %bw as decimals (docs/standards-weighted.md) ──

        // Pistol is balance-capped → keep the lower pistol band.
        "ld.weighted-pistol":         .init(exerciseName: "weighted pistol",         metric: .bodyweightRatio, spec: .full([0.10, 0.22, 0.40, 0.60, 0.90])),

        // Split squat & BSS can hold more (stable, two points of contact).
        "ld.weighted-split-squat":    .init(exerciseName: "weighted split squat",    metric: .bodyweightRatio, spec: .full([0.15, 0.30, 0.50, 0.75, 1.00])),
        "ld.weighted-bss":            .init(exerciseName: "weighted bss",            metric: .bodyweightRatio, spec: .full([0.15, 0.30, 0.50, 0.75, 1.00])),

        // Single-leg calf raise — strong line, can load heavy.
        "ld.weighted-sl-calf":        .init(exerciseName: "single-leg calf raise",   metric: .bodyweightRatio, spec: .full([0.15, 0.35, 0.60, 0.90, 1.30])),
    ]
}

enum LdSkillTiers {
    /// Generated from `LegsSkillAnchors` — each anchor's real-data ladder → 9 tiers.
    /// A few calisthenics leg goals use authored variant ladders so the tree
    /// honors the real progression flow instead of ranking every tier on the
    /// final movement only.
    static let table: [String: [SkillTier: TierCriterion]] = {
        let generated = LegsSkillAnchors.table.mapValues { SkillTierGenerator.generate($0) }
        return generated.merging(authoredVariantLadders) { _, authored in authored }
    }()

    private static let authoredVariantLadders: [String: [SkillTier: TierCriterion]] = [
        "ld.pistol-squat": [
            .initiate: .reps(3, exerciseName: "partial pistol squat"),
            .novice: .reps(8, exerciseName: "partial pistol squat"),
            .apprentice: .reps(5, exerciseName: "assisted pistol squat"),
            .forged: .reps(1, exerciseName: "pistol squat"),
            .veteran: .reps(3, exerciseName: "pistol squat"),
            .master: .reps(8, exerciseName: "pistol squat"),
            .vessel: .reps(13, exerciseName: "pistol squat"),
            .ascendant: .reps(25, exerciseName: "pistol squat"),
            .unbound: .reps(38, exerciseName: "pistol squat")
        ],
        "ld.shrimp-squat": [
            .initiate: .reps(3, exerciseName: "assisted shrimp squat"),
            .novice: .reps(3, exerciseName: "beginner shrimp squat"),
            .apprentice: .reps(3, exerciseName: "intermediate shrimp squat"),
            .forged: .reps(1, exerciseName: "shrimp squat"),
            .veteran: .reps(3, exerciseName: "shrimp squat"),
            .master: .reps(6, exerciseName: "shrimp squat"),
            .vessel: .reps(9, exerciseName: "shrimp squat"),
            .ascendant: .reps(3, exerciseName: "two-hand shrimp squat"),
            .unbound: .reps(3, exerciseName: "elevated two-hand shrimp squat")
        ],
        "ld.nordic-curl": [
            .initiate: .reps(1, exerciseName: "nordic curl negative"),
            .novice: .reps(3, exerciseName: "nordic curl negative"),
            .apprentice: .reps(5, exerciseName: "nordic curl negative"),
            .forged: .reps(1, exerciseName: "nordic curl"),
            .veteran: .reps(2, exerciseName: "nordic curl"),
            .master: .reps(3, exerciseName: "nordic curl"),
            .vessel: .reps(2, exerciseName: "nordic curl arms overhead"),
            .ascendant: .reps(1, exerciseName: "tuck one-leg nordic curl"),
            .unbound: .reps(1, exerciseName: "one-leg nordic curl")
        ]
    ]
}
