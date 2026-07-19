import Foundation

/// Single source for the auto-deload lifecycle constants. Both the trigger
/// (AutoDeloadService), the exit (ProgressionEngine), and the detection window
/// (PlateauDetector) read these so the numbers can't drift apart.
enum DeloadPolicy {
    /// Deload sessions an exercise trains before returning to accumulation. A
    /// deload here is a brief recovery response, not a training block: two
    /// reduced exposures dissipate accumulated fatigue while keeping the athlete
    /// moving. One session is too little to register recovery; more wastes
    /// training time for an automatically fired micro-deload.
    static let sessionsInDeload = 2

    /// Appearances in the recent workout log before an exercise can be judged
    /// plateaued at all.
    static let plateauAppearanceWindow = 3

    /// Normal sessions after a deload exit during which the exercise is immune
    /// from re-plateau detection. Anchored to `plateauAppearanceWindow` so a
    /// full fresh observation window must pass on post-recovery evidence before
    /// another deload can fire, which stops an exit -> instant-replateau thrash.
    static let postDeloadCooldownSessions = plateauAppearanceWindow

    /// Distinct freshly-plateaued exercises required before an auto-deload
    /// fires. A lone stall is a PlateauFix case; a systemic deload waits for
    /// broader fatigue across the program.
    static let systemicPlateauThreshold = 2
}

@MainActor
final class DeloadPlanner {
    static let shared = DeloadPlanner()
    private init() {}

    func shouldDeload(plateauCount: Int) -> Bool {
        plateauCount >= DeloadPolicy.systemicPlateauThreshold
    }

    func planDeload(for states: [ProgressionState]) -> [ProgressionState] {
        states.map { state in
            var next = state
            next.blockType = .deload
            next.weekInBlock = 1
            next.targetRPE = BlockType.deload.targetRPE
            let deloadRange = state.classification.defaultRepRange(for: .deload)
            next.targetRepMin = deloadRange.lowerBound
            next.targetRepMax = deloadRange.upperBound
            next.consecutiveSessionsAtTarget = 0
            // Start the bounded deload counter fresh; entering a deload also
            // cancels any lingering post-deload cooldown from a prior cycle.
            next.deloadSessionsCompleted = 0
            next.deloadCooldownRemaining = nil
            next.updatedAt = Date()
            return next
        }
    }
}
