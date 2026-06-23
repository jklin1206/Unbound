import SwiftUI

// MARK: - QuickLogSheet
//
// Dead-simple "I did one set" capture. Just the metric that matters — reps, or
// a timed hold — and a Log button. No weight, RPE, quality, or notes: logging a
// set should be a single tap of input, every time. Awards a small XP; the 24h
// cap still gates it via SkillProgressService.canTrain. The reward sequence
// (rank-up reveal included) plays on submit.

struct QuickLogSheet: View {
    let skillId: String
    let skillTitle: String
    let defaultReps: Int
    var isHoldBased: Bool = false
    var holdTargetSeconds: Int = 30

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: ServiceContainer

    @State private var reps: Int = 0
    @State private var holdSeconds: Int = 0
    @State private var isSubmitting: Bool = false
    @State private var submitErrorMessage: String? = nil
    @State private var isTimerRunning: Bool = false
    @State private var holdTimer: Timer?
    @State private var rewardSequence: WorkoutRewardSequenceSummary? = nil
    @State private var pendingCompletionLogId: String? = nil

    private static let quickLogXP: Int = 10

    init(
        skillId: String,
        skillTitle: String,
        defaultReps: Int,
        isHoldBased: Bool = false,
        holdTargetSeconds: Int = 30
    ) {
        self.skillId = skillId
        self.skillTitle = skillTitle
        self.defaultReps = defaultReps
        self.isHoldBased = isHoldBased
        self.holdTargetSeconds = holdTargetSeconds
    }

    var body: some View {
        quickLogForm
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.unbound.bg)
        .fullScreenCover(item: $rewardSequence) { sequence in
            WorkoutRewardSequenceView(summary: sequence) {
                rewardSequence = nil
                dismiss()
            }
            .interactiveDismissDisabled(true)
        }
        .onDisappear { stopTimer() }
        .alert("Couldn't save set", isPresented: Binding(
            get: { submitErrorMessage != nil },
            set: { if !$0 { submitErrorMessage = nil } }
        )) {
            Button("Retry") { Task { await submit() } }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text(submitErrorMessage ?? "Your set is still here. Try again when the connection is stable.")
        }
    }

    private var quickLogForm: some View {
        VStack(spacing: 22) {
            Text(skillTitle)
                .font(.system(.title3).weight(.semibold))
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.top, 18)

            if isHoldBased {
                holdCard
            } else {
                repsCard
            }

            Spacer(minLength: 0)

            UnboundButton(
                title: isSubmitting ? "Saving Set" : "Log Set",
                icon: "checkmark",
                isEnabled: canSubmit && !isSubmitting
            ) {
                Task { await submit() }
            }
            .accessibilityIdentifier("skillQuickLog.submit")

            Button("Cancel") {
                stopTimer()
                dismiss()
            }
            .font(Font.unbound.bodyM)
            .foregroundStyle(Color.unbound.textTertiary)
            .accessibilityIdentifier("skillQuickLog.cancel")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg.ignoresSafeArea())
        .onAppear {
            if !isHoldBased, reps == 0 { reps = defaultReps }
        }
    }

    private var canSubmit: Bool {
        isHoldBased ? holdSeconds > 0 : reps > 0
    }

    // MARK: - Reps

    private var repsCard: some View {
        VStack(spacing: 8) {
            Text("REPS")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary)

            HStack(spacing: 28) {
                roundIconButton(icon: "minus") {
                    if reps > 0 { reps -= 1; UnboundHaptics.soft() }
                }
                Text("\(reps)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(minWidth: 110)
                roundIconButton(icon: "plus") {
                    reps += 1; UnboundHaptics.soft()
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Hold (timer)

    private var holdCard: some View {
        let progress: Double = holdTargetSeconds > 0
            ? min(1.0, Double(holdSeconds) / Double(holdTargetSeconds))
            : 0
        let met = holdSeconds >= holdTargetSeconds && holdTargetSeconds > 0

        return VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.unbound.surfaceElevated, lineWidth: 10)

                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        met ? Color.unbound.impact : Color.unbound.accent,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: progress)

                VStack(spacing: 2) {
                    Text(formatHold(holdSeconds))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("/ \(holdTargetSeconds)s")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .monospacedDigit()
                }
            }
            .frame(width: 168, height: 168)

            HStack(spacing: 12) {
                Button {
                    toggleTimer()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                        Text(isTimerRunning ? "Pause" : "Start")
                    }
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Capsule().fill(Color.unbound.surfaceElevated))
                }
                .buttonStyle(.plain)

                Button {
                    stopTimer()
                    holdSeconds = 0
                    UnboundHaptics.soft()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(.headline).weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.unbound.surfaceElevated))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func toggleTimer() {
        if isTimerRunning {
            stopTimer()
        } else {
            startTimer()
        }
        UnboundHaptics.medium()
    }

    private func startTimer() {
        isTimerRunning = true
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                holdSeconds += 1
            }
        }
    }

    private func stopTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
        isTimerRunning = false
    }

    private func formatHold(_ s: Int) -> String {
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }

    // MARK: - Submit

    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        submitErrorMessage = nil
        stopTimer()

        let now = Date()
        guard let userId = AuthService.shared.currentUserId else {
            isSubmitting = false
            submitErrorMessage = "Sign in before logging skill work."
            HapticManager.notification(.error)
            return
        }
        // Just the metric — everything else is an honest, clean single set.
        let set = LoggedSet(
            reps: isHoldBased ? 0 : reps,
            holdSeconds: isHoldBased ? holdSeconds : nil,
            weightKg: nil,
            rpe: nil,
            qualityFlags: [.clean],
            notes: nil
        )

        // Snapshot user state BEFORE the write so RewardComputer can
        // diff for PRs, rank-ups, badges, and first-set detection.
        let preSnapshot = await RewardComputer.shared.before(
            skillId: skillId,
            isHoldBased: isHoldBased,
            userId: userId,
            badgeService: services.badges
        )
        let loggedExercises = [LoggedExercise(name: skillTitle, sets: [set])]
        let completionLogId = pendingCompletionLogId ?? UUID().uuidString
        pendingCompletionLogId = completionLogId

        let performanceLog = TrainingSessionAdapters.performanceLogForSkillSession(
            id: completionLogId,
            userId: userId,
            skillId: skillId,
            skillTitle: skillTitle,
            startedAt: now,
            completedAt: now,
            durationSeconds: 0,
            exercises: loggedExercises
        )

        let completionResult: TrainingCompletionResult
        do {
            completionResult = try await TrainingCompletionService.shared.complete(
                performanceLog,
                services: services,
                skillXPAwarded: QuickLogSheet.quickLogXP
            )
        } catch {
            isSubmitting = false
            submitErrorMessage = error.localizedDescription
            HapticManager.notification(.error)
            return
        }

        // Fan out to BadgeService so per-set unlocks fire.
        let triggerKey = isHoldBased ? "\(skillId).hold" : skillId
        let triggerReps = isHoldBased ? (set.holdSeconds ?? 0) : set.reps
        let unlocked = await services.badges.evaluate(
            trigger: .setCompleted(exerciseKey: triggerKey, reps: triggerReps)
        )

        var summary = await RewardComputer.shared.after(
            snapshot: preSnapshot,
            skillTitle: skillTitle,
            bestSet: set,
            xpGained: completionResult.skillXPGained,
            unlockedBadges: unlocked
        )
        summary.progression = completionResult.progressionReceipt

        UnboundHaptics.medium()

        isSubmitting = false
        pendingCompletionLogId = nil
        rewardSequence = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: performanceLog,
            completionResult: completionResult,
            rewardSummary: summary,
            fallbackXP: QuickLogSheet.quickLogXP,
            sourceName: "Quick Log"
        )
    }

    // MARK: - Helpers

    private func roundIconButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Color.unbound.surfaceElevated))
        }
        .buttonStyle(.plain)
    }
}
