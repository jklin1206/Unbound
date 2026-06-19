import SwiftUI

// MARK: - ActiveWorkoutContainerView bottom-chrome (footer + autosave warning)

extension ActiveWorkoutContainerView {
    var draftAutosaveWarning: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .bold))
            Text("Autosave isn't working — finish your session to keep this workout.")
                .font(Font.unbound.captionS)
                .lineLimit(2)
        }
        .foregroundStyle(Color.unbound.alert)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
        .accessibilityIdentifier("workout.draftAutosaveWarning")
    }

    var deckRestFooter: some View {
        RestTimerPill(
            model: restTimer,
            onAddThirty: { restTimer.addThirty() },
            onDismiss: { restTimer.dismiss() }
        )
        .padding(.bottom, 16)
        .allowsHitTesting(restTimer.isVisible)
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

    func completionButtonTitle(progress: ActiveWorkoutSession.ProgressSummary) -> String {
        if isRankTrial {
            return progress.isComplete ? "FINISH TRIAL" : "COMPLETE TRIAL"
        }
        return progress.isComplete ? "FINISH SESSION" : "COMPLETE SESSION"
    }
}
