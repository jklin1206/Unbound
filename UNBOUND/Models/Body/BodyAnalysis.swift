import Foundation

// Scan is a visual record of progress — not a verdict.
// The old `archetypeMatchPercentage` was removed because a numeric % match
// reads as judgment and is arbitrary. Internally the LLM may hint at drift,
// but nothing user-facing surfaces a percentage.
struct BodyAnalysis: Codable, Identifiable {
    let id: String
    let scanId: String
    let userId: String
    let createdAt: Date
    /// Snapshot of the user's BuildIdentity.displayName at scan time.
    var buildIdentitySnapshot: String?
    var overallScore: Int
    var proportions: ProportionData
    var estimatedBodyFatPercentage: Double?
    var focusAreas: [FocusArea]
    var summary: String
    var strengths: [String]
    var weaknesses: [String]
}

struct ProportionData: Codable {
    var shoulderToWaistRatio: Double?
    var chestToWaistRatio: Double?
    var armToForearmRatio: Double?
    var upperToLowerBodyBalance: Double?
    var leftRightSymmetry: Double?
    var overallProportionScore: Int
}

struct FocusArea: Codable, Equatable {
    let muscleGroup: MuscleGroup
    let priority: Int
    let rationale: String
    let suggestedFocus: String
}
