import Foundation

struct ScanSession: Codable, Identifiable {
    let id: String
    let userId: String
    let createdAt: Date
    var targetArchetype: Archetype
    var photos: [ScanPhoto]
    var analysisId: String?
    var programId: String?
    var status: ScanStatus
    var heightCm: Double?
    var weightKg: Double?
    var trainingExperience: TrainingExperience?
}

enum ScanStatus: String, Codable {
    case photosCapturing
    case photosCaptured
    case uploading
    case analyzing
    case analyzed
    case programGenerating
    case complete
    case failed
}

enum TrainingExperience: String, Codable {
    case beginner
    case intermediate
    case advanced
}

struct ScanPhoto: Codable {
    let angle: ScanAngle
    let storageUrl: String
    let capturedAt: Date
}
