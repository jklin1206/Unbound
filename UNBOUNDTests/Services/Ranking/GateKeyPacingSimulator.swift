import Foundation
@testable import UNBOUND

// MARK: - GateKeyPacingSimulator
//
// Answers "when does each rank-gate's readiness actually turn for realistic
// users?" by driving 24 months of modeled training (GateKeyPacingModel)
// through the app's REAL progression code:
//
//   - Tiers: StrengthStandards.rank (loads) / a name-gated walk over each
//     skill node's real tierCriteria with the app's MovementProofMatcher
//     (mirroring SkillStandards' private rank walk) — never a parallel ladder.
//   - Level: OverallLevelCurve.level(forXP:) on accumulated session AP.
//   - Attributes: AttributeIngest.applyXPDeltas (real catch-up factor +
//     AttributeLevelCurve) fed by AttributeCatalog weight vectors.
//   - Gate keys: GateKeys.keys(for:) + GateKeyHistory.satisfies — the exact
//     definitions and satisfaction logic TrialReadinessService uses.
//
// Two movement pool series are tracked. Since the 2026-07-09 retune the
// shipped wiring in TrialReadinessService.readiness IS the widened pool:
// all skills + everything StrengthStandards ranks (compounds incl. barbell
// row with variants collapsed to canonical, accessory FAMILIES counted one
// per family, weighted pull-up). `current` mirrors that production pool;
// `widened` is kept as an identical series so the artifact schema stays
// stable across retunes.
//
// Deviations from production, by design (documented in the artifact too):
//   - Month granularity; attribute catch-up applies per month, not per
//     session (slightly smoother, same shape).
//   - Novelty multiplier fixed at 1.0 (conservative) and whole-point AP
//     quantization skipped — negligible at monthly scale.
//   - The equipment requirement line is assumed satisfied; only the level
//     floor and the gate keys are timed.
//   - `gatesAnswered` (final gate) is structural — it depends on attempt
//     behavior, not training — and is reported as never-month.

// MARK: Result types

struct PacingMonthRow {
    let month: Int
    let level: Int
    let totalXP: Double
    /// Count of attributes at >= rank, for tuning.reportedAttributeRanks.
    let attributeCounts: [RankTier: Int]
    /// Count of current-pool movements at >= rank.
    let currentPoolCounts: [RankTier: Int]
    /// Count of widened-pool movements at >= rank.
    let widenedPoolCounts: [RankTier: Int]
}

struct PacingKeyTurn {
    let keyId: String
    let label: String
    let month: Int
}

struct PacingGateTurn {
    let gateId: String
    let gateName: String
    let targetRank: RankTier
    let minOverallLevel: Int
    let levelMonth: Int
    let keyTurns: [PacingKeyTurn]
    /// Max of level month + non-structural key months (999 if any never turn).
    let readyMonth: Int
}

struct PacingCandidateTurn {
    let pool: String   // "current" | "widened"
    let count: Int
    let rank: RankTier
    let month: Int
}

struct PersonaPacingResult {
    let spec: PacingPersonaSpec
    let months: [PacingMonthRow]
    let gates: [PacingGateTurn]
    let candidates: [PacingCandidateTurn]
}

/// Minimal GateKeyHistory over a simulated month snapshot, so gate-key
/// satisfaction runs through the real `satisfies` extension.
private struct SimulatedGateKeyHistory: GateKeyHistory {
    let gateKeySetRecords: [GateKeySetRecord] = []
    let gateKeyAttributeProfile: AttributeProfile?
    let gateKeyTrialProgress: OverallRankTrialProgress = .empty
    let gateKeyMovementTiers: [RankTier]
}

// MARK: Simulator

struct GateKeyPacingSimulator {
    let tuning: GateKeyPacingTuning
    let horizonMonths: Int

    init(tuning: GateKeyPacingTuning = .default, horizonMonths: Int) {
        self.tuning = tuning
        self.horizonMonths = horizonMonths
    }

    // MARK: Per-persona run

    func run(_ spec: PacingPersonaSpec) -> PersonaPacingResult {
        let adherence = tuning.adherenceRate[spec.adherence] ?? 1.0
        let headStart = tuning.experienceHeadStartMonths[spec.experience] ?? 0
        let sessionsPerMonth = tuning.weeksPerMonth * spec.sessionsPerWeek * adherence
        let monthAP = sessionsPerMonth * tuning.sessionAP
        let apShares = attributeAPShares(for: spec)
        let curves = spec.movements.map { (movement: $0, curve: performanceCurve(for: $0, spec: spec)) }
        let referenceDate = Date(timeIntervalSince1970: 1_780_000_000)

        var profile = AttributeProfile.empty(userId: "pacing-\(spec.id)", at: referenceDate)
        var totalXP = 0.0
        var monthRows: [PacingMonthRow] = []
        var profileByMonth: [AttributeProfile] = []
        var currentTiersByMonth: [[RankTier]] = []

        for month in 1...horizonMonths {
            totalXP += monthAP

            var xpDeltas: [AttributeKey: Double] = [:]
            for (movement, share) in apShares {
                for (key, weight) in attributeVector(for: movement) {
                    xpDeltas[key, default: 0] += monthAP * share * weight
                }
            }
            _ = AttributeIngest.applyXPDeltas(
                &profile,
                xpDeltas: xpDeltas,
                at: referenceDate.addingTimeInterval(Double(month) * 30 * 86_400)
            )

            var currentPool: [String: RankTier] = [:]
            var widenedPool: [String: RankTier] = [:]
            for (movement, curve) in curves {
                let age = headStart + Double(month) * (tuning.emphasisAgeRate[movement.emphasis] ?? 1.0) * adherence
                let tier = evaluateTier(movement, value: curve.value(at: age), spec: spec)
                let poolKey = poolIdentity(for: movement)
                widenedPool[poolKey] = max(widenedPool[poolKey] ?? .initiate, tier)
                if isInCurrentPool(movement) {
                    currentPool[poolKey] = max(currentPool[poolKey] ?? .initiate, tier)
                }
            }

            let attributeCounts = Dictionary(uniqueKeysWithValues: tuning.reportedAttributeRanks.map { rank in
                (rank, AttributeKey.allCases.filter { profile.value(for: $0).rankTitle >= rank }.count)
            })
            monthRows.append(PacingMonthRow(
                month: month,
                level: OverallLevelCurve.level(forXP: totalXP),
                totalXP: totalXP,
                attributeCounts: attributeCounts,
                currentPoolCounts: poolCounts(Array(currentPool.values)),
                widenedPoolCounts: poolCounts(Array(widenedPool.values))
            ))
            profileByMonth.append(profile)
            currentTiersByMonth.append(Array(currentPool.values))
        }

        let gates = gateTurns(
            monthRows: monthRows,
            profileByMonth: profileByMonth,
            currentTiersByMonth: currentTiersByMonth,
            bodyweightKg: spec.bodyweightKg
        )
        let candidates = candidateTurns(monthRows: monthRows)
        return PersonaPacingResult(spec: spec, months: monthRows, gates: gates, candidates: candidates)
    }

    /// Pure level-curve helper: the first month a persona with the given
    /// cadence reaches `level` (independent of the simulated horizon).
    /// Used by the calibration sanity check.
    func monthWhenLevelReached(_ level: Int, sessionsPerWeek: Double, adherence: Double) -> Int {
        let monthAP = tuning.weeksPerMonth * sessionsPerWeek * adherence * tuning.sessionAP
        guard monthAP > 0 else { return tuning.neverMonth }
        let target = OverallLevelCurve.xpRequired(forLevel: level)
        let months = Int(ceil(target / monthAP))
        return months <= tuning.neverMonth ? months : tuning.neverMonth
    }

    // MARK: Gate + candidate turn computation

    private func gateTurns(
        monthRows: [PacingMonthRow],
        profileByMonth: [AttributeProfile],
        currentTiersByMonth: [[RankTier]],
        bodyweightKg: Double
    ) -> [PacingGateTurn] {
        OverallRankTrialDefinitions.all.map { definition in
            let levelMonth = firstMonth { monthRows[$0].level >= definition.minOverallLevel }
            var keyTurns: [PacingKeyTurn] = []
            for key in GateKeys.keys(for: definition.format) {
                if case .gatesAnswered = key.metric {
                    // Structural: depends on attempting prior gates, not training.
                    keyTurns.append(PacingKeyTurn(keyId: key.id, label: key.label, month: tuning.neverMonth))
                    continue
                }
                let month = firstMonth { index in
                    SimulatedGateKeyHistory(
                        gateKeyAttributeProfile: profileByMonth[index],
                        gateKeyMovementTiers: currentTiersByMonth[index]
                    ).satisfies(key, bodyweightKg: bodyweightKg)
                }
                keyTurns.append(PacingKeyTurn(keyId: key.id, label: key.label, month: month))
            }
            // Ready = level floor + all trainable keys (structural
            // gates-answered key excluded — it tracks attempts, not training).
            let trainableMonths = keyTurns
                .filter { !$0.keyId.hasPrefix("key-gates-answered") }
                .map(\.month)
            let readyMonth = ([levelMonth] + trainableMonths).max() ?? tuning.neverMonth
            return PacingGateTurn(
                gateId: definition.id,
                gateName: definition.displayName,
                targetRank: definition.targetRank,
                minOverallLevel: definition.minOverallLevel,
                levelMonth: levelMonth,
                keyTurns: keyTurns,
                readyMonth: readyMonth
            )
        }
    }

    private func candidateTurns(monthRows: [PacingMonthRow]) -> [PacingCandidateTurn] {
        var rows: [PacingCandidateTurn] = []
        for pool in ["current", "widened"] {
            for count in tuning.candidateCounts {
                for rank in tuning.candidateRanks {
                    let month = firstMonth { index in
                        let counts = pool == "current"
                            ? monthRows[index].currentPoolCounts
                            : monthRows[index].widenedPoolCounts
                        return (counts[rank] ?? 0) >= count
                    }
                    rows.append(PacingCandidateTurn(pool: pool, count: count, rank: rank, month: month))
                }
            }
        }
        return rows
    }

    private func firstMonth(where predicate: (Int) -> Bool) -> Int {
        for index in 0..<horizonMonths where predicate(index) {
            return index + 1
        }
        return tuning.neverMonth
    }

    private func poolCounts(_ tiers: [RankTier]) -> [RankTier: Int] {
        Dictionary(uniqueKeysWithValues: tuning.reportedMovementRanks.map { rank in
            (rank, tiers.filter { $0 >= rank }.count)
        })
    }

    // MARK: Pool membership (mirrors TrialReadinessService.readiness wiring)

    /// Current pool = the shipped `gateKeyMovementTierPool` wiring (2026-07-09
    /// retune): all skill-graph skills + every loaded movement
    /// StrengthStandards ranks — compounds incl. barbell row (variants
    /// collapse to canonical, exactly like RankService.bestBarbellLiftTiers),
    /// weighted pull-up, and accessory FAMILIES (one family = one movement).
    /// The formerly narrower skills+big-4 pool is gone; `widened` is now an
    /// identical series, kept so the artifact schema stays stable.
    private func isInCurrentPool(_ movement: PacingMovement) -> Bool {
        switch movement.kind {
        case .skill:
            return true
        case .lift(let exerciseKey):
            return StrengthStandards.canonicalKey(for: exerciseKey) != nil
                || StrengthStandards.accessoryFamily(for: exerciseKey) != nil
        }
    }

    /// Dedupe identity within a pool, matching the production pool's
    /// canonicalization: canonical compound key for lifts (two bench variants
    /// count once), accessory FAMILY for accessories (five curl variants count
    /// once), node id for skills.
    private func poolIdentity(for movement: PacingMovement) -> String {
        switch movement.kind {
        case .skill(let nodeId, _):
            return nodeId
        case .lift(let exerciseKey):
            if let canonical = StrengthStandards.canonicalKey(for: exerciseKey) {
                return "lift:\(canonical)"
            }
            if let family = StrengthStandards.accessoryFamily(for: exerciseKey) {
                return "family:\(family)"
            }
            return MovementResolution.normalizedKey(exerciseKey)
        }
    }

    // MARK: Attribute fan-out

    private func attributeAPShares(for spec: PacingPersonaSpec) -> [(PacingMovement, Double)] {
        let weights = spec.movements.map { tuning.emphasisAPWeight[$0.emphasis] ?? 1.0 }
        let total = weights.reduce(0, +)
        guard total > 0 else { return [] }
        return zip(spec.movements, weights).map { ($0, $1 / total) }
    }

    func attributeVector(for movement: PacingMovement) -> [AttributeKey: Double] {
        if let name = movement.attributeName {
            let weights = AttributeCatalog.shared.contribution(forExerciseName: name).weights
            if !weights.isEmpty { return weights }
        }
        switch movement.kind {
        case .skill: return tuning.defaultSkillAttributeVector
        case .lift: return tuning.defaultLiftAttributeVector
        }
    }

    // MARK: Performance model (timing) + real-standards evaluation

    /// Piecewise-linear best-performance curve over training age (months).
    /// Values are load ratios for lifts, reps/seconds for skills — anchored
    /// to the app's own tables, timed by the tuning milestones.
    struct PerformanceCurve {
        let points: [(age: Double, value: Double)]

        func value(at age: Double) -> Double {
            guard let first = points.first, let last = points.last else { return 0 }
            if age <= first.age { return first.value }
            if age >= last.age { return last.value }
            for index in 1..<points.count {
                let lo = points[index - 1]
                let hi = points[index]
                if age <= hi.age {
                    let t = (age - lo.age) / max(hi.age - lo.age, 0.0001)
                    return lo.value + t * (hi.value - lo.value)
                }
            }
            return last.value
        }
    }

    private static let milestoneTierOrder: [RankTier] = [.novice, .forged, .veteran, .master, .vessel, .ascendant]

    func performanceCurve(for movement: PacingMovement, spec: PacingPersonaSpec) -> PerformanceCurve {
        switch movement.kind {
        case .lift(let exerciseKey):
            return liftCurve(exerciseKey: exerciseKey, sex: spec.sex)
        case .skill(let nodeId, let exerciseName):
            return skillCurve(nodeId: nodeId, exerciseName: exerciseName)
        }
    }

    private func liftCurve(exerciseKey: String, sex: BiologicalSex) -> PerformanceCurve {
        var points: [(Double, Double)] = []
        for tier in Self.milestoneTierOrder {
            guard let months = tuning.liftMilestoneMonths[tier],
                  let ratio = StrengthStandards.ratio(exerciseKey: exerciseKey, tier: tier, sex: sex)
            else { continue }
            points.append((months, ratio))
        }
        guard let first = points.first else { return PerformanceCurve(points: [(0, 0)]) }
        points.insert((0, first.1 * tuning.startFractionOfFirstAnchor), at: 0)
        return PerformanceCurve(points: points.map { (age: $0.0, value: $0.1) })
    }

    private func skillCurve(nodeId: String, exerciseName: String) -> PerformanceCurve {
        guard let criteria = SkillGraph.shared.node(id: nodeId)?.tierCriteria, !criteria.isEmpty else {
            return PerformanceCurve(points: [(0, 0)])
        }
        guard let metric = Self.skillMetric(for: criteria, exerciseName: exerciseName) else {
            return PerformanceCurve(points: [(0, 0)])
        }
        // Feat = no name-matched Novice rung on the ladder (either a hard
        // feat whose first clean rep is already a mid-ladder rank, or a
        // variant ladder whose low rungs belong to easier regressions the
        // modeled user isn't credited for) → all milestones shift later.
        let isFeat = criteria[.novice].flatMap {
            Self.nameGatedThreshold($0, metric: metric, exerciseName: exerciseName)
        } == nil
        let delay = isFeat ? tuning.featDelayMonths : 0

        var points: [(Double, Double)] = []
        for tier in Self.milestoneTierOrder {
            guard let months = tuning.skillMilestoneMonths[tier],
                  let criterion = criteria[tier],
                  let threshold = Self.nameGatedThreshold(criterion, metric: metric, exerciseName: exerciseName)
            else { continue }
            points.append((months + delay, threshold))
        }
        guard let first = points.first else { return PerformanceCurve(points: [(0, 0)]) }
        let startValue = isFeat ? 0 : first.1 * tuning.startFractionOfFirstAnchor
        points.insert((0, startValue), at: 0)
        return PerformanceCurve(points: points.map { (age: $0.0, value: $0.1) })
    }

    /// Number of usable milestone anchors a curve carries (excluding the
    /// synthetic day-zero point) — the full run asserts every chosen
    /// movement has at least 3 so a bad node choice can't silently flatline.
    func milestoneAnchorCount(for movement: PacingMovement, spec: PacingPersonaSpec) -> Int {
        max(0, performanceCurve(for: movement, spec: spec).points.count - 1)
    }

    private func evaluateTier(_ movement: PacingMovement, value: Double, spec: PacingPersonaSpec) -> RankTier {
        switch movement.kind {
        case .lift(let exerciseKey):
            return StrengthStandards.rank(
                liftKg: value * spec.bodyweightKg,
                bodyweightKg: spec.bodyweightKg,
                exerciseKey: exerciseKey,
                sex: spec.sex
            ) ?? .initiate
        case .skill(let nodeId, let exerciseName):
            guard let criteria = SkillGraph.shared.node(id: nodeId)?.tierCriteria,
                  let metric = Self.skillMetric(for: criteria, exerciseName: exerciseName)
            else { return .initiate }
            return Self.skillTier(criteria: criteria, exerciseName: exerciseName, metric: metric, value: value)
        }
    }

    /// Name-gated tier walk over a node's REAL tierCriteria — the same
    /// highest-first walk `SkillStandards.rank(using:exerciseKey:)` performs
    /// (that entry point is private and only reachable for its canonical
    /// exercise keys), using the app's own MovementProofMatcher name gate.
    /// The gate matters for variant ladders (ld.pistol-squat / nordic):
    /// tiers proven by a DIFFERENT variant are skipped instead of cleared by
    /// raw rep count, so 1 modeled nordic rep can't clear the one-leg
    /// Unbound rung.
    static func skillTier(
        criteria: [SkillTier: TierCriterion],
        exerciseName: String,
        metric: SkillMetric,
        value: Double
    ) -> RankTier {
        for tier in SkillTier.allCases.reversed() {
            guard let criterion = criteria[tier],
                  let threshold = nameGatedThreshold(criterion, metric: metric, exerciseName: exerciseName)
            else { continue }
            if value >= threshold { return tier }
        }
        return .initiate
    }

    // MARK: Skill criterion introspection

    enum SkillMetric { case reps, seconds }

    static func skillMetric(for criteria: [SkillTier: TierCriterion], exerciseName: String) -> SkillMetric? {
        if criteria.values.contains(where: { nameGatedThreshold($0, metric: .seconds, exerciseName: exerciseName) != nil }) {
            return .seconds
        }
        if criteria.values.contains(where: { nameGatedThreshold($0, metric: .reps, exerciseName: exerciseName) != nil }) {
            return .reps
        }
        return nil
    }

    /// The criterion's numeric requirement for `metric`, but only when the
    /// criterion actually references this movement (or carries no exercise
    /// name at all). Name matching = MovementProofMatcher.namesMatch, the
    /// same gate SkillStandards.clears applies.
    static func nameGatedThreshold(_ criterion: TierCriterion, metric: SkillMetric, exerciseName: String) -> Double? {
        switch criterion {
        case .reps(let n, let required) where metric == .reps:
            return MovementProofMatcher.namesMatch(logged: exerciseName, required: required) ? Double(n) : nil
        case .exerciseSeconds(let n, let required) where metric == .seconds:
            return MovementProofMatcher.namesMatch(logged: exerciseName, required: required) ? Double(n) : nil
        case .seconds(let n) where metric == .seconds:
            return Double(n)
        case .compound(let subs):
            let values = subs.compactMap { nameGatedThreshold($0, metric: metric, exerciseName: exerciseName) }
            return values.isEmpty ? nil : values.max()
        default:
            return nil
        }
    }
}
