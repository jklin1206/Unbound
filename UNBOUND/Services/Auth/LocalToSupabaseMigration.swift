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
//   5. Legacy files stay on disk for one session as a backup, then are purged
//      on next app launch (handled by a stale-legacy cleanup in app delegate)
//
// The `users` collection is special: the legacy UserProfile.id IS the old
// UUID. We create a NEW UserProfile with the Supabase UID and copy all
// onboarding fields across.

enum LocalToSupabaseMigration {

    static func migrate(from legacyUserId: String, to supabaseUserId: String) async {
        let logger = LoggingService.shared
        logger.log(
            "Starting local→cloud migration",
            level: .info,
            context: ["from": legacyUserId, "to": supabaseUserId]
        )

        // User profile: copy legacy profile → new profile keyed by Supabase UID
        await migrateUserProfile(from: legacyUserId, to: supabaseUserId, logger: logger)

        // TODO(P2a.2-followup): migrate workoutLogs, workingWeights, skillProgress,
        // programs, scans. Each has a different shape so we handle them one by
        // one once the corresponding cloud-write service lands.

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
            preferredArchetype: legacy.preferredArchetype,
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
