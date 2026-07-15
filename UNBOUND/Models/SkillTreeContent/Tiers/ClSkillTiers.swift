// UNBOUND/Models/SkillTreeContent/Tiers/ClSkillTiers.swift
//
// Tier criteria for the core / lever family (cl.*, 31 skills) — GENERATED from
// real-data anchors (CoreSkillAnchors + SkillTierGenerator), replacing the old
// hand-authored 9-tier-per-node tables (the source of the distribution mess).
// Grind moves (rep core + hold core) spread real standards across the 9 tiers;
// lever-hold stages each band their own hold-seconds at that leverage; hard feats
// start high (the first rep jumps to a floor rank, ranks below are "not yet").
// The node's difficulty (SkillNode.tier, used by trials) is unchanged — only the
// per-node rank ladder is generated here. Mirrors PpSkillTiers.swift.
//
// Grounding: docs/strength-standards-harvest.md (rep core) +
// docs/standards-statics.md (holds, lever/compression stages, front-lever feat).
//
// 6 orphan nodes (zero consumers) are intentionally excluded: cl.ab-wheel,
// cl.dragon-flag-negative, cl.hollow-body-60, cl.standing-plank,
// cl.straight-crunch, cl.victorian.

import Foundation

import Foundation

#if DEBUG
private let _clCountCheck: Int = {
    assert(
        ClSkillTiers.table.count == 31,
        "cl cluster should have 31 entries, has \(ClSkillTiers.table.count)"
    )
    assert(
        CoreSkillAnchors.table.count == 31,
        "cl anchors should have 31 entries, has \(CoreSkillAnchors.table.count)"
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

// MARK: - Core / lever family anchors (canonical nodes — real data)
//
// Keyed by real cl.* node ids. Grind moves use .full (5 standards spread onto
// tiers 0/2/4/6/8); lever-hold stages use .full seconds (band = hold-seconds at
// that leverage); the two apex feats use .feat (a floor rank + short ladder).

enum CoreSkillAnchors {
    static let table: [String: SkillAnchor] = [

        // ── Rep core — GRIND, full 9-tier spread ──

        // Ego-friendly high-rep ground core. Anchored directly to harvest data.
        "cl.crunch":          .init(exerciseName: "crunch",            metric: .reps, spec: .full([1, 21, 54, 95, 142])),   // crunches <1/21/54/95/142
        "cl.hanging-leg-raise":.init(exerciseName: "hanging leg raise", metric: .reps, spec: .full([1, 4, 8, 12, 20])),     // strict hanging leg raise, no swing reload
        "cl.hanging-knee-raise":.init(exerciseName: "hanging knee raise", metric: .reps, spec: .full([1, 5, 10, 18, 30])),  // strict active-hang knee raise
        "cl.leg-raise":       .init(exerciseName: "leg raise",         metric: .reps, spec: .full([1, 7, 33, 67, 107])),    // lying-leg-raise <1/7/33/67/107

        // Rep core without a direct strengthlevel row — monotonic bands grounded in
        // difficulty relative to the anchored moves above.
        "cl.reverse-crunch":  .init(exerciseName: "reverse crunch",    metric: .reps, spec: .full([5, 10, 20, 35, 55])),    // harder than crunch, lower volume
        "cl.knee-raise":      .init(exerciseName: "knee raise",        metric: .reps, spec: .full([5, 10, 18, 30, 45])),    // floor/parallel-bar, easier than hanging
        "cl.levitation-crunch":.init(exerciseName: "levitation crunch", metric: .reps, spec: .full([3, 6, 12, 20, 30])),    // advanced hip-float crunch
        "cl.toes-to-bar":     .init(exerciseName: "toes to bar",       metric: .reps, spec: .full([1, 3, 6, 10, 16])),      // StrengthLevel row <1/4/16/31/48 (65,599 lifts) is kipping-inclusive; this node is STRICT, so bands take the same strict discount as HLR and sit just UNDER it (harder movement, fewer reps)
        "cl.decline-situp":   .init(exerciseName: "decline sit-up",    metric: .reps, spec: .full([5, 15, 35, 60, 90])),    // sit-ups <1/23/57/99/146 scaled for decline
        "cl.knee-ab-rollout": .init(exerciseName: "ab wheel kneeling", metric: .reps, spec: .full([2, 5, 12, 22, 35])),     // kneeling ab wheel
        "cl.dragon-flag-hip-raise":.init(exerciseName: "dragon flag hip raise", metric: .reps, spec: .full([5, 10, 18, 30, 45])), // dragon-flag lead-up

        // Hard low-rep moves — run low (~[1,3,6,10,15]).
        "cl.skin-the-cat":       .init(exerciseName: "skin the cat",       metric: .reps, spec: .full([1, 3, 6, 10, 15])),  // low-rep rotational
        "cl.dragon-flag":        .init(exerciseName: "dragon flag",        metric: .reps, spec: .full([1, 3, 6, 10, 15])),  // full dragon flag, treated as reps
        "cl.inverted-situp":     .init(exerciseName: "inverted sit-up",    metric: .reps, spec: .full([1, 3, 6, 10, 15])),  // inverted hang sit-up
        "cl.standing-ab-rollout":.init(exerciseName: "standing ab rollout", metric: .reps, spec: .full([1, 3, 6, 10, 15])), // standing wheel, very hard

        // ── Hold core — GRIND seconds, full 9-tier spread ──

        "cl.hollow-body-30":  .init(exerciseName: "hollow body hold",  metric: .seconds, spec: .full([10, 20, 30, 45, 60])),  // hollow body 10/20/30/45/60
        "cl.extended-plank":  .init(exerciseName: "extended plank",    metric: .seconds, spec: .full([20, 45, 60, 120, 180])),// plank 20/45/60/120/180
        "cl.german-hang":     .init(exerciseName: "german hang",       metric: .seconds, spec: .full([10, 20, 30, 45, 60])),  // passive shoulder-flexion hold
        "cl.bird-dog-plank":  .init(exerciseName: "bird dog plank",    metric: .seconds, spec: .full([15, 30, 45, 60, 90])),  // unilateral stability hold
        "cl.superman-plank":  .init(exerciseName: "superman plank",    metric: .seconds, spec: .full([15, 30, 45, 60, 90])),  // extension hold

        // ── Lever-hold stages — each its own node; band = hold-seconds at that leverage ──

        "cl.tuck-front-lever":    .init(exerciseName: "tuck front lever",    metric: .seconds, spec: .full([3, 5, 10, 20, 30])),  // FL tuck (statics §2)
        "cl.straddle-front-lever":.init(exerciseName: "straddle front lever", metric: .seconds, spec: .full([2, 4, 8, 15, 25])), // FL straddle (statics §2)
        "cl.tuck-back-lever":     .init(exerciseName: "tuck back lever",     metric: .seconds, spec: .full([3, 5, 10, 15, 20])), // BL tuck — canonical first horizontal pause
        "cl.straddle-back-lever": .init(exerciseName: "straddle back lever", metric: .seconds, spec: .full([2, 5, 10, 15, 20])), // BL straddle — back lever is easier
        "cl.full-back-lever":     .init(exerciseName: "back lever",          metric: .seconds, spec: .scaled(to: 45)), // owning a full back lever = Forged floor (one notch under full front lever's Veteran — BL is the easier family); 6 vals = 9−3

        // ── L-sit / V-sit compression holds — GRIND seconds ──

        "cl.semi-straddle-l-sit": .init(exerciseName: "semi straddle l-sit", metric: .seconds, spec: .full([3, 6, 12, 20, 30])),
        "cl.straddle-l-sit":      .init(exerciseName: "straddle l-sit",      metric: .seconds, spec: .full([5, 10, 15, 25, 40])),
        "cl.v-sit":               .init(exerciseName: "v-sit",              metric: .seconds, spec: .full([2, 4, 7, 12, 20])),  // v-sit can't/2-3/5/10/20

        // ── Apex feats — start high (floor from difficulty), short ladder floor…peak ──

        // Full front lever — elite straight-arm feat; sits above every rep anchor.
        // floor .veteran (rawValue 4) → ladder count 9-4 = 5.
        "cl.full-front-lever":  .init(exerciseName: "front lever",     metric: .seconds, spec: .scaled(to: 40)),
        // 360 ring pulls — rare straight-arm ring arc; floor .vessel (rawValue 6)
        // -> ladder count 9-6 = 3.
        "cl.three-sixty-pulls": .init(exerciseName: "360 ring pulls", metric: .reps,   spec: .scaled(to: 13)),
    ]
}

enum ClSkillTiers {
    /// Generated from `CoreSkillAnchors` — each anchor's real-data ladder → 9 tiers.
    static let table: [String: [SkillTier: TierCriterion]] =
        CoreSkillAnchors.table.mapValues { SkillTierGenerator.generate($0) }
}
