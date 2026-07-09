import SwiftUI

struct ProgramModifierSummaryRail: View {
    let summary: ProgramModifierSummary

    var body: some View {
        if !summary.isEmpty {
            let titles = summary.visibleLines.map { $0.title }
            let overflow = summary.overflowCount > 0 ? "+\(summary.overflowCount)" : nil
            MetaLine(titles + [overflow])
        }
    }
}

struct ProgramWorkoutExerciseList: View {
    let exercises: [Exercise]

    var body: some View {
        let visibleExercises = Array(exercises.prefix(5))

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visibleExercises.enumerated()), id: \.element.id) { index, exercise in
                ProgramVisualExerciseRow(exercise: exercise)
                if index < visibleExercises.count - 1 {
                    Divider()
                        .padding(.leading, 56)
                        .overlay(Color.unbound.borderSubtle.opacity(0.55))
                }
            }
            if exercises.count > 5 {
                Text("+\(exercises.count - 5) more")
                    .font(Font.unbound.captionS.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Color.unbound.textPrimary.opacity(0.62))
                    .padding(.top, 10)
                    .padding(.leading, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

/// One exercise line in the daily-card style: art thumbnail, name,
/// "Equipment · Muscles" subtitle, mono sets × target on the right.
/// Built from a program `Exercise` or a saved-workout prescription so the
/// daily quest card and loadout surfaces share one row language.
struct ProgramVisualExerciseRow: View {
    let name: String
    let muscleGroups: [MuscleGroup]
    let trailing: String
    private let includesMuscles: Bool

    init(exercise: Exercise) {
        name = exercise.name
        muscleGroups = exercise.muscleGroups
        trailing = "\(exercise.sets) × \(exercise.reps)"
        includesMuscles = true
    }

    /// Loadout rows show set count only — stored rep targets are template
    /// numbers that the progression engine overrides when the loadout lands
    /// on a program day, so printing them here would promise the wrong thing.
    /// Subtitle is equipment-only: the loadout answers "what do I need",
    /// the daily answers "what does it train".
    init(prescription: TrainingBlockPrescription) {
        name = prescription.exerciseName
        muscleGroups = prescription.muscleGroups
        trailing = "\(prescription.sets) set\(prescription.sets == 1 ? "" : "s")"
        includesMuscles = false
    }

    // Resolve any real movement (canonical exercise, skill drill, skill target …)
    // so drills like Wall Handstand get their art; only unresolved/routine-step
    // names fall back to the placeholder tile. Same rule as WorkoutReferenceImageView.
    private var definition: MovementDefinition? {
        let resolved = MovementResolver.resolve(name)
        guard let definition = MovementCatalog.definition(for: resolved.movementId),
              definition.role != .routineStep
        else { return nil }
        return definition
    }

    private var subtitle: String {
        let groups = includesMuscles
            ? muscleGroups.prefix(2).map(\.displayName).joined(separator: " / ")
            : ""
        guard let definition else { return groups }
        let labels = ExerciseLibrary.equipmentLabels(for: definition)
        let equipment = labels.first(where: { $0 != "Bodyweight" }) ?? labels.first
        return [equipment, groups].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 10) {
            ProgramWorkoutExerciseVisual(
                definition: definition,
                size: .thumbnail
            )
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            Spacer(minLength: 8)

            Text(trailing)
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct ProgramWorkoutExerciseVisual: View {
    let definition: MovementDefinition?
    let size: ExerciseVisualView.Size

    var body: some View {
        if let definition {
            ExerciseVisualView(definition: definition, size: size)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .fill(Color.unbound.surfaceElevated)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: size.iconSize * 0.65, weight: .semibold))
                    .foregroundStyle(Color.unbound.coachCyan)
            }
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
    }
}
