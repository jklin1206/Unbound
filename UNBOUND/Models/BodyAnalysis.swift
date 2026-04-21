import Foundation

// Scan is a visual record of progress toward the user's chosen archetype —
// not a verdict. The old `archetypeMatchPercentage` was removed because a
// numeric % match reads as judgment and is arbitrary; the user's chosen
// archetype is what matters. Internally the LLM may still hint at drift, but
// nothing user-facing surfaces a percentage.
struct BodyAnalysis: Codable, Identifiable {
    let id: String
    let scanId: String
    let userId: String
    let createdAt: Date
    let targetArchetype: Archetype
    var overallScore: Int
    var muscleAssessments: [MuscleGroupAssessment]
    var proportions: ProportionData
    var estimatedBodyFatPercentage: Double?
    var estimatedMuscleMassCategory: MuscleMassCategory
    var focusAreas: [FocusArea]
    var summary: String
    var strengths: [String]
    var weaknesses: [String]
}

struct MuscleGroupAssessment: Codable {
    let muscleGroup: MuscleGroup
    var currentScore: Int
    var targetScore: Int
    var gap: Int
    var assessment: String
    var recommendation: String
}

struct ProportionData: Codable {
    var shoulderToWaistRatio: Double?
    var chestToWaistRatio: Double?
    var armToForearmRatio: Double?
    var upperToLowerBodyBalance: Double?
    var leftRightSymmetry: Double?
    var overallProportionScore: Int
}

enum MuscleMassCategory: String, Codable {
    case low, belowAverage, average, aboveAverage, high
}

struct FocusArea: Codable {
    let muscleGroup: MuscleGroup
    let priority: Int
    let rationale: String
    let suggestedFocus: String
}
