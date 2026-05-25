import Foundation

enum SessionRoleTagger {
    static func role(for day: ProgramDay) -> SessionRole {
        if day.isRestDay { return .rest }
        guard let workout = day.workout else { return .custom("unspecified") }
        return role(for: workout)
    }

    static func role(for workout: Workout) -> SessionRole {
        role(
            title: workout.name,
            muscleGroups: workout.targetMuscleGroups + workout.warmup.flatMap(\.muscleGroups) + workout.mainExercises.flatMap(\.muscleGroups)
        )
    }

    static func role(for draft: TrainingSessionDraft) -> SessionRole {
        role(
            title: draft.title,
            muscleGroups: draft.blocks.flatMap { block in
                block.prescriptions.flatMap(\.muscleGroups)
            }
        )
    }

    static func role(
        title: String,
        muscleGroups: [MuscleGroup],
        fallback: SessionRole = .custom("unspecified")
    ) -> SessionRole {
        let normalizedTitle = normalize(title)
        let titleMatches: [(needle: String, role: SessionRole)] = [
            ("full_body", .fullBody),
            ("fullbody", .fullBody),
            ("upper", .upper),
            ("lower", .lower),
            ("squat", .squatFocus),
            ("push", .push),
            ("pull", .pull),
            ("legs", .legs),
            ("leg", .legs),
            ("chest", .broChest),
            ("back", .broBack),
            ("shoulder", .broShoulders),
            ("arms", .broArms),
            ("cardio", .cardio),
            ("skill", .skillOnly)
        ]
        if let match = titleMatches.first(where: { normalizedTitle.contains($0.needle) }) {
            return match.role
        }

        let counts = Dictionary(grouping: muscleGroups, by: { $0 }).mapValues(\.count)
        let push = (counts[.chest] ?? 0) + (counts[.shoulders] ?? 0) + (counts[.arms] ?? 0)
        let pull = (counts[.back] ?? 0) + (counts[.lats] ?? 0) + (counts[.traps] ?? 0) + (counts[.forearms] ?? 0)
        let legs = (counts[.legs] ?? 0) + (counts[.glutes] ?? 0) + (counts[.calves] ?? 0)
        let core = counts[.core] ?? 0

        if push > 0 && pull > 0 && legs > 0 { return .fullBody }
        if push > 0 && pull > 0 && legs == 0 { return .upper }
        if legs > 0 && push == 0 && pull == 0 { return .legs }
        if legs > 0 && (push > 0 || pull > 0) { return .lower }
        if push > pull { return .push }
        if pull > push { return .pull }
        if core > 0 { return .custom("core") }
        return fallback
    }

    static func rolesMatchForRotation(_ lhs: SessionRole, _ rhs: SessionRole) -> Bool {
        lhs.storageValue == rhs.storageValue
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }
}
