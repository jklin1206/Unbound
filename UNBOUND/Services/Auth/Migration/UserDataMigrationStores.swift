import Foundation

struct ProductionUserDataMigrationLocalStore: UserDataMigrationLocalStoring {
    private let local: any DatabaseServiceProtocol
    private let synced: any DatabaseServiceProtocol

    init(
        local: any DatabaseServiceProtocol = DatabaseService.shared,
        synced: any DatabaseServiceProtocol = SyncedDatabase.shared
    ) {
        self.local = local
        self.synced = synced
    }

    func workoutLogs(userId: String) async throws -> [WorkoutLog] {
        try await local.query(
            collection: "workoutLogs",
            field: "userId",
            isEqualTo: userId,
            orderBy: "startedAt",
            descending: false,
            limit: nil
        )
    }

    func workoutLog(id: String) async throws -> WorkoutLog? {
        try? await local.read(collection: "workoutLogs", documentId: id)
    }

    func writeWorkoutLog(_ log: WorkoutLog, enqueueForSync: Bool) async throws {
        if enqueueForSync {
            try await synced.create(log, collection: "workoutLogs", documentId: log.id)
        } else {
            try await local.create(log, collection: "workoutLogs", documentId: log.id)
        }
    }

    func workingWeights(userId: String) async throws -> [WorkingWeight] {
        try await local.query(
            collection: "workingWeights",
            field: "userId",
            isEqualTo: userId,
            orderBy: nil,
            descending: false,
            limit: nil
        )
    }

    func workingWeight(id: String) async throws -> WorkingWeight? {
        try? await local.read(collection: "workingWeights", documentId: id)
    }

    func writeWorkingWeight(_ weight: WorkingWeight) async throws {
        try await synced.create(weight, collection: "workingWeights", documentId: weight.id)
    }

    func skillProgress(userId: String) async throws -> UserSkillProgress? {
        try? await local.read(collection: "skillProgress", documentId: userId)
    }

    func writeSkillProgress(_ progress: UserSkillProgress) async throws {
        try await synced.create(progress, collection: "skillProgress", documentId: progress.userId)
    }
}

struct SupabaseUserDataMigrationRemoteStore: UserDataMigrationRemoteWriting {
    private let supabase: SupabaseDatabase

    init(supabase: SupabaseDatabase = .shared) {
        self.supabase = supabase
    }

    func canWrite(as userId: String) async -> Bool {
        guard let current = await UnboundSupabase.currentUserId else { return false }
        return current.caseInsensitiveCompare(userId) == .orderedSame
    }

    func upsertWorkingWeight(_ weight: WorkingWeight) async throws {
        let row = WorkingWeightMigrationRow(weight)
        let _: WorkingWeightMigrationRow = try await supabase.upsert(
            row,
            into: "working_weights",
            onConflict: "user_id,exercise_name"
        )
    }

    func upsertSkillProgress(_ progress: UserSkillProgress) async throws {
        let _: UserSkillProgress = try await supabase.upsert(
            progress,
            into: "skill_progress",
            onConflict: "user_id"
        )
    }
}

private struct WorkingWeightMigrationRow: Codable, Sendable {
    let userId: String
    let exerciseName: String
    let weightKg: Double
    let lastReps: Int
    let lastRPE: Int?
    let updatedAt: Date
    let sourceLogId: String
    let consecutiveSessionsAtTarget: Int

    init(_ weight: WorkingWeight) {
        self.userId = weight.userId
        self.exerciseName = weight.exerciseName
        self.weightKg = weight.weightKg
        self.lastReps = weight.lastReps
        self.lastRPE = weight.lastRPE
        self.updatedAt = weight.updatedAt
        self.sourceLogId = weight.sourceLogId
        self.consecutiveSessionsAtTarget = weight.consecutiveSessionsAtTarget
    }
}
