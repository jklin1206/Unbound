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
        do {
            let snakeFields = Self.mapFieldsToSnakeCase(fields)
            let payload = Self.toAnyJSON(snakeFields)
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

    static func mapFieldsToSnakeCase(_ fields: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (k, v) in fields {
            out[camelToSnake[k] ?? k] = v
        }
        return out
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
