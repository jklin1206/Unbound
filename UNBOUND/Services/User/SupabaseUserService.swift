import Foundation
import Supabase

// MARK: - SupabaseUserService
//
// Supabase-backed implementation of UserServiceProtocol. Wraps SupabaseDatabase
// and replaces the local-JSON UserService at the ServiceContainer level.
//
// Falls back to the local UserService when the user isn't yet signed into
// Supabase (dev mode runs on local UUIDs). The fallback short-circuits on
// SupabaseDatabaseError.notAuthenticated — every other failure surfaces.
//
// Snake_case mapping happens in two layers:
//   1. UserProfile / TrainingProgram / WorkoutLog encoded by the snake_case
//      encoder configured on UnboundSupabase.client.
//   2. Loose [String: Any] field dicts (from OnboardingFlowViewModel) are
//      remapped explicitly here via `mapFieldsToSnakeCase`, then converted
//      to [String: AnyJSON] for the Postgrest patch.

final class SupabaseUserService: UserServiceProtocol, @unchecked Sendable {
    static let shared = SupabaseUserService()

    private let supabase = SupabaseDatabase.shared
    private let local = UserService.shared
    private let logger = LoggingService.shared

    private init() {}

    // MARK: - createUserIfNeeded

    func createUserIfNeeded(userId: String, email: String?) async throws -> UserProfile {
        #if DEBUG
        if Self.isLocalDebugUser(userId) {
            return try await local.createUserIfNeeded(userId: userId, email: email)
        }
        #endif

        do {
            if let existing: UserProfile = try await supabase.fetchOne(
                from: "users",
                keyedBy: "id",
                equals: userId
            ) {
                return existing
            }
            let newUser = UserProfile(
                id: userId,
                email: email,
                displayName: nil,
                createdAt: Date(),
                onboardingCompleted: false,
                totalScans: 0
            )
            let stored: UserProfile = try await supabase.upsert(newUser, into: "users")
            logger.log("Supabase user profile created", level: .info, context: ["userId": userId])
            return stored
        } catch SupabaseDatabaseError.notAuthenticated {
            return try await local.createUserIfNeeded(userId: userId, email: email)
        }
    }

    // MARK: - fetchProfile

    func fetchProfile(userId: String) async throws -> UserProfile {
        #if DEBUG
        if Self.isLocalDebugUser(userId) {
            return try await local.fetchProfile(userId: userId)
        }
        #endif

        do {
            guard let profile: UserProfile = try await supabase.fetchOne(
                from: "users",
                keyedBy: "id",
                equals: userId
            ) else {
                // Row doesn't exist on Supabase yet — fall back to local store.
                return try await local.fetchProfile(userId: userId)
            }
            return profile
        } catch SupabaseDatabaseError.notAuthenticated {
            return try await local.fetchProfile(userId: userId)
        }
    }

    // MARK: - updateProfile

    func updateProfile(userId: String, fields: [String: Any]) async throws {
        #if DEBUG
        if Self.isLocalDebugUser(userId) {
            try await local.updateProfile(userId: userId, fields: fields)
            return
        }
        #endif

        do {
            let snakeFields = Self.mapFieldsToSnakeCase(fields)
            // Drop any key that is not a real `public.users` column BEFORE the
            // PostgREST patch — one unknown column (e.g. seededAttributes /
            // pactSignature, which persist locally but were never migrated to a
            // column) makes Postgres reject the ENTIRE patch with 400
            // undefined_column, wiping the whole profile write. The local
            // fallback path below keeps `fields` intact (the JSON store merges
            // arbitrary keys), so nothing is lost off-cloud.
            let columnSafe = Self.columnSafeFields(snakeFields)
            let payload = Self.toAnyJSON(columnSafe)
            try await supabase.patch(
                payload,
                in: "users",
                keyedBy: "id",
                equals: userId
            )
        } catch SupabaseDatabaseError.notAuthenticated {
            try await local.updateProfile(userId: userId, fields: fields)
        }
    }

    // MARK: - deleteUserData

    func deleteUserData(userId: String) async throws {
        #if DEBUG
        if Self.isLocalDebugUser(userId) {
            try await local.deleteUserData(userId: userId)
            return
        }
        #endif

        do {
            // Foreign-key cascades on programs / workout_logs / scans /
            // analyses / progress drop child rows automatically.
            try await supabase.delete(from: "users", keyedBy: "id", equals: userId)

            // Storage objects live outside Postgres — delete them explicitly.
            try await StorageService.shared.deleteUserPhotos(userId: userId)
            logger.log("Supabase user data deleted", level: .info, context: ["userId": userId])
        } catch SupabaseDatabaseError.notAuthenticated {
            try await local.deleteUserData(userId: userId)
        }
    }

    // MARK: - Field key mapping
    //
    // OnboardingFlowViewModel emits payload dicts with camelCase keys
    // (legacy Firestore convention). Postgres columns are snake_case.
    // Map every onboarding field that needs explicit conversion; pass-through
    // for fields where camelCase happens to equal snake_case (single-word
    // fields like "age", "gender", "goals", "equipment", etc.).

    private static let camelToSnake: [String: String] = [
        "onboardingCompleted":   "onboarding_completed",
        "displayHandle":         "display_handle",
        "displayName":           "display_name",
        "currentProgramId":      "current_program_id",
        "heightCm":              "height_cm",
        "weightKg":              "weight_kg",
        "biologicalSex":         "biological_sex",
        "dietQuality":           "diet_quality",
        "sleepQuality":          "sleep_quality",
        "stressLevel":           "stress_level",
        "targetFrequency":       "target_frequency",
        "currentFrequency":      "current_frequency",
        "workoutTime":           "workout_time",
        "workoutMinuteOfDay":    "workout_minute_of_day",
        "sessionLength":         "session_length",
        "exerciseStyles":        "exercise_styles",
        "targetAreas":           "target_areas",
        "priorAttempts":         "prior_attempts",
        "trainingFeedbackMode":  "training_feedback_mode",
        "trainingDays":          "training_days",
        "trainingStyleOverride": "training_style_override",
        "totalScans":            "total_scans",
        "createdAt":             "created_at",
        "updatedAt":             "updated_at",
        "currentBodyType":       "current_body_type",
        "cutMode":               "cut_mode"
    ]

    #if DEBUG
    private static func isLocalDebugUser(_ userId: String) -> Bool {
        userId == "dev-player" || userId.hasPrefix("dev-player-")
    }
    #endif

    static func mapFieldsToSnakeCase(_ fields: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (k, v) in fields {
            out[camelToSnake[k] ?? k] = v
        }
        return out
    }

    // MARK: - Column safety
    //
    // Every real `public.users` column a client patch may target (snake_case,
    // matching the schema + later migrations). `updateProfile` takes a loose
    // [String: Any] whose keys come from onboarding / settings dicts; a key
    // that is NOT a real column (seededAttributes, pactSignature) makes
    // PostgREST 400 the whole patch. Filter against this set so only real
    // columns reach the remote patch. Keep this list in sync with the users
    // columns in supabase/migrations when a new column is added.

    private static let writableUserColumns: Set<String> = [
        "id", "email", "display_name", "display_handle", "created_at", "updated_at",
        "onboarding_completed", "total_scans", "current_program_id", "preferred_archetype",
        "height_cm", "weight_kg", "age", "biological_sex", "gender",
        "motivations", "goals", "target_areas", "obstacles", "experience",
        "current_frequency", "target_frequency", "workout_time", "workout_minute_of_day",
        "equipment", "exercise_styles", "session_length", "prior_attempts",
        "diet_quality", "sleep_quality", "stress_level", "commitment",
        "current_body_type", "training_feedback_mode", "training_style_override",
        "training_days", "cut_mode", "overall_rank_trials", "lift_tiers",
        "overall_level_backup", "streak_backup", "progress_snapshot",
        "rewards_backup", "achievements_backup", "is_pro", "is_pro_expires_at"
    ]

    /// Keep only keys naming a real `public.users` column; drop the rest so a
    /// stray field never 400s the whole patch. Expects already snake-cased keys
    /// (post `mapFieldsToSnakeCase`). Dropped keys are logged at debug level.
    static func columnSafeFields(_ snakeFields: [String: Any]) -> [String: Any] {
        var kept: [String: Any] = [:]
        var dropped: [String] = []
        for (k, v) in snakeFields {
            if writableUserColumns.contains(k) {
                kept[k] = v
            } else {
                dropped.append(k)
            }
        }
        if !dropped.isEmpty {
            LoggingService.shared.log(
                "Dropped unknown user columns from remote patch",
                level: .debug,
                context: ["keys": dropped.sorted()]
            )
        }
        return kept
    }

    // MARK: - AnyJSON conversion
    //
    // Postgrest's update() accepts any Encodable, but Foundation's
    // `[String: Any]` isn't Encodable. Walk the dict and box each value
    // into AnyJSON so the request serializes correctly.

    static func toAnyJSON(_ dict: [String: Any]) -> [String: AnyJSON] {
        var out: [String: AnyJSON] = [:]
        for (k, v) in dict {
            out[k] = anyJSON(from: v)
        }
        return out
    }

    private static func anyJSON(from value: Any) -> AnyJSON {
        switch value {
        case is NSNull:
            return .null
        case let v as Bool:
            return .bool(v)
        case let v as Int:
            return .integer(v)
        case let v as Int64:
            return .integer(Int(v))
        case let v as Double:
            return .double(v)
        case let v as Float:
            return .double(Double(v))
        case let v as String:
            return .string(v)
        case let v as Date:
            let formatter = ISO8601DateFormatter()
            return .string(formatter.string(from: v))
        case let v as [Any]:
            return .array(v.map(anyJSON(from:)))
        case let v as [String: Any]:
            var obj: [String: AnyJSON] = [:]
            for (k, vv) in v {
                obj[k] = anyJSON(from: vv)
            }
            return .object(obj)
        default:
            // Fallback: stringify the value rather than dropping it.
            return .string(String(describing: value))
        }
    }
}
