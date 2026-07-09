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
        (["bulgarian split squat"],         "ld.bulgarian-split-squat"),
        (["split squat"],                   "ld.split-squat"),
        (["step-up", "step up"],           "ld.step-up"),
        (["bodyweight leg extension", "reverse nordic", "kneeling leg extension"], "ld.leg-extensions"),
        (["pistol squat", "pistol"],        "ld.pistol-squat"),
        (["shrimp squat"],                  "ld.shrimp-squat"),
        (["nordic curl"],                   "ld.nordic-curl"),
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
    private static func clears(
        _ criterion: TierCriterion,
        exerciseKey: String? = nil,
        peakReps: Int,
        peakSeconds: Int
    ) -> Bool {
        if let exerciseKey,
           let requiredName = exerciseName(in: criterion),
           !MovementProofMatcher.namesMatch(logged: exerciseKey, required: requiredName) {
            return false
        }

        switch criterion {
        case .reps(let n, _):            return peakReps >= n
        case .exerciseSeconds(let n, _): return peakSeconds >= n
        default:                         return false
        }
    }

    // MARK: Criteria core (shared by the exercise-key and node-id entry points)

    /// Walk a node's tier criteria high→low; first cleared tier wins (floor = initiate).
    private static func rank(
        using criteria: [SkillTier: TierCriterion],
        exerciseKey: String? = nil,
        peakReps: Int,
        peakSeconds: Int
    ) -> RankTier {
        for tier in SkillTier.allCases.reversed() {
            guard let criterion = criteria[tier] else { continue }
            if clears(criterion, exerciseKey: exerciseKey, peakReps: peakReps, peakSeconds: peakSeconds) { return tier }
        }
        return .initiate
    }

    private static func progress(
        using criteria: [SkillTier: TierCriterion],
        exerciseKey: String? = nil,
        peakReps: Int,
        peakSeconds: Int
    ) -> (current: RankTier, next: RankTier?, fraction: Double) {
        let current = rank(using: criteria, exerciseKey: exerciseKey, peakReps: peakReps, peakSeconds: peakSeconds)
        guard let next = nextEligibleTier(after: current, criteria: criteria, exerciseKey: exerciseKey) else {
            return (current, nil, 1.0)
        }
        // The metric that drives this node — reps for rep nodes, seconds for holds.
        let value = Double(criteria[current].flatMap(isSecondsCriterion) == true ? peakSeconds : peakReps)
        let lo = Double(criteria[current].flatMap(threshold) ?? 0)
        guard let hiInt = criteria[next].flatMap(threshold) else { return (current, next, 1.0) }
        let hi = Double(hiInt)
        guard hi > lo else { return (current, next, 1.0) }
        return (current, next, max(0.0, min(1.0, (value - lo) / (hi - lo))))
    }

    private static func thresholdText(
        using criteria: [SkillTier: TierCriterion],
        exerciseKey: String? = nil,
        peakReps: Int,
        peakSeconds: Int
    ) -> String? {
        let current = rank(using: criteria, exerciseKey: exerciseKey, peakReps: peakReps, peakSeconds: peakSeconds)
        guard let next = nextEligibleTier(after: current, criteria: criteria, exerciseKey: exerciseKey),
              let nextCriterion = criteria[next],
              let nextThreshold = threshold(nextCriterion) else { return nil }
        let seconds = isSecondsCriterion(nextCriterion)
        let have = seconds ? peakSeconds : peakReps
        let remaining = max(0, nextThreshold - have)
        if seconds { return "\(remaining)s to \(next.displayName)" }
        return "\(remaining) \(remaining == 1 ? "rep" : "reps") to \(next.displayName)"
    }

    private static func exerciseName(in criterion: TierCriterion) -> String? {
        switch criterion {
        case .reps(_, let exerciseName),
             .exerciseSeconds(_, let exerciseName),
             .exerciseWeightKg(_, let exerciseName),
             .exerciseBodyweightRatio(_, let exerciseName):
            return exerciseName
        case .variant(let name):
            return name
        case .compound, .seconds, .weightKg, .bodyweightRatio:
            return nil
        }
    }

    private static func nextEligibleTier(
        after current: RankTier,
        criteria: [SkillTier: TierCriterion],
        exerciseKey: String?
    ) -> RankTier? {
        guard current.rawValue < SkillTier.unbound.rawValue else { return nil }
        return SkillTier.allCases
            .filter { $0.rawValue > current.rawValue }
            .first { tier in
                guard let criterion = criteria[tier] else { return false }
                guard let exerciseKey, let requiredName = exerciseName(in: criterion) else { return true }
                return MovementProofMatcher.namesMatch(logged: exerciseKey, required: requiredName)
            }
    }

    private static func isSecondsCriterion(_ criterion: TierCriterion) -> Bool {
        if case .exerciseSeconds = criterion { return true }
        return false
    }

    // MARK: Exercise-key entry points (lift rank path — the canonical bodyweight skills)

    /// Rank a bodyweight rep/hold performance against its skill node — the SAME
    /// thresholds `computeTier` walks. nil if not a bodyweight skill ranked here.
    static func bodyweightRank(exerciseKey: String, peakReps: Int, peakSeconds: Int) -> RankTier? {
        guard let criteria = criteria(forKey: exerciseKey) else { return nil }
        guard peakReps > 0 || peakSeconds > 0 else { return nil }
        return rank(using: criteria, exerciseKey: exerciseKey, peakReps: peakReps, peakSeconds: peakSeconds)
    }

    /// Progress toward the next rank for a bodyweight rep/hold movement.
    static func bodyweightProgress(exerciseKey: String, peakReps: Int, peakSeconds: Int) -> (current: RankTier, next: RankTier?, fraction: Double)? {
        guard let criteria = criteria(forKey: exerciseKey) else { return nil }
        return progress(using: criteria, exerciseKey: exerciseKey, peakReps: peakReps, peakSeconds: peakSeconds)
    }

    // MARK: Node-id entry points (reward cards — works for ANY skill node)

    /// Progress toward the next rank for a specific skill node, from the peak
    /// reps/seconds achieved this session. Covers every node, not just the
    /// canonical lift-path movements.
    ///
    /// `exerciseKey` is the movement the peaks were actually logged AS. Rungs
    /// whose criterion names a DIFFERENT movement (the authored variant
    /// ladders: ld.pistol-squat / ld.nordic-curl / ld.shrimp-squat) are
    /// name-gated exactly like the exercise-key path above — a raw rep count
    /// can never clear another variant's rung (1 nordic curl is NOT the
    /// one-leg nordic curl Unbound rung). Single-movement nodes, where the
    /// logged name IS the node movement, behave identically to an ungated
    /// walk. Pass nil only when no logged movement name exists.
    static func nodeProgress(skillId: String, exerciseKey: String?, peakReps: Int, peakSeconds: Int) -> (current: RankTier, next: RankTier?, fraction: Double)? {
        guard let criteria = SkillGraph.shared.node(id: skillId)?.tierCriteria, !criteria.isEmpty else { return nil }
        return progress(using: criteria, exerciseKey: gateKey(exerciseKey, in: criteria), peakReps: peakReps, peakSeconds: peakSeconds)
    }

    /// Micro-target text for a specific skill node. Same name gate as
    /// `nodeProgress`, so the "N reps to X" line never points at a rung whose
    /// criterion names a different variant.
    static func nodeNextThresholdText(skillId: String, exerciseKey: String?, peakReps: Int, peakSeconds: Int) -> String? {
        guard let criteria = SkillGraph.shared.node(id: skillId)?.tierCriteria, !criteria.isEmpty else { return nil }
        return thresholdText(using: criteria, exerciseKey: gateKey(exerciseKey, in: criteria), peakReps: peakReps, peakSeconds: peakSeconds)
    }

    /// A key can only gate a ladder it belongs to: if `exerciseKey` matches
    /// NONE of the ladder's named criteria, gating would zero the whole node
    /// (vocabulary drift between a node's target text and its anchor text,
    /// e.g. "inverted row" vs "row"), so the walk stays ungated instead —
    /// the pre-gate behavior. Within-ladder keys gate rung-by-rung.
    private static func gateKey(_ exerciseKey: String?, in criteria: [SkillTier: TierCriterion]) -> String? {
        guard let exerciseKey else { return nil }
        let requiredNames = criteria.values.compactMap(exerciseName(in:))
        guard !requiredNames.isEmpty else { return exerciseKey }
        let matchesLadder = requiredNames.contains {
            MovementProofMatcher.namesMatch(logged: exerciseKey, required: $0)
        }
        return matchesLadder ? exerciseKey : nil
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
