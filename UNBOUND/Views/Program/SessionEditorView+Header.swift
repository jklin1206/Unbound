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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(mode.summaryEyebrow)
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.coachCyan)

                    TextField("Workout name", text: $draft.title)
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.unbound.bg.opacity(0.74))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                        )
                        .accessibilityIdentifier("sessionEditor.workoutName")
                }

                VStack(alignment: .trailing, spacing: 6) {
                    compactMetric("\(exerciseCount)", "EXERCISES")
                    compactMetric("~\(draft.estimatedMinutes)M", "TIME")
                }
            }

            HStack(spacing: 8) {
                builderActionButton("Add Exercise", systemName: "plus", tint: Color.unbound.accent) {
                    UnboundHaptics.soft()
                    openAddExercise()
                }
                .accessibilityIdentifier("sessionEditor.addExercise")

                if mode.showsSaveWorkoutAction {
                    iconActionButton(systemName: "square.and.arrow.down", tint: Color.unbound.coachCyan) {
                        guard exerciseCount > 0 else {
                            showEmptyWorkoutWarning = true
                            return
                        }
                        UnboundHaptics.soft()
                        showSaveWorkoutSheet = true
                    }
                    .accessibilityIdentifier("sessionEditor.saveWorkout")
                    .accessibilityLabel("Save workout")
                }

                iconActionButton(systemName: "sparkles", tint: Color.unbound.accent) {
                    UnboundHaptics.soft()
                    showSkillBlockPicker = true
                }
                .accessibilityIdentifier("sessionEditor.addSkillBlock")
                .accessibilityLabel("Add skill block")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.coachCyan.opacity(0.22), lineWidth: 1)
        )
    }

    func compactMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(Font.unbound.monoM.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
            Text(label)
                .font(Font.unbound.captionS)
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(minWidth: 70, alignment: .trailing)
    }

    func builderActionButton(
        _ title: String,
        systemName: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(Font.unbound.bodyS.weight(.heavy))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(0.36), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    func iconActionButton(
        systemName: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(0.26), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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
