import Foundation

// MARK: - AestheticScores
//
// Gemini's honest 1-10 ratings across five visible physique dimensions plus
// an overall aesthetic score. Scores are calibrated — 8+ is elite, 5-7 is
// solid, below 5 is early-stage. Never inflated.

struct AestheticScores: Codable, Sendable, Equatable {
    let leanness: Int      // visible body-fat level / conditioning
    let muscleMass: Int    // overall size and development
    let definition: Int    // cuts, separation, vascularity — "CUTS" in UI
    let proportions: Int   // v-taper, shoulder-to-waist ratio — "SHAPE" in UI
    let symmetry: Int      // left/right balance, overall visual harmony
    let overall: Int       // holistic aesthetic

    static let placeholder = AestheticScores(
        leanness: 5, muscleMass: 5, definition: 5,
        proportions: 5, symmetry: 5, overall: 5
    )
}

// MARK: - BodyScanAnalysis

struct BodyScanAnalysis: Codable, Identifiable, Sendable, Equatable {
    let id: String          // "{userId}:{photoId}"
    let userId: String
    let photoId: String

    /// Honest 1-10 aesthetic scores. nil on legacy documents or low-confidence reads.
    let scores: AestheticScores?

    /// 2-3 sentence coach-voice read. Hero copy on payoff screen.
    let narrative: String

    let focusArea: String?
    let confidence: Confidence
    let observations: [String]
    let createdAt: Date

    enum Confidence: String, Codable, Sendable {
        case high, medium, low
    }

    init(
        userId: String,
        photoId: String,
        scores: AestheticScores?,
        narrative: String,
        focusArea: String?,
        confidence: Confidence,
        observations: [String],
        createdAt: Date = Date()
    ) {
        self.id = "\(userId):\(photoId)"
        self.userId = userId
        self.photoId = photoId
        self.scores = scores
        self.narrative = narrative
        self.focusArea = focusArea
        self.confidence = confidence
        self.observations = observations
        self.createdAt = createdAt
    }
}

/// Error surface for `BodyAnalysisService.analyzeScan`. Callers should
/// degrade gracefully (save the photo, award the daily +5 SP, do not
/// consume the 14-day scan window).
enum BodyAnalysisError: Error, Sendable {
    case unavailable        // API failure, parse error, rate limit, offline
    case consentRequired    // user hasn't accepted Gemini data policy yet
}
