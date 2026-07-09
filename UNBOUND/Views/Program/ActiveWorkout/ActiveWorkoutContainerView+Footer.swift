import SwiftUI

// MARK: - ActiveWorkoutContainerView footer
//
// Bottom-of-screen chrome: the rank-trial rest footer, the empty Quick Log
// state, and the completion footer (rest pill, progress line, DEBUG fill,
// add-exercise, COMPLETE button).

extension ActiveWorkoutContainerView {
    var trialRestFooter: some View {
        RestTimerPill(
            model: restTimer,
            onAddThirty: { restTimer.addThirty() },
            onDismiss: { restTimer.dismiss() }
        )
        .padding(.bottom, 16)
        .allowsHitTesting(restTimer.isVisible)
    }

    /// Free / Quick-Log session — the only mode that supports adding exercises
    /// live. Program days and rank trials have a fixed prescription.
    var isCustomSession: Bool {
        session.source == .custom && !isRankTrial
    }

    var visibleExerciseCount: Int {
        session.exercises.filter { !$0.skipped }.count
    }

    var emptyQuickLogState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "dumbbell")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.unbound.textTertiary)
            VStack(spacing: 6) {
                Text("No exercises yet")
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Add what you just trained.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                UnboundHaptics.soft()
                showingAddExercise = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("ADD EXERCISE")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.4)
                }
                .foregroundStyle(Color.unbound.bg)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.unbound.accent))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("workout.addExercise.empty")
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    var completionFooter: some View {
        let progress = session.progressSummary
        return VStack(spacing: 10) {
            RestTimerPill(
                model: restTimer,
                onAddThirty: { restTimer.addThirty() },
                onDismiss: { restTimer.dismiss() }
            )

            HStack(spacing: 8) {
                Image(systemName: progress.isComplete ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(progress.isComplete ? Color.unbound.accent : Color.unbound.textTertiary)
                Text(progress.footerText.uppercased())
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer()
            }
            .padding(.horizontal, 4)

            #if DEBUG
            Button(action: debugFillPlannedSets) {
                Label("Fill Planned Sets", systemImage: "wand.and.stars")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.unbound.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("workout.debug.fillPlannedSets")
            #endif

            if isCustomSession {
                Button {
                    UnboundHaptics.soft()
                    showingAddExercise = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("ADD EXERCISE")
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.4)
                    }
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.unbound.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("workout.addExercise")
            }

            Button(action: requestComplete) {
                HStack(spacing: 10) {
                    if saving {
                        ProgressView()
                            .tint(Color.unbound.bg)
                    }
                    Text(saving ? "SAVING SESSION" : completionButtonTitle(progress: progress))
                        .font(Font.unbound.bodyLStrong)
                        .tracking(2)
                }
                .foregroundStyle(Color.unbound.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(RoundedRectangle(cornerRadius: 18)
                    .fill(saving ? Color.unbound.textSecondary : Color.unbound.accent))
                .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .disabled(saving)
            .accessibilityIdentifier("workout.complete")
            .accessibilityLabel(saving ? "Saving session" : (isRankTrial ? "Complete trial" : "Complete session"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(Color.unbound.bg.opacity(0.96))
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Color.unbound.bg.opacity(0), Color.unbound.bg.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 42)
            .offset(y: -42)
            .allowsHitTesting(false)
        }
    }

    private func completionButtonTitle(progress: ActiveWorkoutSession.ProgressSummary) -> String {
        if isRankTrial {
            return progress.isComplete ? "FINISH TRIAL" : "COMPLETE TRIAL"
        }
        return progress.isComplete ? "FINISH SESSION" : "COMPLETE SESSION"
    }
}
