import Foundation

/// The single end-of-week challenge attached to a trial card.
struct TrialCapstone: Codable, Equatable, Sendable {
    let displayName: String     // "Top-Set Benchmark"
    let description: String     // Full instruction shown on the attempt screen
    let evaluation: CapstoneEvaluation
}

/// How a capstone is verified.
enum CapstoneEvaluation: Codable, Equatable, Sendable {
    /// Auto-detected from log via TierCriterionEvaluator.
    case autoFromLog(TierCriterion)
    /// In-app countdown timer. User starts in-app; CapstoneLiveTimerView
    /// fires completeCapstone on natural finish.
    case liveTimer(seconds: Int, exerciseName: String)
    /// "Mark complete" button. Trust-based.
    case manualClaim
}
