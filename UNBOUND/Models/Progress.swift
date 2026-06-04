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

struct BodyWeightLog: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let userId: String
    var weightKg: Double
    var loggedAt: Date
    var note: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        weightKg: Double,
        loggedAt: Date = Date(),
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.weightKg = weightKg
        self.loggedAt = loggedAt
        self.note = note
        self.createdAt = createdAt
    }
}
