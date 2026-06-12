// UNBOUND/Models/SkillTreeContent/Tiers/CalSkillTiers.swift
//
// Tier criteria for the push family (cal.*, 24 skills) — GENERATED from real-data
// anchors (PushSkillAnchors + SkillTierGenerator), replacing the old hand-authored
// 9-tier-per-node tables (the source of the distribution mess). Grind moves spread
// real strengthlevel / coaching standards across the 9 tiers; hard feats start high
// (the first rep jumps to a floor rank, ranks below are "not yet"). The node's
// difficulty (SkillNode.tier, used by trials) is unchanged — only the per-node rank
// ladder is generated here. Mirrors the shipped pull pipeline (PpSkillTiers).
//
// See docs/strength-standards-harvest.md, docs/standards-advanced-skills.md, and
// docs/standards-statics.md for the grounding anchors.
//
// 10 vestigial orphan nodes (azarian, iron-cross-3s/10s, l-sit-20, l-sit-dip,
// maltese, ring-support-10, slow-pushup, tempo-dip, weighted-dip) are intentionally
// dropped — confirmed dead, zero consumers.

import Foundation

import Foundation

#if DEBUG
private let _calCountCheck: Int = {
    assert(
        CalSkillTiers.table.count == 24,
        "cal cluster should have 24 entries, has \(CalSkillTiers.table.count)"
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

// MARK: - Push family anchors (canonical cal.* nodes — real data)
//
// Keyed by real cal.* node ids. Grind moves use .full (5 bands [Beginner…Elite]);
// hard feats use .feat (a floor rank from the move's difficulty + a short rep ladder
// floor…peak, count == 9 - floor.rawValue). Exercise strings MUST match the node
// target for evaluator name-resolution.

enum PushSkillAnchors {
    static let table: [String: SkillAnchor] = [

        // ── Grind moves — real range, full 9-tier spread ──

        // Push-up chain. Push-up is the doc anchor [5,20,40,64,90].
        "cal.incline-pushup": .init(exerciseName: "incline pushup", metric: .reps, spec: .full([10, 25, 45, 65, 90])),  // easier than pushup → more reps
        "cal.pushup":         .init(exerciseName: "pushup",         metric: .reps, spec: .full([5, 20, 40, 64, 90])),   // strengthlevel direct
        "cal.decline-pushup": .init(exerciseName: "decline pushup", metric: .reps, spec: .full([3, 14, 30, 50, 72])),   // harder angle than flat → fewer reps

        // Tricep / lateral push variants.
        "cal.diamond-pushup": .init(exerciseName: "diamond pushup", metric: .reps, spec: .full([3, 10, 24, 39, 56])),   // strengthlevel direct (Beginner <1 → 3)
        "cal.sphinx-pushup":  .init(exerciseName: "sphinx pushup",  metric: .reps, spec: .full([2, 8, 18, 30, 44])),    // tricep/elbow push, between diamond & pushup
        "cal.archer-pushup":  .init(exerciseName: "archer pushup",  metric: .reps, spec: .full([1, 9, 24, 44, 65])),    // strengthlevel direct (Beginner <1 → 1)
        "cal.pseudo-planche-pushup": .init(exerciseName: "pseudo-planche pushup", metric: .reps, spec: .full([3, 6, 10, 16, 22])), // PPPU coaching standard

        // Power / plyo push-ups — explosive, fewer reps.
        "cal.explosive-pushup": .init(exerciseName: "explosive pushup", metric: .reps, spec: .full([2, 8, 16, 26, 38])), // power, fewer reps than flat
        "cal.clapping-pushup":  .init(exerciseName: "clapping pushup",  metric: .reps, spec: .full([1, 5, 11, 18, 26])), // plyo, harder than explosive

        // Dips.
        "cal.bench-dip": .init(exerciseName: "bench dip", metric: .reps, spec: .full([5, 12, 32, 56, 83])),  // strengthlevel direct (Beginner <1 → 5)
        "cal.5-dips":    .init(exerciseName: "dip",       metric: .reps, spec: .full([1, 10, 20, 31, 44])),  // strengthlevel direct (parallel bar dip)
        "cal.ring-dip":  .init(exerciseName: "ring dip",  metric: .reps, spec: .full([1, 7, 15, 25, 36])),   // rings add instability → fewer than bar dip

        // Pike / overhead press chain. Pike push-up coaching standard [5,10,18,30,42].
        "cal.pike-pushup":          .init(exerciseName: "pike pushup",          metric: .reps, spec: .full([5, 10, 18, 30, 42])),  // coaching standard
        "cal.elevated-pike-pushup": .init(exerciseName: "elevated pike pushup", metric: .reps, spec: .full([3, 8, 15, 24, 34])),   // between pike & HSPU
        "cal.floating-pike-pushup": .init(exerciseName: "floating pike pushup", metric: .reps, spec: .full([1, 5, 11, 18, 26])),   // harder than elevated pike
        "cal.handstand-pushup":     .init(exerciseName: "handstand pushup",     metric: .reps, spec: .feat(floor: .veteran, ladder: [1, 8, 18, 32, 46])),  // a first HSPU is already advanced — floor Veteran, then real rep climb to 46 (5 vals = 9−4)

        // Planche-lean press chain.
        "cal.tuck-planche-pushup": .init(exerciseName: "tuck planche pushup", metric: .reps, spec: .full([1, 3, 6, 10, 15])),  // dynamic tuck planche press, build reps

        // One-arm push-up — a first OAPU is already advanced → floor Veteran, then real rep climb to 43.
        "cal.one-arm-pushup": .init(exerciseName: "one-arm pushup", metric: .reps, spec: .feat(floor: .veteran, ladder: [1, 8, 18, 30, 43])),  // 5 vals = 9−4

        // Holds.
        "cal.plank-30":  .init(exerciseName: "plank", metric: .seconds, spec: .full([20, 45, 60, 120, 180])),  // front plank coaching/clinical standard
        "cal.l-sit-10":  .init(exerciseName: "l-sit", metric: .seconds, spec: .full([3, 5, 15, 30, 45])),       // L-sit coaching standard (Beginner <1 → 3)

        // ── Hard feats — first rep is already elite; floor from difficulty, short ladder ──

        // World-class apex presses — owning ONE rep is elite; floor .vessel (3 vals).
        "cal.bent-arm-press":      .init(exerciseName: "bent arm press",   metric: .reps, spec: .feat(floor: .vessel, ladder: [1, 2, 4])),  // bent-arm planche press
        "cal.ninety-degree-pushup": .init(exerciseName: "90 degree pushup", metric: .reps, spec: .feat(floor: .vessel, ladder: [1, 2, 4])), // 90-degree pushup apex

        // Mythic clap variants.
        "cal.clapping-handstand-pushup": .init(exerciseName: "clapping handstand pushup", metric: .reps, spec: .feat(floor: .vessel,  ladder: [1, 2, 4])),  // clapping HSPU (3 vals)
        "cal.triple-clap-pushup":        .init(exerciseName: "triple clap pushup",        metric: .reps, spec: .feat(floor: .ascendant, ladder: [1, 2])),       // triple-clap pushup (2 vals)
    ]
}

enum CalSkillTiers {
    /// Generated from `PushSkillAnchors` — each anchor's real-data ladder → 9 tiers.
    static let table: [String: [SkillTier: TierCriterion]] =
        PushSkillAnchors.table.mapValues { SkillTierGenerator.generate($0) }
}
