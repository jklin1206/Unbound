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
                    .frame(height: 38)
                    .contentShape(Rectangle())
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
                    .contentShape(Rectangle())
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

                VStack(alignment: .leading, spacing: 0) {
                    TextField("Workout name", text: $draft.title)
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("sessionEditor.workoutName")

                    Rectangle()
                        .fill(Color.unbound.borderSubtle)
                        .frame(height: 1)
                }
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
            .foregroundStyle(Color.unbound.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sessionEditor.addExercise")
    }

}

struct WorkoutReferenceImageView: View {
    let exerciseName: String?
    let fallbackSystemName: String
    let fallbackTint: Color
    var size: ExerciseVisualView.Size = .thumbnail

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
            ExerciseVisualView(definition: definition, size: size)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .fill(fallbackTint.opacity(0.14))
                Image(systemName: fallbackSystemName)
                    .font(.system(size: fallbackIconSize, weight: .bold))
                    .foregroundStyle(fallbackTint)
            }
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .strokeBorder(fallbackTint.opacity(0.25), lineWidth: 1)
            )
        }
    }

    private var fallbackIconSize: CGFloat {
        switch size {
        case .thumbnail: return 15
        case .hero: return 28
        }
    }
}
