// UNBOUND/Models/SkillTreeContent/Tiers/PpSkillTiers.swift
//
// Tier criteria for the pull family (pp.*, 26 skills) — GENERATED from real-data
// anchors (PullSkillAnchors + SkillTierGenerator), replacing the old hand-authored
// 9-tier-per-node tables (the source of the distribution mess). Grind moves spread
// real strengthlevel standards across the 9 tiers; hard feats start high (the first
// rep jumps to a floor rank, ranks below are "not yet"). The node's difficulty
// (SkillNode.tier, used by trials) is unchanged — only the per-node rank ladder is
// generated here. See docs/pull-rank-ladders-review.md + docs/strength-standards-harvest.md.

import Foundation

#if DEBUG
private let _ppCountCheck: Int = {
    assert(
        PpSkillTiers.table.count == 26,
        "pp cluster should have 26 entries, has \(PpSkillTiers.table.count)"
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
    /// Generated from `PullSkillAnchors` — each anchor's real-data ladder → 9 tiers.
    static let table: [String: [SkillTier: TierCriterion]] =
        PullSkillAnchors.table.mapValues { SkillTierGenerator.generate($0) }
}

// MARK: - Pull family anchors (canonical nodes — real data)
//
// Keyed by real pp.* node ids. Grind moves use .full (5 strengthlevel levels);
// hard feats use .feat (a floor rank from the move's difficulty + a short rep ladder).
// Variant nodes (5-pullups, slow-pullup, l-sit-pullup, …) added incrementally.
// Co-located with its tier file, mirroring the other six families.

enum PullSkillAnchors {
    static let table: [String: SkillAnchor] = [
        // Grind moves — real range, full 9-tier spread.
        "pp.pullup":          .init(exerciseName: "pullup",          metric: .reps,            spec: .full([1, 6, 13, 23, 32])),
        "pp.chin-up":         .init(exerciseName: "chin-up",         metric: .reps,            spec: .full([1, 7, 13, 22, 30])),
        "pp.wide-pullup":     .init(exerciseName: "wide pullup",     metric: .reps,            spec: .full([1, 4, 9, 17, 24])),
        "pp.muscle-up":       .init(exerciseName: "muscle-up",       metric: .reps,            spec: .full([1, 2, 7, 11, 17])),
        "pp.row":             .init(exerciseName: "row",             metric: .reps,            spec: .full([1, 7, 19, 33, 48])),
        "pp.weighted-pullup": .init(exerciseName: "weighted pullup", metric: .bodyweightRatio, spec: .full([0.10, 0.25, 0.50, 0.75, 1.00])),
        "pp.dead-hang":       .init(exerciseName: "dead hang",       metric: .seconds,         spec: .full([20, 40, 60, 90, 120])),

        // Hard feats — start high (floor from difficulty), short rep ladder floor…peak.
        "pp.archer-pullup":    .init(exerciseName: "archer pullup",    metric: .reps, spec: .scaled(to: 12)),   // floor 2 → 7 vals
        "pp.strict-muscle-up": .init(exerciseName: "strict muscle-up", metric: .reps, spec: .scaled(to: 14)),     // floor 3 → 6 vals
        "pp.ring-muscle-up":   .init(exerciseName: "ring muscle-up",   metric: .reps, spec: .scaled(to: 11)),          // floor 4 → 5 vals
        "pp.one-arm-pullup":   .init(exerciseName: "one-arm pullup",   metric: .reps, spec: .scaled(to: 12)),                // floor 6 → 1 OAP = Vessel (basically elite), 5 = peak

        // ── Variant + lead-up nodes (added incrementally) ──

        // Basic pull — grind volume / tempo / ROM variants. Scale off pullup [1,6,13,23,32].
        "pp.strict-pullup": .init(exerciseName: "pullup",              metric: .reps, spec: .full([1, 6, 13, 23, 32])),   // strict ≈ plain pullup (negligible difference)
        "pp.explosive-pullup": .init(exerciseName: "explosive pullup", metric: .reps, spec: .full([1, 3, 7, 12, 18])),    // power, fewer reps

        // Chin chain — scale off chin-up [1,7,13,22,30].
        "pp.strict-chin-up": .init(exerciseName: "chin-up",            metric: .reps, spec: .full([1, 7, 13, 22, 30])),   // strict ≈ plain chin-up (negligible difference)
        "pp.l-sit-chin-up":  .init(exerciseName: "l-sit chin-up",      metric: .reps, spec: .full([1, 3, 7, 13, 20])),    // core + chin = harder

        // Weighted — bodyweight-ratio, Elite ≈ +100% bw (1.0). Checkpoint nodes center lower.
        "pp.weighted-chin-up":     .init(exerciseName: "weighted chin-up", metric: .bodyweightRatio, spec: .full([0.10, 0.30, 0.50, 0.75, 1.00])),  // chin ~+5–15% over pullup

        // Rows — scale off inverted-row [1,7,19,33,48]. Easier = more reps, harder = fewer.
        "pp.incline-row":  .init(exerciseName: "incline row",  metric: .reps, spec: .full([5, 12, 25, 40, 55])),   // easier angle, more reps
        "pp.decline-row":  .init(exerciseName: "decline row",  metric: .reps, spec: .full([1, 5, 14, 26, 40])),    // harder angle, fewer reps
        "pp.tuck-row":     .init(exerciseName: "tuck row",     metric: .reps, spec: .full([1, 4, 10, 18, 28])),    // tucked lever row
        "pp.straddle-row": .init(exerciseName: "straddle row", metric: .reps, spec: .full([1, 3, 7, 13, 20])),     // straddle lever row, harder

        // Hard feats — start high, short ladder floor…peak (count == 9 - floor.rawValue).
        "pp.clapping-pullup":        .init(exerciseName: "clapping pullup",          metric: .reps, spec: .scaled(to: 15)),     // floor 3 → 6 vals
        "pp.heighted-chin-up":       .init(exerciseName: "heighted chin-up",         metric: .reps, spec: .scaled(to: 20)),     // floor 3 → 6 vals (one-arm-assist chin)
        "pp.oap-negative":           .init(exerciseName: "one-arm pullup negative",  metric: .reps, spec: .scaled(to: 8)),  // floor 2 → 7 vals (eccentric entry)
        "pp.one-arm-row":            .init(exerciseName: "one-arm row",              metric: .reps, spec: .full([1, 4, 8, 14, 20])),                  // plain grind ladder
        "pp.tuck-front-lever-pullup":.init(exerciseName: "tuck front lever pullup",  metric: .reps, spec: .scaled(to: 10)),        // floor 4 → 5 vals (lever pull)
        "pp.one-arm-chin-up":        .init(exerciseName: "one-arm chin-up",          metric: .reps, spec: .scaled(to: 12)),               // floor 6 → 1 OAC = Vessel, 5 = peak
    ]
}
