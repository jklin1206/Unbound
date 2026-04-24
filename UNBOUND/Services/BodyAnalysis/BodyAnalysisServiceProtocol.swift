import UIKit

protocol BodyAnalysisServiceProtocol: Sendable {
    /// Onboarding scan analysis — runs the deep multi-photo Gemini call that
    /// feeds Verdict. Unchanged from V1.
    func analyze(scanSession: ScanSession, photos: [ScanAngle: UIImage], userProfile: UserProfile) async throws -> BodyAnalysis

    /// Recurring bi-weekly scan analysis — qualitative coach-voice read of a
    /// single photo in the context of the user's recent training. Returns a
    /// narrow `BodyScanAnalysis`. Throws `BodyAnalysisError.unavailable` if
    /// Gemini can't be reached, the response can't be parsed, or any error
    /// falls through. Caller must degrade gracefully on throw.
    func analyzeScan(context: ScanContext, userId: String, photoId: String) async throws -> BodyScanAnalysis
}
