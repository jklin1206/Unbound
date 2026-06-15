import SwiftUI

// MARK: - ActiveWorkoutContainerView chrome
//
// Top bar (close / elapsed time / mode badge / progress rail), the draft
// autosave warning row, trial-format flags, and time formatting helpers.

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

    // MARK: - Computed helpers

    var workoutTopBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                closeWorkoutButton
                Spacer(minLength: 0)
                workoutElapsedTime
                Spacer(minLength: 0)
                workoutModeBadge
            }

            workoutProgressRail
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    var closeWorkoutButton: some View {
        Button {
            showExitConfirm = true
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.unbound.textSecondary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.unbound.surface))
                .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close workout")
    }

    var workoutElapsedTime: some View {
        VStack(spacing: 2) {
            Text("TOTAL TIME")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(Self.timeString(seconds: workoutElapsedSeconds))
                .font(Font.unbound.monoS.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary)
                .monospacedDigit()
        }
        .frame(minWidth: 92)
        .accessibilityLabel("Workout timer")
        .accessibilityValue(Self.timeString(seconds: workoutElapsedSeconds))
        .accessibilityIdentifier("workout.elapsedTime")
    }

    var workoutModeBadge: some View {
        let tint = workoutHeaderTint
        let text = session.progressSummary.isComplete
            ? "FINISH"
            : (isRankTrial ? "TRIAL" : "LIVE")
        return Text(text)
            .font(Font.unbound.captionS.weight(.bold))
            .tracking(1.4)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.15)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1))
            .frame(width: 64)
            .accessibilityLabel(text == "FINISH" ? "Ready to finish" : text)
    }

    var workoutProgressRail: some View {
        let progress = session.progressSummary
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(workoutProgressLabel(progress))
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.unbound.surface)
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(workoutHeaderTint)
                        .frame(width: geo.size.width * workoutProgressFraction(progress), height: 3)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress.loggedWorkingSets)
                }
            }
            .frame(height: 3)
        }
    }

    var workoutHeaderTint: Color {
        isRankTrial ? Color.unbound.coachCyan : Color.unbound.accent
    }

    func workoutProgressFraction(_ progress: ActiveWorkoutSession.ProgressSummary) -> CGFloat {
        guard progress.totalWorkingSets > 0 else { return 0 }
        return min(1, CGFloat(progress.loggedWorkingSets) / CGFloat(progress.totalWorkingSets))
    }

    func workoutProgressLabel(_ progress: ActiveWorkoutSession.ProgressSummary) -> String {
        guard progress.totalWorkingSets > 0 else { return "SESSION IN PROGRESS" }
        if progress.isComplete { return "READY TO FINISH" }
        return "\(progress.loggedWorkingSets) OF \(progress.totalWorkingSets) WORK SETS"
    }

    var totalLoggedWorkingSets: Int {
        session.exercises.filter { !$0.skipped }.reduce(0) {
            $0 + $1.sets.filter { !$0.isWarmup && $0.logged }.count
        }
    }

    var rankTrialDefinition: OverallRankTrialDefinition? {
        guard session.source == .overallRankTrial else { return nil }
        return OverallRankTrialDefinitions.definition(id: session.programId)
    }

    var isRankTrial: Bool {
        rankTrialDefinition != nil
    }

    var isDeckTrial: Bool {
        rankTrialDefinition?.format == .deckOfProof
    }

    static func elapsedSeconds(since startedAt: Date, now: Date = Date()) -> Int {
        max(0, Int(now.timeIntervalSince(startedAt).rounded(.down)))
    }

    static func timeString(seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3_600
        let minutes = (clamped % 3_600) / 60
        let seconds = clamped % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
