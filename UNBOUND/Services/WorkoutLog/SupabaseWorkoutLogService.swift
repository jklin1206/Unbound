import Foundation

// MARK: - SupabaseWorkoutLogService
//
// Cloud-backed implementation of WorkoutLogServiceProtocol. Persists to the
// public.workout_logs table; runs the full local side-effect chain
// (progression, skill recompute, rank, skins, session XP, badges) after
// every save so the UI stays in sync with what local WorkoutLogService did.
//
// Falls back to the local WorkoutLogService when Supabase auth isn't ready
// — keeps dev / pre-Sign-in-with-Apple flows working.

final class SupabaseWorkoutLogService: WorkoutLogServiceProtocol, @unchecked Sendable {
    static let shared = SupabaseWorkoutLogService()

    private let supabase = SupabaseDatabase.shared
    private let local = WorkoutLogService.shared
    private let workingWeight = WorkingWeightService.shared
    private let logger = LoggingService.shared

    private init() {}

    // MARK: - saveLog

    func saveLog(_ log: WorkoutLog) async throws {
        do {
            _ = try await supabase.upsert(log, into: "workout_logs")
        } catch SupabaseDatabaseError.notAuthenticated {
            try await local.saveLog(log)
            return
        }

        // --- Side-effects: identical chain to WorkoutLogService.saveLog() ---

        try await workingWeight.updateFromLog(log, userId: log.userId)

        // User profile drives progression/cut mode + skill tree recompute.
        // Pull from Supabase if signed in, otherwise local.
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

        logger.log("Workout logged (Supabase): \(log.plannedWorkoutName)", level: .info, context: ["dayNumber": log.dayNumber])
    }

    // MARK: - updateLog

    func updateLog(_ log: WorkoutLog) async throws {
        do {
            _ = try await supabase.upsert(log, into: "workout_logs")
        } catch SupabaseDatabaseError.notAuthenticated {
            try await local.updateLog(log)
        }
    }

    // MARK: - fetchLogs

    func fetchLogs(userId: String, programId: String?) async throws -> [WorkoutLog] {
        do {
            let logs: [WorkoutLog] = try await supabase.query(
                from: "workout_logs",
                whereColumn: "user_id",
                equals: userId,
                orderBy: "started_at",
                ascending: false,
                limit: nil
            )
            if let programId {
                return logs.filter { $0.programId == programId }
            }
            return logs
        } catch SupabaseDatabaseError.notAuthenticated {
            return try await local.fetchLogs(userId: userId, programId: programId)
        }
    }

    // MARK: - fetchRecentLogs

    func fetchRecentLogs(userId: String, limit: Int) async throws -> [WorkoutLog] {
        do {
            return try await supabase.query(
                from: "workout_logs",
                whereColumn: "user_id",
                equals: userId,
                orderBy: "started_at",
                ascending: false,
                limit: limit
            )
        } catch SupabaseDatabaseError.notAuthenticated {
            return try await local.fetchRecentLogs(userId: userId, limit: limit)
        }
    }

    // MARK: - deleteLog

    func deleteLog(id: String) async throws {
        do {
            try await supabase.delete(from: "workout_logs", keyedBy: "id", equals: id)
        } catch SupabaseDatabaseError.notAuthenticated {
            try await local.deleteLog(id: id)
        }
    }

    // MARK: - Helpers

    /// Load the user profile, preferring Supabase but falling back to the
    /// local DatabaseService cache. Returns nil if neither store has it.
    private func loadProfile(userId: String) async -> UserProfile? {
        do {
            if let p: UserProfile = try await supabase.fetchOne(
                from: "users",
                keyedBy: "id",
                equals: userId
            ) {
                return p
            }
        } catch {
            // fall through to local
        }
        return try? await DatabaseService.shared.read(collection: "users", documentId: userId)
    }
}
