import Foundation

extension DeterministicProgramGenerator {
    static func warmupExercises(
        for template: DayTemplate,
        input: ProgramGeneratorInput
    ) -> [Exercise] {
        if Equipment.isFloorOnlySelection(Set(input.equipment)) {
            return floorOnlyWarmupExercises(for: template)
        }

        let isAdvancedStrength = input.experience == .current && input.trainingStyle != .bodyweight
        let base: [Exercise]

        switch template {
        case .push:
            base = [
                warmupExercise("Shoulder Opener", groups: [.shoulders, .chest, .back], reps: "45s"),
                warmupExercise("Incline Pushup", groups: [.chest, .shoulders, .arms, .core], reps: "8")
            ]
        case .pull:
            base = [
                warmupExercise("Shoulder Opener", groups: [.shoulders, .back], reps: "45s"),
                warmupExercise("Hollow Hold", groups: [.core], reps: "20s")
            ]
        case .legs, .lower:
            base = [
                warmupExercise("Hip Opener Flow", groups: [.legs, .glutes, .back, .core], reps: "45s"),
                warmupExercise("Bodyweight Squat", groups: [.legs, .glutes, .core], reps: "10")
            ]
        case .upper:
            base = [
                warmupExercise("Shoulder Opener", groups: [.shoulders, .chest, .back], reps: "45s"),
                warmupExercise("Hollow Hold", groups: [.core], reps: "20s")
            ]
        case .fullBody, .weakPoint:
            base = [
                warmupExercise("Hip Opener Flow", groups: [.legs, .glutes, .back, .core], reps: "45s"),
                warmupExercise("Incline Pushup", groups: [.chest, .shoulders, .arms, .core], reps: "8")
            ]
        case .skill:
            base = [
                warmupExercise("Wrist Prep", groups: [.forearms], reps: "45s"),
                warmupExercise("Hollow Hold", groups: [.core], reps: "20s")
            ]
        case .rest:
            base = []
        }

        guard isAdvancedStrength, let ramp = rampWarmupExercise(for: template) else {
            return base
        }
        return base + [ramp]
    }

    static func floorOnlyWarmupExercises(for template: DayTemplate) -> [Exercise] {
        switch template {
        case .legs, .lower:
            return [
                warmupExercise("Hip Opener Flow", groups: [.legs, .glutes, .back, .core], reps: "45s"),
                warmupExercise("Bodyweight Squat", groups: [.legs, .glutes, .core], reps: "10")
            ]
        case .push:
            return [
                warmupExercise("Wrist Prep", groups: [.forearms], reps: "45s"),
                warmupExercise("High Plank", groups: [.chest, .shoulders, .arms, .core], reps: "20s")
            ]
        case .pull, .upper:
            return [
                warmupExercise("Prone Shoulder Raise", groups: [.back, .shoulders], reps: "8"),
                warmupExercise("Hollow Hold", groups: [.core], reps: "20s")
            ]
        case .fullBody, .weakPoint:
            return [
                warmupExercise("Hip Opener Flow", groups: [.legs, .glutes, .back, .core], reps: "45s"),
                warmupExercise("Glute Bridge", groups: [.glutes, .legs, .core], reps: "10")
            ]
        case .skill:
            return [
                warmupExercise("Wrist Prep", groups: [.forearms], reps: "45s"),
                warmupExercise("Hollow Hold", groups: [.core], reps: "20s")
            ]
        case .rest:
            return []
        }
    }

    static func calibrationWarmup(
        input: ProgramGeneratorInput,
        planName: String
    ) -> [Exercise] {
        if planName.localizedCaseInsensitiveContains("lower")
            || planName.localizedCaseInsensitiveContains("legs") {
            return warmupExercises(for: .lower, input: input)
        }
        if planName.localizedCaseInsensitiveContains("pull") {
            return warmupExercises(for: .pull, input: input)
        }
        if planName.localizedCaseInsensitiveContains("upper") {
            return warmupExercises(for: .upper, input: input)
        }
        return warmupExercises(for: .fullBody, input: input)
    }

    static func cooldownExercises(for _: DayTemplate, blockType _: BlockType) -> [Exercise] {
        []
    }

    static func rampWarmupExercise(for template: DayTemplate) -> Exercise? {
        switch template {
        case .push, .upper:
            return warmupExercise("Pushup", groups: [.chest, .shoulders, .arms, .core], sets: 1, reps: "5", restSeconds: 45, notes: "Ramp set before loading.")
        case .pull:
            return warmupExercise("Inverted Row", groups: [.back, .lats, .arms], sets: 1, reps: "6", restSeconds: 45, notes: "Ramp set before loading.")
        case .legs, .lower, .fullBody, .weakPoint:
            return warmupExercise("Bodyweight Squat", groups: [.legs, .glutes, .core], sets: 1, reps: "6", restSeconds: 45, notes: "Ramp set before loading.")
        case .skill, .rest:
            return nil
        }
    }

    static func warmupExercise(
        _ name: String,
        groups: [MuscleGroup],
        sets: Int = 1,
        reps: String,
        restSeconds: Int = 0,
        notes: String? = "Prep work."
    ) -> Exercise {
        Exercise(
            id: UUID().uuidString,
            name: name,
            muscleGroups: groups,
            sets: sets,
            reps: reps,
            restSeconds: restSeconds,
            rpe: nil,
            notes: notes,
            substitution: nil
        )
    }

    static func estimatedWorkoutMinutes(
        warmup: [Exercise],
        main: [Exercise],
        cooldown: [Exercise]
    ) -> Int {
        let warmupSeconds = warmup.reduce(0) { $0 + estimatedSeconds(for: $1, defaultWorkSeconds: 30) }
        let mainSeconds = main.reduce(0) { $0 + estimatedSeconds(for: $1, defaultWorkSeconds: 40) }
        let cooldownSeconds = cooldown.reduce(0) { $0 + estimatedSeconds(for: $1, defaultWorkSeconds: 30) }
        let transitionSeconds = max(0, warmup.count + main.count + cooldown.count - 1) * 30
        return max(5, Int(ceil(Double(warmupSeconds + mainSeconds + cooldownSeconds + transitionSeconds) / 60.0)))
    }

    static func estimatedSeconds(for exercise: Exercise, defaultWorkSeconds: Int) -> Int {
        let workSeconds = durationSeconds(in: exercise.reps) ?? defaultWorkSeconds
        return max(1, exercise.sets) * (workSeconds + max(0, exercise.restSeconds))
    }

    static func durationSeconds(in reps: String) -> Int? {
        let lower = reps.lowercased()
        guard lower.contains("s") else { return nil }
        let digits = lower.prefix { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        return Int(String(digits))
    }

    static func isPrimaryExercise(_ exercise: Exercise) -> Bool {
        guard let definition = MovementCatalog.canonicalExercise(named: exercise.name) else {
            return false
        }
        return isPrimaryMovement(definition)
    }

    static func sessionBudgetMinutes(for input: ProgramGeneratorInput) -> Int {
        min(90, max(30, input.sessionLengthMinutes))
    }

    static func appendNote(_ note: String, to existing: String?) -> String {
        guard let existing, !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return note
        }
        if existing.localizedCaseInsensitiveContains(note) { return existing }
        return "\(existing) \(note)"
    }
}
