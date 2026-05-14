import Foundation

// MARK: - OnboardingBodyRatings
//
// Per-body-part scores from Gemini for the onboarding verdict screen.
// Separate from AestheticScores (used by recurring bi-weekly scans).
// Scored strictly: 1-10 integers where most untrained people land 3-6.

struct OnboardingBodyRatings: Codable, Sendable, Equatable {
    let shoulders: Int   // width, roundness, capping
    let chest: Int       // thickness, shape, pec visibility
    let arms: Int        // bicep/tricep size (front-facing)
    let core: Int        // midsection tightness, abs, waist
    let legs: Int        // quad/leg development
    let overall: Int     // holistic aesthetic
    let coachLine: String // one brutal honest sentence, ≤12 words
}
