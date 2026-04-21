import Foundation

struct WorkoutLog: Codable, Identifiable {
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

struct ExerciseLogEntry: Codable, Identifiable {
    let id: String
    var exerciseName: String
    var plannedSets: Int
    var plannedReps: String
    var sets: [SetLog]
    var skipped: Bool
    var notes: String?
}

struct SetLog: Codable, Identifiable {
    let id: String
    var setNumber: Int
    var weightKg: Double?
    var reps: Int
    var rpe: Int?
    var isWarmup: Bool
}
