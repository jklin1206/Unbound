import Foundation

// MARK: - LocalToSupabaseMigration
//
// Re-keys a user's local JSON documents from their pre-auth anonymous UUID
// to their Supabase auth UID on first successful Sign in with Apple. Runs
// ONCE per user, in background, after auth succeeds.
//
// Strategy:
//   1. Read every document in each collection with `userId == legacyUID`
//   2. Rewrite the userId field to the new Supabase UID
//   3. Write back to the local store under the new UID (or new filename)
//   4. Upload to Supabase via SupabaseDatabase (best-effort; local is source of truth until verified)
//   5. Legacy user-keyed singleton docs stay on disk as a backup; per-record
//      docs are rewritten in place with the Supabase userId.
//
// The `users` collection is special: the legacy UserProfile.id IS the old
// UUID. We create a NEW UserProfile with the Supabase UID and copy all
// onboarding fields across.

enum LocalToSupabaseMigration {

    /// Number of attempts before giving up within a single session. A run that
    /// leaves any collection unmigrated does NOT persist the completion flag
    /// (see `UserDataMigrationCoordinator`), so it is retried here with backoff
    /// and, failing that, resumed on the next app launch.
    private static let maxAttempts = 3

    static func migrate(from legacyUserId: String, to supabaseUserId: String) async {
        let logger = LoggingService.shared
        logger.log(
            "Starting local→cloud migration",
            level: .info,
            context: ["from": legacyUserId, "to": supabaseUserId]
        )

        // User profile: copy legacy profile → new profile keyed by Supabase UID
        await migrateUserProfile(from: legacyUserId, to: supabaseUserId, logger: logger)

        let coordinator = UserDataMigrationCoordinator()
        var summary = UserDataMigrationSummary()

        // Awaited, bounded retry with exponential backoff. The coordinator is
        // idempotent (re-key overwrites in place; the completion flag
        // short-circuits a finished migration), so re-running is safe.
        for attempt in 1...maxAttempts {
            summary = await coordinator.migrate(
                legacyUserId: legacyUserId,
                supabaseUserId: supabaseUserId
            )
            if summary.allCollectionsSucceeded { break }

            if attempt < maxAttempts {
                let backoffNanos = UInt64(attempt) * 500_000_000 // 0.5s, 1.0s
                logger.log(
                    "Local→cloud migration incomplete; retrying",
                    level: .warning,
                    context: ["attempt": attempt, "from": legacyUserId, "to": supabaseUserId]
                )
                try? await Task.sleep(nanoseconds: backoffNanos)
            }
        }

        logger.log(
            "Local user data migration summary",
            level: .info,
            context: [
                "localWrites": summary.migratedLocally,
                "remoteDeferred": summary.remoteDeferred,
                "completed": summary.allCollectionsSucceeded,
                "workoutLogs": summary.workoutLogs,
                "workingWeights": summary.workingWeights,
                "skillProgress": summary.skillProgress,
                "scans": summary.scans
            ]
        )

        logger.log("Local→cloud migration finished", level: .info)
    }

    private static func migrateUserProfile(
        from legacyUserId: String,
        to supabaseUserId: String,
        logger: LoggingService
    ) async {
        let db = DatabaseService.shared
        guard let legacy: UserProfile = try? await db.read(
            collection: "users",
            documentId: legacyUserId
        ) else {
            logger.log("No legacy user profile to migrate", level: .info)
            return
        }

        // Build a new profile with the Supabase UID as primary key.
        var migrated = legacy
        migrated = UserProfile(
            id: supabaseUserId,
            email: legacy.email,
            displayName: legacy.displayName,
            createdAt: legacy.createdAt,
            onboardingCompleted: legacy.onboardingCompleted,
            totalScans: legacy.totalScans,
            currentProgramId: legacy.currentProgramId,
            heightCm: legacy.heightCm,
            weightKg: legacy.weightKg,
            age: legacy.age,
            biologicalSex: legacy.biologicalSex
        )
        migrated.displayHandle = legacy.displayHandle
        migrated.gender = legacy.gender
        migrated.motivations = legacy.motivations
        migrated.currentBodyType = legacy.currentBodyType
        migrated.experience = legacy.experience
        migrated.currentFrequency = legacy.currentFrequency
        migrated.targetFrequency = legacy.targetFrequency
        migrated.equipment = legacy.equipment
        migrated.obstacles = legacy.obstacles
        migrated.sessionLength = legacy.sessionLength
        migrated.priorAttempts = legacy.priorAttempts
        migrated.dietQuality = legacy.dietQuality
        migrated.sleepQuality = legacy.sleepQuality
        migrated.stressLevel = legacy.stressLevel
        migrated.commitment = legacy.commitment
        migrated.goals = legacy.goals
        migrated.targetAreas = legacy.targetAreas
        migrated.workoutTime = legacy.workoutTime
        migrated.exerciseStyles = legacy.exerciseStyles
        migrated.trainingFeedbackMode = legacy.trainingFeedbackMode
        migrated.trainingStyleOverride = legacy.trainingStyleOverride
        migrated.trainingDays = legacy.trainingDays
        migrated.cutMode = legacy.cutMode

        // Write locally under the new primary key.
        try? await db.create(migrated, collection: "users", documentId: supabaseUserId)
        logger.log("User profile re-keyed locally", level: .info)

        // Best-effort push to cloud. SupabaseDatabase enforces auth client-side
        // so this will only succeed after the auth session has landed.
        // If it throws we log and leave local as truth; a retry pass on next
        // app launch will sync.
        do {
            try await SupabaseDatabase.shared.upsert(migrated, into: "users")
            logger.log("User profile synced to Supabase", level: .info)
        } catch {
            logger.log("User profile cloud sync deferred: \(error)", level: .warning)
        }
    }
}
