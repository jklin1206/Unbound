import Foundation

// MARK: - BodyScanAnalysis
//
// Gemini's output for a bi-weekly scan, persisted in the
// `body_scan_analyses` collection and linked back to the ProgressPhoto
// that produced it. Rendered in `ScanPayoffView`.
//
// Structure is tight on purpose — we asked Gemini for a narrow,
// structured JSON. Anything beyond these fields would be padding.

struct BodyScanAnalysis: Codable, Identifiable, Sendable, Equatable {
    /// "{userId}:{photoId}" for stable composite key.
    let id: String
    let userId: String
    let photoId: String

    /// 2-3 sentence coach-voice read of the photo, in UNBOUND's language.
    /// Rendered as the hero copy on the payoff screen.
    let narrative: String

    /// A single muscle group Gemini identified as the next-block priority,
    /// or nil if the image quality / context didn't support a confident
    /// call. Mirrors `MuscleHeatGroup.rawValue` where possible.
    let focusArea: String?

    /// How sure Gemini was. Low = retake-in-better-light suggested.
    let confidence: Confidence

    /// One or two concrete visible observations Gemini stands behind. We
    /// do NOT render these in the UI — they live for debug + audit + the
    /// coach's future context lookups.
    let observations: [String]

    let createdAt: Date

    enum Confidence: String, Codable, Sendable {
        case high, medium, low
    }

    init(
        userId: String,
        photoId: String,
        narrative: String,
        focusArea: String?,
        confidence: Confidence,
        observations: [String],
        createdAt: Date = Date()
    ) {
        self.id = "\(userId):\(photoId)"
        self.userId = userId
        self.photoId = photoId
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
