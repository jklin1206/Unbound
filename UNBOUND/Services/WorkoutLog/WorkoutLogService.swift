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

        // Fetch the user's profile once so we can thread its
        // cut-mode + feedback preferences into ProgressionEngine, and
        // reuse it for skill-tree recompute below.
        let profile: UserProfile? = try? await database.read(collection: "users", documentId: log.userId)

        // Hawks-style RPE progression. Evaluates each exercise in the log
        // against its ProgressionState, bumps weights when the
        // 2-consecutive-sessions-at-target-RPE rule fires, publishes
        // `.progressionAdvanced` for UI toasts.
        //
        // `.preserve` mode holds weights while the user is on a cut.
        // Tier unlocks still fire regardless of mode. Feedback mode
        // seeds new ProgressionState rows with the right targetRPE
        // (`.silent` → 0 → pure rep-based progression).
        let progressionMode: ProgressionMode = (profile?.cutMode.enabled == true) ? .preserve : .advance
        let feedbackMode = profile?.trainingFeedbackMode
        await ProgressionEngine.shared.ingest(
            log: log,
            mode: progressionMode,
            feedbackMode: feedbackMode
        )

        // Recompute skill tree state. Reads user's bodyweight
        // from the UserProfile and evaluates every node against the logs.
        if let profile {
            let bw = profile.weightKg
            await SkillProgressService.shared.recompute(after: log, userBodyweightKg: bw)

            // SubRank system: detect sub-rank threshold crossings per lift
            // and post `.rankAdvanced` for the UI cinematic.
            if let bw, bw > 0 {
                await RankService.shared.evaluate(log: log, bodyweightKg: bw)
            }

            // After rank evaluation, check for skin unlocks and record
            // session XP + badge triggers.
            _ = await SkinService.shared.evaluateUnlocks(userId: log.userId)
            await SessionXPService.shared.recordSession(userId: log.userId, at: log.startedAt)
            _ = await BadgeService.shared.evaluate(trigger: .sessionLogged(log))
        }

        // Attribute System: ingest this session to update the 6-axis hex.
        // Fires .attributeRankUp notifications for any tier crossings.
        await AttributeService.shared.ingest(session: log, userId: log.userId)

        // Ascension Tier: evaluate tier crossings against new log + accumulated history.
        // Fires .skillTierAdvanced for each crossing (skill or aggregate).
        // Listeners decide: cinematic for top-3 tiers (Vessel/Unbound/Ascendant),
        // TierBloomToast for lower crossings.
        let advances = await RankService.shared.evaluateTierCrossings(log: log, userId: log.userId)
        for advance in advances {
            NotificationCenter.default.post(name: .skillTierAdvanced, object: advance)
        }

        // Trials: evaluate capstone progress from this log.
        await TrialsService.shared.evaluateCapstoneFromLog(
            userId: log.userId,
            history: log.exerciseEntries,
            bodyweightKg: profile?.weightKg ?? 70.0
        )

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
