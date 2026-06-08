import SwiftUI

extension SessionEditorView {
    var header: some View {
        HStack {
            Button {
                UnboundHaptics.soft()
                dismiss()
            } label: {
                Text("Close")
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Capsule().fill(Color.unbound.surface))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(mode.headerTitle)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textPrimary)

            Spacer()

            Button {
                UnboundHaptics.soft()
                draft = originalDraft
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.unbound.surface))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset session edits")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    var builderHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                WorkoutReferenceImageView(
                    exerciseName: draft.effectiveReferenceExerciseName,
                    fallbackSystemName: "dumbbell.fill",
                    fallbackTint: Color.unbound.accent
                )
                .frame(width: 58, height: 58)

                TextField("Workout name", text: $draft.title)
                    .font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.unbound.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
                    .accessibilityIdentifier("sessionEditor.workoutName")
            }
        }
    }

    var bottomAddExerciseButton: some View {
        Button {
            UnboundHaptics.soft()
            openAddExercise()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                Text("ADD EXERCISE")
                    .font(Font.unbound.bodyS.weight(.heavy))
                    .tracking(1.1)
            }
            .foregroundStyle(Color.unbound.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.36), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sessionEditor.addExercise")
    }

    var compactPersistenceStrip: some View {
        let summary = TrainingSessionEditSummary.compare(original: originalDraft, edited: draft)
        let hasAnyChange = summary.isChanged || draft != originalDraft
        let headline = summary.isChanged ? summary.headline : (hasAnyChange ? "Programming edited" : summary.headline)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: hasAnyChange ? "pencil.line" : "checkmark.seal")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(hasAnyChange ? Color.unbound.warnOrange : Color.unbound.success)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill((hasAnyChange ? Color.unbound.warnOrange : Color.unbound.success).opacity(0.13)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TrainingSessionEditPersistence.allCases, id: \.self) { mode in
                        persistenceChip(mode)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    func persistenceChip(_ mode: TrainingSessionEditPersistence) -> some View {
        let isSelected = selectedPersistence == mode
        return Button {
            UnboundHaptics.soft()
            if mode.isImplemented {
                selectedPersistence = mode
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: mode.isImplemented ? "checkmark.circle.fill" : "clock.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(mode.displayName.uppercased())
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(0.9)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isSelected ? Color.unbound.textPrimary : Color.unbound.textSecondary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                Capsule()
                    .fill(isSelected ? Color.unbound.accent.opacity(0.22) : Color.unbound.bg.opacity(0.72))
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.unbound.accent.opacity(0.55) : Color.unbound.borderSubtle,
                        lineWidth: 1
                    )
            )
            .opacity(mode.isImplemented ? 1.0 : 0.48)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.isImplemented ? mode.displayName : "\(mode.displayName) coming soon")
    }

}

struct WorkoutReferenceImageView: View {
    let exerciseName: String?
    let fallbackSystemName: String
    let fallbackTint: Color

    private var definition: MovementDefinition? {
        guard let exerciseName else { return nil }
        let resolved = MovementResolver.resolve(exerciseName)
        guard let definition = MovementCatalog.definition(for: resolved.movementId),
              definition.role != .routineStep
        else { return nil }
        return definition
    }

    var body: some View {
        if let definition {
            ExerciseVisualView(definition: definition, size: .thumbnail)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fallbackTint.opacity(0.14))
                Image(systemName: fallbackSystemName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(fallbackTint)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(fallbackTint.opacity(0.25), lineWidth: 1)
            )
        }
    }
}
