import Foundation

// MARK: - LoadBiasApplier
//
// Applies a validated Checkpoint `loadAdjustmentBias` (∈ -1...1) to the next
// Arc's prescriptions. Before this, the bias only changed rationale *copy*
// (loadRaised / loadLowered) — the actual sets/reps/RPE were copied verbatim,
// so a "recovery" Checkpoint produced an identical next Arc.
//
// A recovery bias (negative) deloads main-exercise volume + lowers target RPE;
// a push bias (positive) raises both. Warmups/cooldowns are untouched. Biases
// within the neutral band are a no-op, matching the rationale threshold.

enum LoadBiasApplier {
    /// |bias| at or below this is treated as neutral (matches ArcGenerator's
    /// loadRaised/loadLowered rationale threshold).
    static let neutralThreshold = 0.05
    /// How strongly bias maps to a volume factor. bias ±1 → ±25% before clamp.
    static let sensitivity = 0.25
    static let factorRange: ClosedRange<Double> = 0.7...1.2

    static func volumeFactor(for bias: Double) -> Double {
        min(max(1.0 + bias * sensitivity, factorRange.lowerBound), factorRange.upperBound)
    }

    /// Scale a workout's main exercises by the bias. Directional rounding keeps
    /// the change monotone (recovery never rounds back up to the original, push
    /// never rounds back down) so a meaningful bias is never silently dropped.
    static func apply(to workout: Workout, bias: Double) -> Workout {
        guard abs(bias) > neutralThreshold else { return workout }
        var out = workout
        out.mainExercises = workout.mainExercises.map { scale($0, bias: bias) }
        return out
    }

    private static func scale(_ exercise: Exercise, bias: Double) -> Exercise {
        var out = exercise
        let factor = volumeFactor(for: bias)
        let scaled = Double(exercise.sets) * factor
        if bias < 0 {
            out.sets = max(1, Int(scaled.rounded(.down)))
            if let rpe = exercise.rpe { out.rpe = max(5, rpe - 1) }
        } else {
            out.sets = max(exercise.sets, Int(scaled.rounded(.up)))
            if let rpe = exercise.rpe { out.rpe = min(10, rpe + 1) }
        }
        return out
    }
}
