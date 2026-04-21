import Foundation

final class WorkoutLogService: WorkoutLogServiceProtocol, @unchecked Sendable {
    static let shared = WorkoutLogService()
    private let database = DatabaseService.shared
    private let workingWeight = WorkingWeightService.shared
    private let logger = LoggingService.shared

    private init() {}

    func saveLog(_ log: WorkoutLog) async throws {
        try await database.create(log, collection: "workoutLogs", documentId: log.id)
        // Auto-update working weights from this log
        try await workingWeight.updateFromLog(log, userId: log.userId)

        // Hawks-style RPE progression. Evaluates each exercise in the log
        // against its ProgressionState, bumps weights when the
        // 2-consecutive-sessions-at-target-RPE rule fires, publishes
        // `.progressionAdvanced` for UI toasts.
        await ProgressionEngine.shared.ingest(log: log)

        // Recompute skill tree state. Reads user's archetype + bodyweight
        // from the UserProfile and evaluates every node against the logs.
        if let profile: UserProfile = try? await database.read(collection: "users", documentId: log.userId) {
            let archetype = profile.preferredArchetype ?? .vTaper
            let bw = profile.weightKg
            await SkillProgressService.shared.recompute(after: log, for: archetype, userBodyweightKg: bw)

            // SubRank system: detect sub-rank threshold crossings per lift
            // and post `.rankAdvanced` for the UI cinematic.
            if let bw, bw > 0 {
                await RankService.shared.evaluate(log: log, bodyweightKg: bw)
            }

            // After rank evaluation, check for skin unlocks and record
            // session XP + badge triggers.
            _ = await SkinService.shared.evaluateUnlocks(userId: log.userId, archetype: archetype)
            await SessionXPService.shared.recordSession(userId: log.userId, at: log.startedAt)
            _ = await BadgeService.shared.evaluate(trigger: .sessionLogged(log))
        }

        logger.log("Workout logged: \(log.plannedWorkoutName)", level: .info, context: ["dayNumber": log.dayNumber])
    }

    func updateLog(_ log: WorkoutLog) async throws {
        let data = try JSONEncoder().encode(log)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        try await database.update(dict, collection: "workoutLogs", documentId: log.id)
    }

    func fetchLogs(userId: String, programId: String?) async throws -> [WorkoutLog] {
        if let programId {
            return try await database.query(
                collection: "workoutLogs", field: "userId", isEqualTo: userId,
                orderBy: "startedAt", descending: true, limit: nil
            ).filter { ($0 as WorkoutLog).programId == programId }
        }
        return try await database.query(
            collection: "workoutLogs", field: "userId", isEqualTo: userId,
            orderBy: "startedAt", descending: true, limit: nil
        )
    }

    func fetchRecentLogs(userId: String, limit: Int) async throws -> [WorkoutLog] {
        try await database.query(
            collection: "workoutLogs", field: "userId", isEqualTo: userId,
            orderBy: "startedAt", descending: true, limit: limit
        )
    }

    func deleteLog(id: String) async throws {
        try await database.delete(collection: "workoutLogs", documentId: id)
    }
}
