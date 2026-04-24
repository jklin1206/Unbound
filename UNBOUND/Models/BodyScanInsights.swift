import Foundation

/// On-device, deterministic body-shape insights derived from a single
/// front-facing scan photo via Apple's Vision framework. Intentionally
/// narrow: we only surface what we can *actually* measure — shoulder-hip
/// ratios, torso/leg proportions, crude posture flags. No body-fat %,
/// no muscle-mass score, no hallucinated vibes.
///
/// Used by onboarding to confirm or nudge the user's archetype pick and
/// tune priority focus areas. Stored on `OnboardingFlowViewModel` and
/// rendered as a single honest insight on the Verdict screen.
///
/// Not to be confused with `BodyAnalysis` (the LLM-powered deep analysis
/// produced by `BodyAnalysisService` — post-paywall premium feature).
struct BodyScanInsights: Codable, Equatable {
    /// Shoulder width / hip width. Classic V-taper anthropometric ratio.
    /// 1.6+ = strong V-taper. 1.3–1.6 = balanced. <1.3 = squared/broad-hip.
    let shoulderHipRatio: Double

    /// Torso length / leg length. Informs whether program emphasizes
    /// pulls (long torso) or squats/lunges (long legs) for visual balance.
    /// Roughly 0.6–0.8 is typical.
    let torsoLegRatio: Double

    /// Overall frame category derived from shoulder breadth relative to
    /// image height. Rough classification, not a medical statement.
    let frameCategory: FrameCategory

    /// Posture/symmetry tells detected from keypoints. Empty set is fine.
    let postureFlags: Set<PostureFlag>

    /// The archetype this scan's shape most resembles. Used to confirm
    /// the user's pick ("V-taper confirmed.") or suggest a nudge
    /// ("Your frame looks closer to HEAVYWEIGHT — want to swap?").
    let suggestedArchetypeRaw: String

    enum FrameCategory: String, Codable {
        case narrow     // ecto-leaning frame
        case balanced
        case broad      // endo/meso broad-shouldered frame
    }

    enum PostureFlag: String, Codable {
        case shoulderAsymmetry  // one shoulder noticeably higher than the other
        case uprightStance      // clean vertical alignment
    }

    /// One-line headline for the Verdict insight card. Honest phrasing —
    /// nothing we don't actually measure.
    var headline: String {
        switch shoulderHipRatio {
        case 1.5...:  return "Strong V-taper"
        case 1.3..<1.5: return "Balanced frame"
        default:      return "Squared frame"
        }
    }

    /// One-line explanation of how the scan tuned the program. Specific
    /// to the measurement, not generic encouragement.
    var programImpact: String {
        switch shoulderHipRatio {
        case 1.5...:
            return "Shoulders already lead your silhouette. We'll emphasize back thickness and legs to keep the proportion."
        case 1.3..<1.5:
            return "Symmetric starting point. Focus areas tuned to your archetype pick, not forced adjustments."
        default:
            return "Shoulders and back are the fastest lever for your frame. We've bumped those up in priority."
        }
    }
}
