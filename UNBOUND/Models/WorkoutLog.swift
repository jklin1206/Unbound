import Foundation

struct WorkoutLog: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let programId: String
    let dayNumber: Int
    let plannedWorkoutName: String
    var startedAt: Date
    var completedAt: Date?
    var exerciseEntries: [ExerciseLogEntry]
    var overallNotes: String?
    var overallRPE: Int?
    var durationMinutes: Int?
}

struct ExerciseLogEntry: Codable, Identifiable, Hashable {
    let id: String
    var exerciseName: String
    var movementId: String? = nil
    var rankStandardMovementId: String? = nil
    var plannedSets: Int
    var plannedReps: String
    var sets: [SetLog]
    var skipped: Bool
    var notes: String?
}

struct SetLog: Codable, Identifiable, Hashable {
    let id: String
    var setNumber: Int
    var weightKg: Double?
    var reps: Int
    var rpe: Int?
    var isWarmup: Bool
    /// Hold/carry duration in seconds. `nil` for rep-based sets. Pre-Foundation-2
    /// logs encoded hold seconds in `reps`; readers fall back to `reps` when this
    /// is nil so legacy holds still rank. (Optional + default keeps the
    /// memberwise init and existing call sites source-compatible; auto-Codable
    /// decodes a missing key as nil — no migration.)
    var durationSeconds: Int? = nil
}
