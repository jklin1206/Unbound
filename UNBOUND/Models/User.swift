import Foundation

struct UserProfile: Codable, Identifiable {
    let id: String
    var email: String?
    var displayName: String?
    var createdAt: Date
    var onboardingCompleted: Bool
    var totalScans: Int
    var currentProgramId: String?
    var preferredArchetype: Archetype?
    var heightCm: Double?
    var weightKg: Double?
    var age: Int?
    var biologicalSex: BiologicalSex?

    // MARK: UNBOUND onboarding answers (all optional, additive to schema)
    var displayHandle: String?
    var gender: Gender?
    var motivations: [Motivation]?
    var currentBodyType: BodyType?
    var experience: Experience?
    var currentFrequency: Frequency?
    var targetFrequency: TargetFrequency?
    var equipment: [Equipment]?
    var obstacles: [Obstacle]?
    var sessionLength: SessionLength?
    var priorAttempts: [PriorAttempt]?
    var dietQuality: Int?
    var sleepQuality: Int?
    var stressLevel: Int?
    var commitment: Int?
    var goals: [Goal]?
    var targetAreas: [TargetArea]?
    var workoutTime: WorkoutTime?
    var exerciseStyles: [ExerciseStyle]?
}

enum BiologicalSex: String, Codable {
    case male, female
}
