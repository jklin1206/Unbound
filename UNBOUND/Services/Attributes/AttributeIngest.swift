// UNBOUND/Services/Attributes/AttributeIngest.swift
import Foundation

protocol AttributeCatalogProtocol: AnyObject {
    func contribution(forExerciseName name: String) -> AttributeContribution
    func contribution(forSkillNodeId id: String) -> AttributeContribution
}

enum AttributeIngest {
    static let gainConstant: Double = 4.0

    /// Compute per-attribute deltas for a finished workout. Pure — no IO.
    static func deltas(for session: WorkoutLog, catalog: AttributeCatalogProtocol) -> [AttributeKey: Double] {
        let entries = session.exerciseEntries
        guard !entries.isEmpty else { return [:] }

        // session intensity from overall RPE (1...10 → 0...1). Fallback 0.5 if missing.
        let intensity = Double(session.overallRPE ?? 5) / 10.0

        // effort mass per entry: Σ weight × reps across sets (warmups excluded).
        func effortMass(_ entry: ExerciseLogEntry) -> Double {
            entry.sets
                .filter { !$0.isWarmup }
                .reduce(0.0) { acc, set in
                    acc + (set.weightKg ?? 0) * Double(set.reps)
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
            let contrib = catalog.contribution(forExerciseName: entry.exerciseName)
            for key in AttributeKey.allCases {
                let w = contrib.weight(for: key)
                guard w > 0 else { continue }
                deltas[key, default: 0] += intensity * share * w * gainConstant
            }
        }
        return deltas
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
}
