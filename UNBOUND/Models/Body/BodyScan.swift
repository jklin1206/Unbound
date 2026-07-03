import Foundation

struct ScanSession: Codable, Identifiable {
    let id: String
    let userId: String
    let createdAt: Date
    var analysisId: String?
    var programId: String?
    var status: ScanStatus
    var heightCm: Double?
    var weightKg: Double?
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
