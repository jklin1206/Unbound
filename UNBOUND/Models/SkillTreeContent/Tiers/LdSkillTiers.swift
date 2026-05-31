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
//   squat jump        < 1 / 8 / 34 / 68 / 108
//   nordic curl       < 1 / < 1 / 11 / 24 / 39
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

        // Box jump — power/plyo, low-rep quality reps, scale off squat-jump shape
        // but capped low (max-effort box jumps don't rep out like jump squats).
        "ld.box-jump":                .init(exerciseName: "box jump",                metric: .reps, spec: .full([3, 6, 12, 20, 30])),

        // Jumping squat — squat jump standard, verbatim.
        "ld.jumping-squat":           .init(exerciseName: "jumping squat",           metric: .reps, spec: .full([1, 8, 34, 68, 108])),

        // Flying kickback / leg extension — quad/glute isolation accessories.
        "ld.flying-kickback":         .init(exerciseName: "leg kickback",            metric: .reps, spec: .full([8, 18, 35, 55, 80])),
        "ld.leg-extensions":          .init(exerciseName: "leg extensions",          metric: .reps, spec: .full([10, 20, 35, 55, 80])),

        // Nordic hip hinge — nordic lead-up (assisted/short-ROM), sits below the
        // full nordic curl ceiling (39) — an accessible posterior-chain grinder.
        "ld.nordic-hip-hinge":        .init(exerciseName: "nordic hip hinge",        metric: .reps, spec: .full([3, 8, 16, 26, 38])),

        // Pistol squat — pistol standard, verbatim (GRIND, reps to 38).
        "ld.pistol-squat":            .init(exerciseName: "pistol squat",            metric: .reps, spec: .full([1, 3, 13, 25, 38])),

        // Shrimp squat — harder single-leg than pistol → fewer reps than pistol.
        "ld.shrimp-squat":            .init(exerciseName: "shrimp squat",            metric: .reps, spec: .full([1, 3, 9, 18, 28])),

        // Advancing (advanced) nordic curl — harder nordic stage; below full nordic
        // curl (39) but above the hip-hinge lead-up. GRIND — nordic reps out.
        "ld.advancing-nordic-curl":   .init(exerciseName: "advanced nordic hip hinge", metric: .reps, spec: .full([1, 4, 11, 20, 30])),

        // Floor-to-ceiling squat — deep-ROM mobility squat. Default GRIND building
        // reps (per rubric), modest ceiling for a slow controlled ROM movement.
        "ld.floor-to-ceiling-squat":  .init(exerciseName: "floor to ceiling squat",  metric: .reps, spec: .full([1, 3, 6, 10, 15])),

        // Sissy squat — quad-dominant, extreme knee flexion. Moderate ceiling.
        "ld.sissy-squat":             .init(exerciseName: "sissy squat",             metric: .reps, spec: .full([2, 6, 14, 24, 35])),

        // Nordic curl — full nordic hamstring curl standard, verbatim (GRIND to 39).
        "ld.nordic-curl":             .init(exerciseName: "nordic curl",             metric: .reps, spec: .full([1, 3, 11, 24, 39])),

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
    static let table: [String: [SkillTier: TierCriterion]] =
        LegsSkillAnchors.table.mapValues { SkillTierGenerator.generate($0) }
}
