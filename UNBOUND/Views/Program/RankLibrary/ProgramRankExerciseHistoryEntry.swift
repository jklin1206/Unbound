import SwiftUI
import UIKit

enum ProgramRankExerciseLogMode: Equatable {
    case oneRepMax
    case reps
    case hold

    static func mode(for definition: MovementDefinition) -> ProgramRankExerciseLogMode {
        switch definition.rankTemplate {
        case .barbellStrength, .machineStrength, .weightedBodyweight:
            return .oneRepMax
        case .bodyweightReps:
            return .reps
        case .holdControl, .mobilityDuration:
            return .hold
        case .cardioPerformance:
            switch definition.defaultMetric {
            case .reps: return .reps
            case .holdSeconds, .durationSeconds, .distanceMeters, .calories: return .hold
            }
        case .carrySled:
            return .hold
        case .routineCompletion, .unranked:
            switch definition.loggerMode {
            case .strengthSets: return .oneRepMax
            case .bodyweightSets, .skillAttempts: return .reps
            case .hold: return .hold
            case .carry, .cardio, .mobility, .routinePlayer: return .hold
            }
        }
    }

    var recordsReps: Bool {
        switch self {
        case .reps: return true
        case .oneRepMax, .hold: return false
        }
    }

    var recordsOneRepMax: Bool {
        switch self {
        case .oneRepMax: return true
        case .reps, .hold: return false
        }
    }

    var accessibilityUnit: String {
        switch self {
        case .oneRepMax:
            return "one rep max"
        case .reps:
            return "reps"
        case .hold:
            return "hold time"
        }
    }
}

struct ProgramRankExerciseHistoryEntry: Identifiable {
    let id: String
    let occurredAt: Date
    let summary: String
    let oneRepMaxKg: Double?
    let reps: Int?
    let holdSeconds: Int?

    var dateText: String {
        occurredAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    static func entries(
        from logs: [PerformanceLog],
        rankStandardMovementId: String
    ) -> [ProgramRankExerciseHistoryEntry] {
        var entries: [ProgramRankExerciseHistoryEntry] = []
        for log in logs.sorted(by: { $0.completedAt > $1.completedAt }) {
            for block in log.blocks {
                for exercise in block.exercises where !exercise.skipped {
                    let resolvedStandard = exercise.rankStandardMovementId
                        ?? MovementResolver.resolve(exercise.name).rankStandardMovementId
                    guard resolvedStandard == rankStandardMovementId else { continue }

                    for set in exercise.sets where !set.isWarmup {
                        guard let summary = ProgramRankExerciseFormatter.summary(for: set) else { continue }
                        entries.append(
                            ProgramRankExerciseHistoryEntry(
                                id: "\(log.id):\(exercise.id):\(set.id)",
                                occurredAt: log.completedAt,
                                summary: summary,
                                oneRepMaxKg: estimatedOneRepMaxKg(weightKg: set.weightKg, reps: set.reps),
                                reps: set.reps.flatMap { $0 > 0 ? $0 : nil },
                                holdSeconds: set.holdSeconds ?? set.durationSeconds
                            )
                        )
                    }
                }
            }
        }
        return Array(entries.prefix(80))
    }

    /// Attempt history for a SKILL, gathered from blocks the skill itself logged
    /// (`block.skillId`). Skills rank on their own criterion, so their history is
    /// keyed by skill identity — independent of whatever movement twin a reps
    /// template might resolve. A hold set's reps==0 sentinel is dropped so it
    /// reads as a hold, not "0 reps".
    static func entries(
        from logs: [PerformanceLog],
        skillId: String
    ) -> [ProgramRankExerciseHistoryEntry] {
        var entries: [ProgramRankExerciseHistoryEntry] = []
        for log in logs.sorted(by: { $0.completedAt > $1.completedAt }) {
            for block in log.blocks where block.skillId == skillId {
                for exercise in block.exercises where !exercise.skipped {
                    for set in exercise.sets where !set.isWarmup {
                        guard let summary = ProgramRankExerciseFormatter.summary(for: set) else { continue }
                        entries.append(
                            ProgramRankExerciseHistoryEntry(
                                id: "\(log.id):\(exercise.id):\(set.id)",
                                occurredAt: log.completedAt,
                                summary: summary,
                                oneRepMaxKg: estimatedOneRepMaxKg(weightKg: set.weightKg, reps: set.reps),
                                reps: set.reps.flatMap { $0 > 0 ? $0 : nil },
                                holdSeconds: set.holdSeconds ?? set.durationSeconds
                            )
                        )
                    }
                }
            }
        }
        return Array(entries.prefix(80))
    }

    private static func estimatedOneRepMaxKg(weightKg: Double?, reps: Int?) -> Double? {
        guard let weightKg, weightKg > 0 else { return nil }
        let safeReps = max(reps ?? 1, 1)
        guard safeReps > 1 else { return weightKg }
        return weightKg * (1.0 + Double(safeReps) / 30.0)
    }
}

enum ProgramRankExerciseFormatter {
    static func bestSummary(_ progress: MovementProgressState) -> String {
        let unit = WeightPlatePolicy.currentUnit
        if let estimated = progress.bestEstimatedOneRepMaxKg {
            return "1RM \(WeightPlatePolicy.formatLoggedWeight(estimated, unit: unit))\(unit.shortLabel)"
        }
        if let load = progress.bestLoadKg {
            let weight = "\(WeightPlatePolicy.formatLoggedWeight(load, unit: unit))\(unit.shortLabel)"
            if let reps = progress.bestReps {
                return "\(weight) x \(reps)"
            }
            return weight
        }
        if let reps = progress.bestReps {
            return "\(reps) reps"
        }
        if let hold = progress.bestHoldSeconds {
            return "\(seconds(hold)) hold"
        }
        if let duration = progress.bestDurationSeconds {
            return "\(seconds(duration)) hold"
        }
        return progress.rankTemplate.displayName
    }

    static func summary(for set: PerformanceSet) -> String? {
        let unit = WeightPlatePolicy.currentUnit
        if let weight = set.weightKg, let reps = set.reps, reps > 0 {
            return "\(WeightPlatePolicy.formatLoggedWeight(weight, unit: unit))\(unit.shortLabel) x \(reps)"
        }
        // A hold set may carry reps == 0 as a sentinel; treat that as "no reps"
        // so the summary falls through to the hold instead of printing "0 reps".
        if let reps = set.reps, reps > 0 {
            return "\(reps) reps"
        }
        if let hold = set.holdSeconds {
            return "\(seconds(hold)) hold"
        }
        if let duration = set.durationSeconds {
            return "\(seconds(duration)) hold"
        }
        return nil
    }

    static func seconds(_ value: Int) -> String {
        if value < 60 { return "\(value)s" }
        let minutes = value / 60
        let seconds = value % 60
        if seconds == 0 { return "\(minutes)m" }
        return "\(minutes):" + String(format: "%02d", seconds)
    }

    static func distance(_ meters: Int) -> String {
        if meters >= 1_000 {
            let kilometers = Double(meters) / 1_000.0
            if abs(kilometers.rounded() - kilometers) < 0.001 {
                return "\(Int(kilometers.rounded()))km"
            }
            return String(format: "%.1fkm", kilometers)
        }
        return "\(meters)m"
    }
}
