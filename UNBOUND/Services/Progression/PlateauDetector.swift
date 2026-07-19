import Foundation

struct PlateauedExercise: Identifiable, Hashable {
    let exerciseKey: String
    let displayName: String
    let stalledSessions: Int
    let currentWeightKg: Double

    var id: String { exerciseKey }
}

@MainActor
final class PlateauDetector {
    static let shared = PlateauDetector()
    private let workoutLog = WorkoutLogService.shared
    private let logger = LoggingService.shared

    private init() {}

    /// An exercise is considered plateaued when its `consecutiveSessionsAtTarget`
    /// has been zero across its last `DeloadPolicy.plateauAppearanceWindow`
    /// appearances in the workout log — i.e. the athlete has trained it that
    /// many times without hitting the advance threshold. Exercises already in a
    /// deload, or inside the post-deload cooldown, are skipped so a just-applied
    /// or just-exited deload cannot immediately re-register as a plateau.
    func detect(userId: String, states: [ProgressionState]) async -> [PlateauedExercise] {
        let logs = (try? await workoutLog.fetchRecentLogs(userId: userId, limit: 30)) ?? []
        guard !logs.isEmpty else { return [] }

        var appearancesByKey: [String: Int] = [:]
        for log in logs {
            for entry in log.exerciseEntries where !entry.skipped {
                let key = entry.exerciseName.lowercased().trimmingCharacters(in: .whitespaces)
                appearancesByKey[key, default: 0] += 1
            }
        }

        var result: [PlateauedExercise] = []
        for state in states {
            let appearances = appearancesByKey[state.exerciseKey] ?? 0
            guard appearances >= DeloadPolicy.plateauAppearanceWindow else { continue }
            guard state.consecutiveSessionsAtTarget == 0 else { continue }
            guard state.classification != .bodyweightSkill else { continue }
            guard state.blockType != .deload else { continue }
            guard (state.deloadCooldownRemaining ?? 0) == 0 else { continue }

            result.append(PlateauedExercise(
                exerciseKey: state.exerciseKey,
                displayName: state.displayName,
                stalledSessions: appearances,
                currentWeightKg: state.currentWorkingWeightKg
            ))
        }
        return result
    }
}
