import Foundation

struct BodyLoadRegionStatus: Equatable {
    let region: BodyRegion
    var load: Double
    var lastTrainedAt: Date?

    init(region: BodyRegion, load: Double = 0, lastTrainedAt: Date? = nil) {
        self.region = region
        self.load = load
        self.lastTrainedAt = lastTrainedAt
    }

    var recoveryHours: Int {
        let displayedLoad = load < 1 ? load : Double(Int(load.rounded()))
        switch displayedLoad {
        case ..<0.5:
            return 0
        case ..<6:
            return 24
        case ..<13:
            return 36
        case ..<22:
            return 48
        default:
            return 72
        }
    }

    var recoveryReadyAt: Date? {
        guard let lastTrainedAt else { return nil }
        return lastTrainedAt.addingTimeInterval(TimeInterval(recoveryHours) * 60 * 60)
    }

    func lastTrainedText(relativeTo now: Date = .now) -> String {
        guard let lastTrainedAt else { return "No recent session" }
        return "Last trained \(Self.relativeText(since: lastTrainedAt, now: now))"
    }

    func recoveryText(relativeTo now: Date = .now) -> String {
        guard let recoveryReadyAt else { return "Ready now" }
        let remaining = recoveryReadyAt.timeIntervalSince(now)
        guard remaining > 0 else { return "Ready now" }
        return "Ready in \(Self.durationText(remaining))"
    }

    private static func relativeText(since date: Date, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 * 60 {
            return "\(max(1, Int(seconds / 60)))m ago"
        }
        if seconds < 24 * 60 * 60 {
            return "\(max(1, Int(seconds / (60 * 60))))h ago"
        }
        let days = max(1, Int(seconds / (24 * 60 * 60)))
        return days == 1 ? "yesterday" : "\(days)d ago"
    }

    private static func durationText(_ seconds: TimeInterval) -> String {
        let minutes = Int(ceil(seconds / 60))
        if minutes < 60 {
            return "\(max(1, minutes))m"
        }
        let hours = Int(ceil(Double(minutes) / 60.0))
        if hours < 24 {
            return "\(hours)h"
        }
        let days = hours / 24
        let remainingHours = hours % 24
        return remainingHours == 0 ? "\(days)d" : "\(days)d \(remainingHours)h"
    }
}

/// Pure, dependency-free derivations from a single recent-logs fetch.
/// Exists so the Home load can dedupe three `workout_logs` fetches into one
/// and still be unit-tested. The week logic is lifted verbatim from the
/// original `refreshWeeklyRhythm`.
enum HomeLoadDerivations {

    static func lastLog(_ logs: [WorkoutLog]) -> WorkoutLog? { logs.first }

    static func hasLogged(_ logs: [WorkoutLog]) -> Bool { !logs.isEmpty }

    /// True when *today's specific program day* was completed — matched on
    /// program + day number + the local calendar day, against the canonical
    /// `PerformanceLog` record (the superset every completion writes; a derived
    /// `WorkoutLog` is filtered and absent for cardio-/routine-only quests).
    /// Unlike `SessionXPRecord.loggedToday()` (true for ANY session today,
    /// including rank trials or extra workouts), this only fires when the
    /// displayed quest itself was completed.
    static func didCompleteProgramDayToday(
        _ logs: [PerformanceLog],
        programId: String,
        dayNumber: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        logs.contains { log in
            log.programId == programId
                && log.dayNumber == dayNumber
                && calendar.isDate(log.completedAt, inSameDayAs: now)
        }
    }

    static func bodyRegionLoads(_ logs: [WorkoutLog],
                                now: Date = .now,
                                calendar baseCal: Calendar = .current,
                                recentDays: Int = 7) -> [BodyRegion: Double] {
        bodyRegionStatuses(logs, now: now, calendar: baseCal, recentDays: recentDays)
            .reduce(into: [:]) { result, entry in
                if entry.value.load > 0.05 {
                    result[entry.key] = entry.value.load
                }
            }
    }

    static func bodyRegionStatuses(_ logs: [WorkoutLog],
                                   now: Date = .now,
                                   calendar baseCal: Calendar = .current,
                                   recentDays: Int = 7) -> [BodyRegion: BodyLoadRegionStatus] {
        guard recentDays > 0 else { return [:] }

        var statuses: [BodyRegion: BodyLoadRegionStatus] = [:]
        let cutoff = baseCal.date(byAdding: .day, value: -recentDays, to: now)
            ?? now.addingTimeInterval(-TimeInterval(recentDays) * 24 * 60 * 60)
        let window = max(1, now.timeIntervalSince(cutoff))

        for log in logs where log.startedAt <= now {
            let age = max(0, now.timeIntervalSince(log.startedAt))
            let recency = max(0.55, 1.0 - (age / window) * 0.45)
            let shouldCountRecentLoad = log.startedAt >= cutoff

            for entry in log.exerciseEntries where !entry.skipped {
                let completedSets = entry.sets.filter { !$0.isWarmup }.count
                let setCount = completedSets > 0 ? completedSets : entry.plannedSets
                guard setCount > 0 else { continue }

                let score = shouldCountRecentLoad
                    ? Double(setCount) * recency * rpeMultiplier(for: entry)
                    : 0
                for region in bodyRegions(for: entry) {
                    var status = statuses[region] ?? BodyLoadRegionStatus(region: region)
                    status.load += score
                    if status.lastTrainedAt.map({ log.startedAt > $0 }) ?? true {
                        status.lastTrainedAt = log.startedAt
                    }
                    statuses[region] = status
                }
            }
        }

        return statuses
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
