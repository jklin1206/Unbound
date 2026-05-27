import Foundation

/// The proof attached to a Weekly Vow.
struct WeeklyVowProof: Codable, Equatable, Sendable {
    let displayName: String
    let description: String
    let evaluation: WeeklyVowProofEvaluation
}

/// How a Binding Vow standard is verified.
enum WeeklyVowProofEvaluation: Codable, Equatable, Sendable {
    /// Auto-detected from log via TierCriterionEvaluator.
    case autoFromLog(TierCriterion)
    /// In-app countdown timer. User starts in-app; the live timer fires
    /// completion on natural finish.
    case liveTimer(seconds: Int, exerciseName: String)
    /// "Mark complete" button. Trust-based.
    case manualClaim
}

typealias TrialCapstone = WeeklyVowProof
typealias CapstoneEvaluation = WeeklyVowProofEvaluation
