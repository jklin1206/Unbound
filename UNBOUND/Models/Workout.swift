import Foundation

struct Workout: Codable, Hashable {
    var name: String
    var targetMuscleGroups: [MuscleGroup]
    var warmup: [Exercise]
    var mainExercises: [Exercise]
    var cooldown: [Exercise]
    var estimatedMinutes: Int
    var notes: String?
    var blockType: BlockType?
}

struct Exercise: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var muscleGroups: [MuscleGroup]
    var sets: Int
    var reps: String
    var restSeconds: Int
    var rpe: Int?
    var notes: String?
    var substitution: String?
}
