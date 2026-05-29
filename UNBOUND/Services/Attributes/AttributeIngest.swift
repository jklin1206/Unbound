// UNBOUND/Services/Attributes/AttributeIngest.swift
import Foundation

protocol AttributeCatalogProtocol: AnyObject {
    func contribution(forExerciseName name: String) -> AttributeContribution
    func contribution(forSkillNodeId id: String) -> AttributeContribution
    func contribution(
        forMovementId movementId: String?,
        rankStandardMovementId: String?,
        fallbackExerciseName name: String
    ) -> AttributeContribution
}

extension AttributeCatalogProtocol {
    func contribution(
        forMovementId movementId: String?,
        rankStandardMovementId: String?,
        fallbackExerciseName name: String
    ) -> AttributeContribution {
        contribution(forExerciseName: name)
    }
}

enum AttributeIngest {
    static let gainConstant: Double = 4.0
    /// Converts a coarse legacy session `delta` (≈0…4 per axis, from
    /// `deltas(for:catalog:)`) into permanent XP. Only the legacy WorkoutLog
    /// ingest/backfill path uses this; the canonical AP path awards XP directly.
    static let sessionDeltaXPScale: Double = 50

    // MARK: - Per-axis catch-up multiplier (build-revealing + balance)
    //
    // Neglected axes (below the hex mean) earn faster; over-fed / near-cap axes
    // slow down. Keeps the hex build-revealing while preventing a single axis
    // (e.g. power) from trivially pinning at max. Pure function of the user's
    // CURRENT per-axis levels — deterministic, no new persistence.

    /// Slope of the catch-up bonus. Higher = stronger pull toward the mean.
    /// One-line tunable.
    static let catchUpK: Double = 2.0
    /// Multiplier floor / ceiling.
    static let catchUpMin: Double = 0.5
    static let catchUpMax: Double = 2.0
    /// At/above this level an axis is "near cap" and its factor is braked.
    static let catchUpNearCapLevel: Int = 90
    /// Brake applied to a near-cap axis's catch-up factor.
    static let catchUpNearCapBrake: Double = 0.5

    /// Catch-up factor for `axisLevel` given the mean level across the 6 axes.
    /// `clamp(1 + k·(mean − level)/maxLevel, min, max)`, then a near-cap brake.
    static func catchUpFactor(axisLevel: Int, meanLevel: Double) -> Double {
        let raw = 1 + catchUpK * (meanLevel - Double(axisLevel)) / Double(AttributeLevelCurve.maxLevel)
        var factor = min(catchUpMax, max(catchUpMin, raw))
        if axisLevel >= catchUpNearCapLevel { factor *= catchUpNearCapBrake }
        return factor
    }

    /// Mean of the current per-axis levels in `profile`.
    static func meanLevel(of profile: AttributeProfile) -> Double {
        let levels = AttributeKey.allCases.map { Double(profile.level(for: $0)) }
        guard !levels.isEmpty else { return 0 }
        return levels.reduce(0, +) / Double(levels.count)
    }

    /// Compute per-attribute deltas for a finished workout. Pure — no IO.
    static func deltas(for session: WorkoutLog, catalog: AttributeCatalogProtocol) -> [AttributeKey: Double] {
        let entries = session.exerciseEntries
        guard !entries.isEmpty else { return [:] }

        // session intensity from overall RPE (1...10 → 0...1). Fallback 0.5 if missing.
        let intensity = Double(session.overallRPE ?? 5) / 10.0

        // Effort mass per entry. Weighted work uses load x reps; bodyweight /
        // skill work still counts through reps so calisthenics can shape the
        // expression hex instead of disappearing when weightKg is nil.
        func effortMass(_ entry: ExerciseLogEntry) -> Double {
            entry.sets
                .filter { !$0.isWarmup }
                .reduce(0.0) { acc, set in
                    let loadFactor = max(set.weightKg ?? 10, 10)
                    return acc + loadFactor * Double(max(set.reps, 1))
                }
        }

        // Skipped exercises must not contribute effort — even if the user logged
        // a set or two before tapping skip.
        let masses = entries
            .filter { !$0.skipped }
            .map { ($0, effortMass($0)) }
        let total = masses.map(\.1).reduce(0, +)
        guard total > 0 else { return [:] }

        var deltas: [AttributeKey: Double] = [:]
        for (entry, mass) in masses where mass > 0 {
            let share = mass / total
            let contrib = catalog.contribution(
                forMovementId: entry.movementId,
                rankStandardMovementId: entry.rankStandardMovementId,
                fallbackExerciseName: entry.exerciseName
            )
            for key in AttributeKey.allCases {
                let w = contrib.weight(for: key)
                guard w > 0 else { continue }
                deltas[key, default: 0] += intensity * share * w * gainConstant
            }
        }
        return deltas
    }

    /// Compute permanent attribute XP from movement AP. This is the canonical
    /// PROGRESSION.md path: raw AP fans out through the movement's attribute
    /// vector. Body-map novelty is intentionally a multiplier here, not on
    /// the raw movement AP ledger.
    static func xpDeltas(
        for movementGains: [MovementAPGain],
        catalog: AttributeCatalogProtocol,
        noveltyMultiplier: Double = 1.0
    ) -> [AttributeKey: Double] {
        guard !movementGains.isEmpty else { return [:] }
        let novelty = max(1.0, noveltyMultiplier)
        var deltas: [AttributeKey: Double] = [:]

        for gain in movementGains where gain.rawAP > 0 {
            let contribution = catalog.contribution(
                forMovementId: gain.movementId,
                rankStandardMovementId: gain.rankStandardMovementId,
                fallbackExerciseName: gain.movementDisplayName
            )

            let awardedXP = RewardLedgerQuantizer.splitWholePoints(
                total: gain.rawAP * novelty,
                weights: AttributeKey.allCases.map { key in
                    (key: key, weight: contribution.weight(for: key))
                }
            )

            for (key, xp) in awardedXP {
                deltas[key, default: 0] += xp
            }
        }

        return deltas
    }

    /// Returns the dominant (highest-delta) axis for a finished workout, or nil if no deltas.
    /// Used by SessionXPService to check squad affinity bonus eligibility.
    static func dominantAxis(for session: WorkoutLog, catalog: AttributeCatalogProtocol) -> AttributeKey? {
        let d = deltas(for: session, catalog: catalog)
        return d.max(by: { $0.value < $1.value })?.key
    }

    // NOTE: skill-session deltas path deferred — `UserSkillProgress.Session` does not
    // exist in this codebase yet. When the skill-session completion type is introduced,
    // add a `static func deltas(for skillSession:catalog:) -> [AttributeKey: Double]`
    // overload here. Spec target: `(durationMin / 30) × (rpe / 10) × catalog vector × gainConstant`.

    /// Rank-up event for a tier crossing on the single RankTitle ladder.
    private static func rankUpEvent(
        axis: AttributeKey,
        from previousTier: RankTitle,
        to currentTier: RankTitle,
        at date: Date
    ) -> AttributeRankUpEvent? {
        guard currentTier != previousTier else { return nil }
        let crownBand: Set<RankTitle> = [.vessel, .unbound, .ascendant]
        let level: AttributeRankUpEvent.Level = crownBand.contains(currentTier) ? .aTier : .tier
        return AttributeRankUpEvent(
            axis: axis,
            fromTitle: previousTier, toTitle: currentTier,
            level: level, timestamp: date
        )
    }

    /// Mutates `profile` in place (legacy WorkoutLog path): converts coarse
    /// session deltas to permanent XP, returns tier-crossing events.
    static func applyDeltas(
        _ profile: inout AttributeProfile,
        deltas: [AttributeKey: Double],
        at date: Date
    ) -> [AttributeRankUpEvent] {
        var events: [AttributeRankUpEvent] = []
        for key in AttributeKey.allCases {
            let delta = deltas[key] ?? 0
            guard delta > 0 else { continue }
            var v = profile.value(for: key)
            let previousTier = v.rankTitle
            v.xp += delta * sessionDeltaXPScale
            v.lastContributionAt = date
            profile.set(key, v)
            if let event = rankUpEvent(axis: key, from: previousTier, to: v.rankTitle, at: date) {
                events.append(event)
            }
        }
        return events
    }

    /// Mutates `profile` by adding permanent XP from the AP fan-out path.
    /// Returns reward rows plus tier-crossing rank-up events.
    static func applyXPDeltas(
        _ profile: inout AttributeProfile,
        xpDeltas: [AttributeKey: Double],
        at date: Date
    ) -> AttributeAPApplyResult {
        var rewards: [AttributeProgressionReward] = []
        var events: [AttributeRankUpEvent] = []

        // Per-axis catch-up: scale each axis's gain by a factor off the CURRENT
        // (pre-ingest) per-axis levels. Neglected axes (below the mean) gain
        // faster; over-fed / near-cap axes slow. On top of the novelty
        // multiplier already baked into `xpDeltas`.
        let mean = meanLevel(of: profile)

        for key in AttributeKey.allCases {
            let rawXPGained = xpDeltas[key] ?? 0
            guard rawXPGained > 0 else { continue }

            var value = profile.value(for: key)
            let previousXP = value.xp
            let previousLevel = value.level
            let previousTier = value.rankTitle

            let xpGained = rawXPGained * catchUpFactor(axisLevel: previousLevel, meanLevel: mean)
            value.xp += xpGained
            value.lastContributionAt = date
            profile.set(key, value)

            let currentTier = value.rankTitle
            if let event = rankUpEvent(axis: key, from: previousTier, to: currentTier, at: date) {
                events.append(event)
            }

            rewards.append(AttributeProgressionReward(
                key: key,
                xpGained: xpGained,
                previousXP: previousXP,
                currentXP: value.xp,
                previousLevel: previousLevel,
                currentLevel: value.level,
                previousTier: previousTier,
                currentTier: currentTier
            ))
        }

        return AttributeAPApplyResult(rewards: rewards, rankUpEvents: events)
    }
}

struct AttributeAPApplyResult: Sendable {
    var rewards: [AttributeProgressionReward] = []
    var rankUpEvents: [AttributeRankUpEvent] = []
}

struct AttributeAPIngestResult: Sendable {
    var rewards: [AttributeProgressionReward] = []
    var rankUpEvents: [AttributeRankUpEvent] = []

    var totalXPGained: Double {
        rewards.reduce(0) { $0 + $1.xpGained }
    }

    var didIncreaseAnyLevel: Bool {
        rewards.contains(where: \.didIncreaseLevel)
    }
}

struct AttributeProgressionReward: Sendable {
    var key: AttributeKey
    var xpGained: Double
    var previousXP: Double
    var currentXP: Double
    var previousLevel: Int
    var currentLevel: Int
    var previousTier: RankTitle
    var currentTier: RankTitle

    var didIncreaseLevel: Bool { currentLevel > previousLevel }
    var didAdvanceTier: Bool { currentTier.ordinal > previousTier.ordinal }
}
