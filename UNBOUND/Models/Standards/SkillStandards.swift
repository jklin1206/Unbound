import Foundation

// MARK: - SkillStandards
//
// THE single source for ranking a bodyweight rep/hold movement.
//
// Bodyweight skills (pull-up, push-up, dip, plank, l-sit, dead hang, hollow…)
// are ranked by ONE authority: the skill graph's generated `tierCriteria`
// (SkillAnchor → SkillTierGenerator). This type maps a logged movement key to
// its canonical skill node and reads those same thresholds — so the lift path
// (`RankService.computeLiftRank`) and the reward "% to next" bar
// (`StrengthStandards.progressToNextRank`) produce the EXACT tier the skill
// tree (`RankService.computeTier`) would. No second ladder, no drift.
//
// This replaced the old duplicate `StrengthStandards.repLadders` /
// `holdLadders` and `RankService.bodyweightRepRank` / `holdRank`, which each
// authored their own conflicting numbers for the same movements.
//
// Weighted / loaded variants (weighted pull-up, weighted dip) are NOT handled
// here — they rank off load, on the StrengthStandards path.

enum SkillStandards {

    /// Logged-movement key → canonical skill node id, in match order (rep
    /// movements before holds, matching the old ladder precedence). The node's
    /// generated `tierCriteria` are the single source of truth for its ranks.
    private static let canonicalNodes: [(match: [String], nodeId: String)] = [
        // Rep movements
        (["chin-up", "chinup"],            "pp.chin-up"),
        (["pull-up", "pullup"],            "pp.pullup"),
        (["push-up", "pushup"],            "cal.pushup"),
        (["dip"],                          "cal.5-dips"),
        // Holds
        (["l-sit", "lsit"],                "cal.l-sit-10"),
        (["plank"],                        "cal.plank-30"),
        (["dead hang", "dead-hang"],       "pp.dead-hang"),
        (["hollow"],                       "cl.hollow-body-30")
    ]

    /// True when `exerciseKey` is a bodyweight rep/hold movement ranked here
    /// (and not a loaded/weighted variant, which ranks off load elsewhere).
    static func isBodyweightSkill(exerciseKey: String) -> Bool {
        canonicalNodeId(forKey: exerciseKey) != nil
    }

    private static func canonicalNodeId(forKey exerciseKey: String) -> String? {
        let key = exerciseKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Loaded variants are not ranked by reps/holds.
        if key.contains("weighted") { return nil }
        for entry in canonicalNodes where entry.match.contains(where: key.contains) {
            return entry.nodeId
        }
        return nil
    }

    /// Generated tier thresholds for a bodyweight skill node, keyed by tier.
    private static func criteria(forKey exerciseKey: String) -> [SkillTier: TierCriterion]? {
        guard let nodeId = canonicalNodeId(forKey: exerciseKey),
              let criteria = SkillGraph.shared.node(id: nodeId)?.tierCriteria,
              !criteria.isEmpty else { return nil }
        return criteria
    }

    /// The numeric threshold a tier criterion requires (reps OR hold seconds).
    /// nil for non rep/second criteria (these nodes only ever produce those).
    private static func threshold(_ criterion: TierCriterion) -> Int? {
        switch criterion {
        case .reps(let n, _):            return n
        case .exerciseSeconds(let n, _): return n
        default:                         return nil
        }
    }

    /// True when `peakReps`/`peakSeconds` clears the criterion's threshold.
    private static func clears(_ criterion: TierCriterion, peakReps: Int, peakSeconds: Int) -> Bool {
        switch criterion {
        case .reps(let n, _):            return peakReps >= n
        case .exerciseSeconds(let n, _): return peakSeconds >= n
        default:                         return false
        }
    }

    /// Rank a bodyweight rep/hold performance against its skill node — the SAME
    /// thresholds `computeTier` walks. Returns nil if the movement isn't a
    /// bodyweight skill ranked here. `peakReps` = best reps across working sets;
    /// `peakSeconds` = best hold seconds (with the legacy reps-column fallback
    /// applied by the caller).
    static func bodyweightRank(exerciseKey: String, peakReps: Int, peakSeconds: Int) -> RankTier? {
        guard let criteria = criteria(forKey: exerciseKey) else { return nil }
        guard peakReps > 0 || peakSeconds > 0 else { return nil }
        for tier in SkillTier.allCases.reversed() {
            guard let criterion = criteria[tier] else { continue }
            if clears(criterion, peakReps: peakReps, peakSeconds: peakSeconds) { return tier }
        }
        return .initiate
    }

    /// Progress toward the next rank for a bodyweight rep/hold movement: current
    /// tier, the next tier (nil at peak), and the 0…1 fraction between their
    /// thresholds. Single source for the reward "% to next" bar on these moves.
    static func bodyweightProgress(
        exerciseKey: String,
        peakReps: Int,
        peakSeconds: Int
    ) -> (current: RankTier, next: RankTier?, fraction: Double)? {
        guard let criteria = criteria(forKey: exerciseKey),
              let current = bodyweightRank(exerciseKey: exerciseKey, peakReps: peakReps, peakSeconds: peakSeconds)
        else { return nil }

        guard let next = current.next, current.rawValue < 8 else { return (current, nil, 1.0) }
        // The metric that drives this node — reps for rep nodes, seconds for holds.
        let value = Double(criteria[current].flatMap(isSecondsCriterion) == true ? peakSeconds : peakReps)
        let lo = Double(criteria[current].flatMap(threshold) ?? 0)
        guard let hiInt = criteria[next].flatMap(threshold) else { return (current, next, 1.0) }
        let hi = Double(hiInt)
        guard hi > lo else { return (current, next, 1.0) }
        let fraction = max(0.0, min(1.0, (value - lo) / (hi - lo)))
        return (current, next, fraction)
    }

    private static func isSecondsCriterion(_ criterion: TierCriterion) -> Bool {
        if case .exerciseSeconds = criterion { return true }
        return false
    }

    // MARK: - Weighted pull-up (added-load %bw)

    // Weighted pull-up / chin-up / dip are ranked by ADDED LOAD as a fraction of
    // bodyweight — NOT absolute kg (the old StrengthStandards.weightedPullupAddedKg
    // table, now deleted). The single source is the `pp.weighted-pullup` skill
    // node's generated %bw criteria; StrengthStandards projects these 9 anchors
    // into its ratio machinery so weighted pull-up ranks exactly like the skill.

    private static let weightedNodeId = "pp.weighted-pullup"

    /// The 9 per-tier added-load %bw thresholds (ordinal 0…8), read from the
    /// `pp.weighted-pullup` node — the single source. nil if the node is missing.
    static var weightedPullupRatioAnchors: [Double]? {
        guard let criteria = SkillGraph.shared.node(id: weightedNodeId)?.tierCriteria else { return nil }
        var anchors = [Double](repeating: 0, count: 9)
        for tier in SkillTier.allCases {
            guard case .exerciseBodyweightRatio(let r, _) = criteria[tier] else { return nil }
            anchors[tier.rawValue] = r
        }
        return anchors
    }

    /// Added-load %bw required to reach `tier` on the weighted pull-up path.
    static func weightedPullupRatio(tier: RankTier) -> Double? {
        weightedPullupRatioAnchors?[tier.rawValue]
    }
}
