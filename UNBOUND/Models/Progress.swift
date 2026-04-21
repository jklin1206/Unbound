import Foundation

struct ProgressEntry: Codable, Identifiable {
    let id: String
    let userId: String
    let scanId: String
    let analysisId: String
    let createdAt: Date
    var overallScore: Int
    var muscleScores: [String: Int]
    var bodyFatEstimate: Double?
    var weightKg: Double?
    var notes: String?
}
