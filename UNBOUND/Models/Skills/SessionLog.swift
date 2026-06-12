import Foundation

// MARK: - SessionLog (persisted)

struct SessionLog: Codable, Identifiable {
    let id: String                  // UUID
    let userId: String
    let skillId: String             // the goal being trained
    var selectedRungId: String? = nil
    var selectedRungSource: SkillTrainingRungSource? = nil
    var selectedRungReason: String? = nil
    let createdAt: Date
    let durationSeconds: Int
    let exercises: [LoggedExercise]
    let xpAwarded: Int
}

struct LoggedExercise: Codable, Hashable {
    let name: String
    let sets: [LoggedSet]
}

struct LoggedSet: Codable, Hashable {
    let reps: Int                   // for reps/amrap/tempo
    let holdSeconds: Int?           // for hold-target sets
    let weightKg: Double?           // optional load
    let rpe: Int?                   // 1-10 perceived effort
    var qualityFlags: Set<PerformanceQualityFlag>? = nil
    var notes: String? = nil

    init(
        reps: Int,
        holdSeconds: Int?,
        weightKg: Double?,
        rpe: Int?,
        qualityFlags: Set<PerformanceQualityFlag> = [],
        notes: String? = nil
    ) {
        self.reps = reps
        self.holdSeconds = holdSeconds
        self.weightKg = weightKg
        self.rpe = rpe
        self.qualityFlags = qualityFlags.isEmpty ? nil : qualityFlags
        self.notes = notes
    }

    var effectiveQualityFlags: Set<PerformanceQualityFlag> {
        qualityFlags ?? []
    }
}
