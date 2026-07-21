import Foundation

extension DeterministicProgramGenerator {
    static func restDayActivities() -> [RecoveryActivity] {
        [
            RecoveryActivity(
                id: UUID().uuidString,
                name: "Walk",
                description: "20-minute easy walk",
                durationMinutes: 20,
                frequency: "Rest days"
            ),
            RecoveryActivity(
                id: UUID().uuidString,
                name: "Mobility flow",
                description: "Hips + shoulders",
                durationMinutes: 10,
                frequency: "Rest days"
            )
        ]
    }

    static func labelFor(template: DayTemplate, bias: [MuscleGroup: Int]) -> String {
        // Only advertise a bias the day can actually express — a "Legs Bias"
        // tag on a push day is a placebo label. Deterministic tie-break so the
        // same inputs always produce the same label. Both sides are
        // modernized before matching so legacy persisted bias (`.arms`/
        // `.legs`) still lines up with the fine-grained template groups.
        let modernizedBias = Dictionary(
            bias.flatMap { key, value in key.modernized.map { ($0, value) } },
            uniquingKeysWith: max
        )
        let relevantGroups: Set<MuscleGroup> = template == .weakPoint
            ? Set(modernizedBias.keys)
            : Set(MuscleGroup.modernized(template.muscleGroups))
        let biggest = modernizedBias
            .filter { relevantGroups.contains($0.key) }
            .sorted { lhs, rhs in
                lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key.rawValue < rhs.key.rawValue
            }
            .first
        guard let biggest else { return template.displayLabel }
        return "\(template.displayLabel) + \(biggest.key.displayName) Bias"
    }

    static func sessionRole(for template: DayTemplate, workout: Workout) -> SessionRole {
        switch template {
        case .push:
            return .push
        case .pull:
            return .pull
        case .legs:
            return .legs
        case .upper:
            return .upper
        case .lower:
            return .lower
        case .fullBody, .weakPoint:
            return inferredSessionRole(from: workout)
        case .skill:
            return .skillOnly
        case .rest:
            return .rest
        }
    }

    static func inferredSessionRole(from workout: Workout) -> SessionRole {
        let regions = workout.mainExercises
            .flatMap(\.muscleGroups)
            .map(ProgramBodyRegion.from(muscleGroup:))

        let hasPush = regions.contains(.push) || regions.contains(.shoulders)
        let hasPull = regions.contains(.pull)
        let hasLegs = regions.contains(.legs) || regions.contains(.posterior)
        let hasCore = regions.contains(.core)

        switch (hasPush, hasPull, hasLegs, hasCore) {
        case (true, true, true, _):
            return .fullBody
        case (true, true, false, _):
            return .upper
        case (false, false, true, true), (false, false, true, false):
            return .lower
        case (true, false, false, _):
            return .push
        case (false, true, false, _):
            return .pull
        default:
            return .custom(workout.name)
        }
    }

    static func difficultyLevel(for experience: Experience) -> DifficultyLevel {
        switch experience {
        case .never, .tried: return .beginner
        case .used: return .intermediate
        case .current: return .advanced
        }
    }

}
