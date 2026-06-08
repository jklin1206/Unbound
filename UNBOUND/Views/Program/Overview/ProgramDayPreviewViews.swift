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

struct ProgramWaveAdjustmentPanel: View {
    let adjustments: [WaveAdjustment]
    let onUndo: (WaveAdjustment) -> Void

    var body: some View {
        if !adjustments.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Divider()
                    .overlay(Color.unbound.border)
                CalmSectionHeader(title: "WAVE ADJUSTMENTS")
                    .padding(.vertical, 6)
                ForEach(adjustments) { adjustment in
                    ProgramWaveAdjustmentRow(adjustment: adjustment, onUndo: onUndo)
                    Divider()
                        .padding(.leading, 22)
                        .overlay(Color.unbound.border.opacity(0.5))
                }
            }
        }
    }
}

private struct ProgramWaveAdjustmentRow: View {
    let adjustment: WaveAdjustment
    let onUndo: (WaveAdjustment) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: adjustment.reason.iconSystemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
                .padding(.top, 2)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(adjustment.reason.decisionApplied)
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                Text(adjustment.reason.inputSummary)
                    .font(Font.unbound.captionS)
                    .tracking(0.2)
                    .foregroundStyle(Color.unbound.textPrimary.opacity(0.66))
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            if adjustment.reason.revertible {
                Button {
                    onUndo(adjustment)
                } label: {
                    Text("UNDO")
                        .font(Font.unbound.captionS.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(Color.unbound.warnOrange)
                        .frame(height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("program.waveAdjustment.undo.\(adjustment.dayNumber)")
            }
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

private struct ProgramVisualExerciseRow: View {
    let exercise: Exercise

    private var definition: MovementDefinition? {
        MovementCatalog.canonicalExercise(named: exercise.name)
    }

    private var subtitle: String {
        let groups = exercise.muscleGroups.prefix(2).map(\.displayName).joined(separator: " / ")
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

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name.uppercased())
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(subtitle.uppercased())
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textPrimary.opacity(0.58))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 8)

            Text("\(exercise.sets)x\(exercise.reps)")
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary.opacity(0.78))
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
