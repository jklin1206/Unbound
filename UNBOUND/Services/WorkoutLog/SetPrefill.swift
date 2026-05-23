import Foundation

/// Per-set "previous" ghost shown above the steppers.
/// Priority: last session's matching set → last session's last set →
/// working weight (weight only) → nil.
enum SetPrefill {
    struct Ghost: Equatable { var weightKg: Double?; var reps: Int? }

    static func ghost(exerciseName: String,
                      setIndex: Int,
                      priorEntries: [ExerciseLogEntry],
                      workingWeightKg: Double?) -> Ghost? {
        let target = exerciseName.lowercased()
        if let last = priorEntries.last(where: { $0.exerciseName.lowercased() == target }),
           !last.sets.isEmpty {
            let set = last.sets.indices.contains(setIndex) ? last.sets[setIndex] : last.sets[last.sets.count - 1]
            return Ghost(weightKg: set.weightKg, reps: set.reps)
        }
        if let ww = workingWeightKg { return Ghost(weightKg: ww, reps: nil) }
        return nil
    }
}
