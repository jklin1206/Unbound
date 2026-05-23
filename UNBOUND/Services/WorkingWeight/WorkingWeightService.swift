import Foundation

final class WorkingWeightService: WorkingWeightServiceProtocol, @unchecked Sendable {
    static let shared = WorkingWeightService()
    private let database = DatabaseService.shared
    private let logger = LoggingService.shared

    private init() {}

    func fetchWeights(userId: String) async throws -> [WorkingWeight] {
        try await database.query(
            collection: "workingWeights", field: "userId", isEqualTo: userId,
            orderBy: nil, descending: true, limit: nil
        )
    }

    func fetchWeight(userId: String, exerciseName: String) async throws -> WorkingWeight? {
        let weights: [WorkingWeight] = try await database.query(
            collection: "workingWeights", field: "userId", isEqualTo: userId,
            orderBy: nil, descending: true, limit: nil
        )
        return weights.first { $0.exerciseName == exerciseName }
    }

    func updateFromLog(_ log: WorkoutLog, userId: String) async throws {
        for entry in log.exerciseEntries where !entry.skipped {
            let workingSets = entry.sets.filter { !$0.isWarmup }
            guard let bestSet = workingSets.max(by: { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }),
                  let weight = bestSet.weightKg else { continue }

            let normalizedName = entry.exerciseName.lowercased().replacingOccurrences(of: " ", with: "_")
            let existing = try? await fetchWeight(userId: userId, exerciseName: normalizedName)

            let hitTarget = bestSet.reps >= (Int(entry.plannedReps.split(separator: "-").last ?? "0") ?? 0)
                && (bestSet.rpe ?? 10) <= 8

            let consecutiveSessions: Int
            if hitTarget {
                consecutiveSessions = (existing?.consecutiveSessionsAtTarget ?? 0) + 1
            } else {
                consecutiveSessions = 0
            }

            let workingWeight = WorkingWeight(
                id: existing?.id ?? normalizedName,
                userId: userId,
                exerciseName: normalizedName,
                weightKg: weight,
                lastReps: bestSet.reps,
                lastRPE: bestSet.rpe,
                updatedAt: Date(),
                sourceLogId: log.id,
                consecutiveSessionsAtTarget: consecutiveSessions
            )

            try await database.create(workingWeight, collection: "workingWeights", documentId: workingWeight.id)
            let unit = WeightPlatePolicy.currentUnit
            logger.log(
                "Working weight updated: \(normalizedName) -> \(WeightPlatePolicy.formatLoggedWeight(weight, unit: unit))\(unit.shortLabel)",
                level: .info
            )
        }
    }

    func getProgressionSuggestion(for exerciseName: String, userId: String) async throws -> ProgressionSuggestion? {
        guard let weight = try await fetchWeight(userId: userId, exerciseName: exerciseName) else { return nil }

        // Check if RPE is consistently too high
        if let rpe = weight.lastRPE, rpe >= 10 {
            return .deload(percentage: 10)
        }

        // Check consecutive sessions at target for progression
        if weight.consecutiveSessionsAtTarget >= 2 {
            let definition = MovementCatalog.canonicalExercise(named: exerciseName)
            let isCompound = definition.map(ExerciseLibrary.isCompound) ?? false
            let isLowerBody = definition?
                .muscleGroups.contains(where: { [.legs, .glutes].contains($0) }) ?? false

            if isCompound {
                return .increaseWeight(
                    amount: WeightPlatePolicy.progressionJumpKilograms(
                        for: isLowerBody ? .lowerCompound : .upperCompound
                    )
                )
            } else {
                return .increaseReps
            }
        }

        return .hold
    }
}
