import Foundation

/// Body Analysis is now strictly flavor copy generation.
/// The OLD grading pipeline (LLM-based scoring, gap analysis, proportion analysis)
/// is removed per the "AI never grades the body" rule.
@MainActor
protocol BodyAnalysisServiceProtocol {
    /// Returns one-line flavor copy for the user's earned Build Identity.
    /// Never references specific body parts. Never grades.
    /// Backed by Anthropic Haiku 4.5.
    func flavorCopy(for identity: BuildIdentity) async -> String
}
