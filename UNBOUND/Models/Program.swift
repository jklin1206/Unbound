import Foundation

struct TrainingProgram: Codable, Identifiable {
    let id: String
    let scanId: String
    let analysisId: String
    let userId: String
    let createdAt: Date
    var name: String
    var description: String
    var durationDays: Int = 14   // Locked by program redesign 2026-04-20: blocks are 14 days.
    var days: [ProgramDay]
    var nutritionPlan: NutritionPlan
    var recoveryPlan: RecoveryPlan
    var difficultyLevel: DifficultyLevel
    var requiredEquipment: [String]
    var estimatedDailyMinutes: Int
    var rationale: ProgramRationale?
}

enum DifficultyLevel: String, Codable {
    case beginner, intermediate, advanced
}

struct ProgramDay: Codable, Identifiable, Hashable {
    let id: String
    let dayNumber: Int
    var label: String
    var isRestDay: Bool
    var workout: Workout?
    var nutritionOverride: DayNutrition?
    var recoveryActivities: [RecoveryActivity]
}
