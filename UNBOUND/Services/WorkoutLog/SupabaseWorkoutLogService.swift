import Foundation

// MARK: - SupabaseWorkoutLogService
//
// WorkoutLog persistence now flows through the unified offline outbox:
// SyncedDatabase writes the local store (authoritative, instant) and
// enqueues the cloud upsert/delete, which SyncEngine drains on
// foreground/reconnect. This file keeps the post-save side-effect chain
// (progression, skill recompute, rank, skins, session XP, badges) and the
// profile loader. The previous ad-hoc "try Supabase / catch any error /
// fall back to local" logic is removed — the outbox is the single sync path.

final class SupabaseWorkoutLogService: WorkoutLogServiceProtocol, WorkoutLogCompatibilityHistoryWriting, @unchecked Sendable {
    static let shared = SupabaseWorkoutLogService()

    private let db = SyncedDatabase.shared
    private let workingWeight = WorkingWeightService.shared
    private let logger = LoggingService.shared

    private init() {}

    // MARK: - saveLog

    func saveLog(_ log: WorkoutLog) async throws {
        // MIGRATION(Phase 9): legacy direct save still runs old post-save
        // side effects. New completion routes must call TrainingCompletionService
        // and saveCompatibleHistoryLog(_:) for WorkoutLog compatibility.
        // Local-authoritative write + outbox enqueue (offline-safe).
        try await db.create(log, collection: "workoutLogs", documentId: log.id)

        guard log.hasCompletedWorkingSet else {
            logger.log(
                "Workout logged without completed working sets; skipped progression side effects",
                level: .info,
                context: ["dayNumber": log.dayNumber]
            )
            return
        }

        // --- Side-effects: identical chain to WorkoutLogService.saveLog() ---
        try await workingWeight.updateFromLog(log, userId: log.userId)

        let profile: UserProfile? = await loadProfile(userId: log.userId)

        let progressionMode: ProgressionMode = (profile?.cutMode.enabled == true) ? .preserve : .advance
        let feedbackMode = profile?.trainingFeedbackMode
        await ProgressionEngine.shared.ingest(
            log: log,
            mode: progressionMode,
            feedbackMode: feedbackMode
        )

        if let profile {
            let bw = profile.weightKg
            await SkillProgressService.shared.recompute(after: log, userBodyweightKg: bw)

            if let bw, bw > 0 {
                await RankService.shared.evaluate(log: log, bodyweightKg: bw)
            }

            _ = await SkinService.shared.evaluateUnlocks(userId: log.userId)
            await SessionXPService.shared.recordSession(userId: log.userId, at: log.startedAt)
            _ = await BadgeService.shared.evaluate(trigger: .sessionLogged(log))
        }

        logger.log("Workout logged: \(log.plannedWorkoutName)", level: .info, context: ["dayNumber": log.dayNumber])
    }

    func saveCompatibleHistoryLog(_ log: WorkoutLog) async throws {
        // MIGRATION(Phase 9): compatibility-only history write. It keeps old
        // history/rendering paths alive without re-running legacy awards.
        try await db.create(log, collection: "workoutLogs", documentId: log.id)
    }

    // MARK: - updateLog

    func updateLog(_ log: WorkoutLog) async throws {
        // Upsert semantics: rewrite the doc locally + enqueue.
        try await db.create(log, collection: "workoutLogs", documentId: log.id)
    }

    // MARK: - fetchLogs

    func fetchLogs(userId: String, programId: String?) async throws -> [WorkoutLog] {
        let logs: [WorkoutLog] = try await db.query(
            collection: "workoutLogs", field: "userId", isEqualTo: userId,
            orderBy: "startedAt", descending: true, limit: nil
        )
        if let programId { return logs.filter { $0.programId == programId } }
        return logs
    }

    // MARK: - fetchRecentLogs

    func fetchRecentLogs(userId: String, limit: Int) async throws -> [WorkoutLog] {
        try await db.query(
            collection: "workoutLogs", field: "userId", isEqualTo: userId,
            orderBy: "startedAt", descending: true, limit: limit
        )
    }

    // MARK: - deleteLog

    func deleteLog(id: String) async throws {
        try await db.delete(collection: "workoutLogs", documentId: id)
    }

    // MARK: - Helpers

    /// Load the user profile from the local store (local-first; profile
    /// cloud sync is handled by the outbox / restore path elsewhere).
    private func loadProfile(userId: String) async -> UserProfile? {
        try? await DatabaseService.shared.read(collection: "users", documentId: userId)
    }
}

extension WorkoutLog {
    var hasCompletedWorkingSet: Bool {
        exerciseEntries.contains { entry in
            !entry.skipped && entry.sets.contains { !$0.isWarmup && $0.reps > 0 }
        }
    }
}
