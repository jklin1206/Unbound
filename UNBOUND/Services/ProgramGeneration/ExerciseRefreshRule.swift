import Foundation

/// Rotates exercises that have been prescribed for too many consecutive
/// blocks without fresh stimulus (tier unlock or plateau-triggered deload).
///
/// Research-grounded cadence: evidence-based coaching rotates exercises
/// every ~4–6 weeks. Our block = 2 weeks, so 3 blocks = ~6 weeks.
enum ExerciseRefreshRule {

    struct ExerciseHistory: Equatable {
        let exerciseKey: String
        let consecutiveBlocksPrescribed: Int
        let hadTierUnlock: Bool
        let hadPlateauDeload: Bool
    }

    /// Rotate when an exercise has been prescribed for 3+ consecutive blocks
    /// AND has not unlocked a tier AND has not been plateau-deloaded.
    /// Tier unlocks and plateau deloads count as "fresh stimulus" — they
    /// reset the rotation counter implicitly.
    static func shouldRotate(history: ExerciseHistory) -> Bool {
        if history.hadTierUnlock || history.hadPlateauDeload { return false }
        return history.consecutiveBlocksPrescribed >= 3
    }

}
