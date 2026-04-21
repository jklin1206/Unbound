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

    /// Find a same-pattern alternative in a catalog pool.
    ///
    /// Preference order:
    /// 1. Another exercise in the same `progressionFamily` with different name
    /// 2. Any exercise with identical `muscleGroups` and different name
    /// 3. nil if no suitable alternative exists
    static func alternative(
        for entry: CatalogExercise,
        in pool: [CatalogExercise]
    ) -> CatalogExercise? {
        if let family = entry.progressionFamily {
            if let sibling = pool.first(where: {
                $0.progressionFamily == family && $0.name != entry.name
            }) {
                return sibling
            }
        }
        return pool.first(where: {
            $0.muscleGroups == entry.muscleGroups && $0.name != entry.name
        })
    }
}
