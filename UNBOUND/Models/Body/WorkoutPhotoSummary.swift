import Foundation

// MARK: - WorkoutPhotoSummary
//
// Compact, denormalized snapshot of the workout a progress photo was taken
// after. Stored directly on `ProgressPhoto` so the photo gallery can show
// "the workout you did" without fetching or joining the original session
// record — and so the snapshot survives the source workout being edited or
// deleted (the photo is a moment-in-time record). Local-only, like the photo.

struct WorkoutPhotoSummary: Codable, Equatable, Hashable, Sendable {
    var title: String
    var completedAt: Date
    var durationMinutes: Int?
    /// Compact "what you did" lines, e.g. "Bench Press · 3×5". Weight is left
    /// out on purpose so the line is unit-agnostic (no kg/lb).
    var exercises: [String]

    init(title: String, completedAt: Date, durationMinutes: Int? = nil, exercises: [String]) {
        self.title = title
        self.completedAt = completedAt
        self.durationMinutes = durationMinutes
        self.exercises = exercises
    }
}

extension WorkoutPhotoSummary {
    /// Build a gallery snapshot from a completed `PerformanceLog`.
    init(performanceLog log: PerformanceLog) {
        let seconds = log.completedAt.timeIntervalSince(log.startedAt)
        let minutes = seconds > 0 ? max(1, Int((seconds / 60).rounded())) : nil

        var lines: [String] = []
        for block in log.blocks {
            var blockHadExercise = false
            for exercise in block.exercises {
                if let line = Self.line(for: exercise) {
                    lines.append(line)
                    blockHadExercise = true
                }
            }
            // Cardio (or any duration-only) block with no per-exercise rows.
            if !blockHadExercise, let duration = block.durationSeconds, duration > 0 {
                let mins = max(1, Int((Double(duration) / 60).rounded()))
                lines.append("\(block.title) · \(mins) min")
            }
        }

        self.init(
            title: log.title,
            completedAt: log.completedAt,
            durationMinutes: minutes,
            exercises: lines
        )
    }

    /// One compact line for an exercise, or nil when it was skipped or had only
    /// warmup sets (a warmup-only entry isn't part of "what you did").
    private static func line(for exercise: PerformanceExercise) -> String? {
        guard !exercise.skipped else { return nil }
        let sets = exercise.sets.filter { !$0.isWarmup }
        guard !sets.isEmpty else { return nil }

        let count = sets.count
        let reps = sets.compactMap(\.reps)
        if reps.count == count, let first = reps.first, reps.allSatisfy({ $0 == first }) {
            return "\(exercise.name) · \(count)×\(first)"
        }
        let holds = sets.compactMap(\.holdSeconds)
        if holds.count == count, let first = holds.first, holds.allSatisfy({ $0 == first }) {
            return "\(exercise.name) · \(count)×\(first)s"
        }
        // Cardio / duration-based sets carry time, not reps — total the minutes.
        let durations = sets.compactMap(\.durationSeconds)
        if durations.count == count {
            let minutes = max(1, Int((Double(durations.reduce(0, +)) / 60).rounded()))
            return "\(exercise.name) · \(minutes) min"
        }
        return "\(exercise.name) · \(count) \(count == 1 ? "set" : "sets")"
    }
}
