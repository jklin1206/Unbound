import Foundation

/// Pure, dependency-free derivations from a single recent-logs fetch.
/// Exists so the Home load can dedupe three `workout_logs` fetches into one
/// and still be unit-tested. The week logic is lifted verbatim from the
/// original `refreshWeeklyRhythm`.
enum HomeLoadDerivations {

    static func lastLog(_ logs: [WorkoutLog]) -> WorkoutLog? { logs.first }

    static func hasLogged(_ logs: [WorkoutLog]) -> Bool { !logs.isEmpty }

    static func bodyRegionLoads(_ logs: [WorkoutLog],
                                now: Date = .now,
                                calendar baseCal: Calendar = .current,
                                recentDays: Int = 7) -> [BodyRegion: Double] {
        guard recentDays > 0 else { return [:] }

        var loads: [BodyRegion: Double] = [:]
        let cutoff = baseCal.date(byAdding: .day, value: -recentDays, to: now)
            ?? now.addingTimeInterval(-TimeInterval(recentDays) * 24 * 60 * 60)
        let window = max(1, now.timeIntervalSince(cutoff))

        for log in logs where log.startedAt >= cutoff && log.startedAt <= now {
            let age = max(0, now.timeIntervalSince(log.startedAt))
            let recency = max(0.55, 1.0 - (age / window) * 0.45)

            for entry in log.exerciseEntries where !entry.skipped {
                let completedSets = entry.sets.filter { !$0.isWarmup }.count
                let setCount = completedSets > 0 ? completedSets : entry.plannedSets
                guard setCount > 0 else { continue }

                let score = Double(setCount) * recency * rpeMultiplier(for: entry)
                for region in bodyRegions(for: entry) {
                    loads[region, default: 0] += score
                }
            }
        }

        return loads
    }

    /// Monday-indexed (Mon=1 … Sun=7) set of weekdays with a session this
    /// calendar week. `startedAts` are each log's `startedAt`.
    static func weekSessionDays(_ startedAts: [Date],
                                now: Date = .now,
                                calendar baseCal: Calendar = .current) -> Set<Int> {
        var cal = baseCal
        cal.firstWeekday = 2 // Monday
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let weekStart = cal.date(from: components) else { return [] }
        var days: Set<Int> = []
        for started in startedAts where started >= weekStart {
            let weekday = cal.component(.weekday, from: started)
            let monIndex = ((weekday + 5) % 7) + 1
            days.insert(monIndex)
        }
        return days
    }

    private static func bodyRegions(for entry: ExerciseLogEntry) -> [BodyRegion] {
        if let resolved = MovementCatalog.resolvedTrainingMovement(
            name: entry.exerciseName,
            movementId: entry.movementId,
            rankStandardMovementId: entry.rankStandardMovementId
        ) {
            if !resolved.exact.bodyRegions.isEmpty {
                return Array(Set(resolved.exact.bodyRegions)).sorted { $0.rawValue < $1.rawValue }
            }
            if let standard = resolved.standard, !standard.bodyRegions.isEmpty {
                return Array(Set(standard.bodyRegions)).sorted { $0.rawValue < $1.rawValue }
            }
        }

        let normalizedName = MovementCatalog.normalized(entry.exerciseName)
        let regions = BodyRegion.allCases.filter { region in
            region.contributingLifts.contains { lift in
                normalizedName.contains(MovementCatalog.normalized(lift))
            }
        }
        return Array(Set(regions)).sorted { $0.rawValue < $1.rawValue }
    }

    private static func rpeMultiplier(for entry: ExerciseLogEntry) -> Double {
        let rpes = entry.sets.compactMap(\.rpe)
        guard !rpes.isEmpty else { return 1.0 }
        let average = Double(rpes.reduce(0, +)) / Double(rpes.count)
        let clamped = min(10.0, max(1.0, average))
        return 0.9 + (clamped / 10.0) * 0.2
    }
}
