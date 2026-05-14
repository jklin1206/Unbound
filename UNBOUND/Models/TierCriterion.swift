import Foundation

/// Typed criterion for a single tier on a single skill. Supports per-skill
/// bespoke shapes — reps, seconds, weight, bw ratio, variant, or compound
/// (AND across multiple). Evaluation lives in TierCriterionEvaluator.
///
/// Exercise-name lookups MUST use space-lowercase (e.g. "pull-up"),
/// matching CatalogExercise.name. See feedback_unbound_dual_exercise_catalogs.
indirect enum TierCriterion: Codable, Hashable, Sendable {
    /// Best single-set rep count for `exerciseName` ≥ n.
    case reps(Int, exerciseName: String)
    /// Best held duration in seconds ≥ t.
    case seconds(Int)
    /// Best working-set absolute weight in kg ≥ w.
    case weightKg(Double)
    /// Best working-set weight ÷ bodyweightKg ≥ r.
    case bodyweightRatio(Double)
    /// Any logged set with exerciseName matching this variant (case-insensitive).
    case variant(String)
    /// All sub-criteria must pass.
    case compound([TierCriterion])
}
