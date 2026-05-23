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
    /// Transitional bridge while the profile hex still uses the legacy 0...100
    /// `current`/`peak` fields for shape. Permanent progression is stored in
    /// `AttributeValue.xp`; this scale only keeps the visible hex from freezing
    /// until the UI is fully XP-native.
    static let apXPToDisplayScoreScale: Double = 1.0 / AttributeLevelCurve.legacyScoreXPScale

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

    /// Mutates `profile` in place: adds deltas, lifts peaks, returns rank-up crossings.
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
            let beforeSub  = v.subRank
            let beforeTier = v.rankTitle
            v.xp += AttributeLevelCurve.xpAwarded(forScoreDelta: delta)
            v.current = min(100, v.current + delta)
            if v.current > v.peak { v.peak = v.current }
            v.lastContributionAt = date
            profile.set(key, v)
            let afterSub  = v.subRank
            let afterTier = v.rankTitle
            if afterSub != beforeSub {
                let level: AttributeRankUpEvent.Level = {
                    if afterTier != beforeTier {
                        let aTitles: Set<RankTitle> = [.vessel, .unbound, .ascendant]
                        return aTitles.contains(afterTier) ? .aTier : .tier
                    }
                    return .subRank
                }()
                events.append(AttributeRankUpEvent(
                    axis: key,
                    fromTitle: beforeTier, toTitle: afterTier,
                    fromSubRank: beforeSub, toSubRank: afterSub,
                    level: level, timestamp: date
                ))
            }
        }
        return events
    }

    /// Mutates `profile` by adding permanent XP from the AP fan-out path.
    /// Returns reward rows plus rank-up events for any legacy display-tier
    /// crossings caused by the small transitional score lift.
    static func applyXPDeltas(
        _ profile: inout AttributeProfile,
        xpDeltas: [AttributeKey: Double],
        at date: Date
    ) -> AttributeAPApplyResult {
        var rewards: [AttributeProgressionReward] = []
        var events: [AttributeRankUpEvent] = []

        for key in AttributeKey.allCases {
            let xpGained = xpDeltas[key] ?? 0
            guard xpGained > 0 else { continue }

            var value = profile.value(for: key)
            let previousXP = value.xp
            let previousLevel = value.level
            let previousSubRank = value.subRank
            let previousTier = value.rankTitle
            let previousScore = value.current

            value.xp += xpGained
            let displayDelta = xpGained * apXPToDisplayScoreScale
            value.current = min(100, value.current + displayDelta)
            value.peak = max(value.peak, value.current)
            value.lastContributionAt = date
            profile.set(key, value)

            let currentSubRank = value.subRank
            let currentTier = value.rankTitle
            if currentSubRank != previousSubRank {
                let level: AttributeRankUpEvent.Level = {
                    if currentTier != previousTier {
                        let aTitles: Set<RankTitle> = [.vessel, .unbound, .ascendant]
                        return aTitles.contains(currentTier) ? .aTier : .tier
                    }
                    return .subRank
                }()
                events.append(AttributeRankUpEvent(
                    axis: key,
                    fromTitle: previousTier,
                    toTitle: currentTier,
                    fromSubRank: previousSubRank,
                    toSubRank: currentSubRank,
                    level: level,
                    timestamp: date
                ))
            }

            rewards.append(AttributeProgressionReward(
                key: key,
                xpGained: xpGained,
                previousXP: previousXP,
                currentXP: value.xp,
                previousLevel: previousLevel,
                currentLevel: value.level,
                previousTier: previousTier,
                currentTier: currentTier,
                previousScore: previousScore,
                currentScore: value.current
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
    var previousScore: Double
    var currentScore: Double

    var didIncreaseLevel: Bool { currentLevel > previousLevel }
    var didAdvanceTier: Bool { currentTier.ordinal > previousTier.ordinal }
}
