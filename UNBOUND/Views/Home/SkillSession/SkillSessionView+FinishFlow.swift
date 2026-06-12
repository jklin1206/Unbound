import SwiftUI

// MARK: - Loading states, summary card, fallback, finish bar + finish flow

extension SkillSessionView {

    // MARK: - Loading + summary

    var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.unbound.accent)
                .scaleEffect(1.3)
            Text("Generating today's session…")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
            if let err = loadError {
                Text(err)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    func summaryCard(_ session: AISession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TODAY'S FOCUS")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.accent)
            Text(session.summary)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("~\(session.estimatedDurationMinutes) min")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    // MARK: - Generic fallback

    var genericFallback: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No detailed plan yet")
                .font(.system(.headline).weight(.semibold))
                .foregroundStyle(Color.unbound.textPrimary)
            Text("This skill doesn't have a structured training plan in V1. Train the movement on your own — sets, reps, holds — and tap FINISH SESSION when you're done.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    // MARK: - Finish bar

    var finishBar: some View {
        let title: String
        if !canFinish {
            title = "Log a set to finish"
        } else if isFinishing {
            title = "Saving session"
        } else if loggedCount == totalSlots && totalSlots > 0 {
            title = "Finish session"
        } else {
            title = "Finish session (\(loggedCount)/\(totalSlots))"
        }
        return UnboundButton(
            title: title,
            icon: "checkmark.seal.fill",
            isEnabled: canFinish && !isFinishing
        ) {
            Task { await finish() }
        }
        .accessibilityIdentifier("skillSession.finish")
    }

    // MARK: - Finish flow

    func finish() async {
        guard !isFinishing else { return }
        isFinishing = true
        finishErrorMessage = nil
        stopTimer()

        let realNow = Date()
        #if DEBUG
        let now = DevProgramClock.now
        #else
        let now = realNow
        #endif
        let duration = Int(realNow.timeIntervalSince(sessionStart))
        let adjustedSessionStart = now.addingTimeInterval(-TimeInterval(duration))
        guard let userId = AuthService.shared.currentUserId else {
            isFinishing = false
            finishErrorMessage = "Sign in before finishing a skill session."
            HapticManager.notification(.error)
            return
        }

        // Build LoggedExercise entries grouped by exercise name. Pull from
        // every exercise that has at least one logged slot — mains AND any
        // accessory the user actually completed.
        var loggedExercises: [LoggedExercise] = []
        if let session = aiSession {
            for ex in session.exercises {
                let bucket = loggedSets[ex.id] ?? [:]
                guard !bucket.isEmpty else { continue }
                let sortedSets = bucket
                    .sorted(by: { $0.key < $1.key })
                    .map(\.value)
                loggedExercises.append(
                    LoggedExercise(name: ex.name, sets: sortedSets)
                )
            }
        }

        // XP: 25 × completion fraction. Cap at 25, floor at 1 if anything logged.
        let xp = computeXP()

        // Snapshot before write. Look up the canonical node for hold-based
        // detection (the earned tier is read from the tier store inside before/after).
        let node = SkillGraph.shared.node(id: skillId)
        let isHoldBased: Bool = {
            if case .hold = node?.target { return true }
            return false
        }()

        let preSnapshot = await RewardComputer.shared.before(
            skillId: skillId,
            isHoldBased: isHoldBased,
            userId: userId,
            badgeService: services.badges
        )

        let completionLogId = pendingCompletionLogId ?? UUID().uuidString
        pendingCompletionLogId = completionLogId

        let performanceLog = TrainingSessionAdapters.performanceLogForSkillSession(
            id: completionLogId,
            userId: userId,
            skillId: skillId,
            skillTitle: skillTitle,
            startedAt: adjustedSessionStart,
            completedAt: now,
            durationSeconds: duration,
            exercises: loggedExercises,
            selectedRungId: aiSession?.selectedRungId,
            selectedRungSource: aiSession?.selectedRungSource,
            selectedRungReason: aiSession?.selectedRungReason
        )

        let completionResult: TrainingCompletionResult
        do {
            completionResult = try await TrainingCompletionService.shared.complete(
                performanceLog,
                services: services,
                skillXPAwarded: xp
            )
        } catch {
            isFinishing = false
            finishErrorMessage = error.localizedDescription
            HapticManager.notification(.error)
            return
        }

        let compatibleLog = TrainingSessionAdapters.sessionLogs(from: performanceLog, xpAwarded: xp).first

        // Fire badge evaluation — sessionLogged trigger expects a
        // WorkoutLog (legacy). For now, fire setCompleted for the
        // best set in the session — that's what the catalog evaluators
        // actually consume.
        let bestSet = compatibleLog.flatMap { RewardComputer.bestSet(from: $0, isHoldBased: isHoldBased) }
        var unlocked: [Badge] = []
        if let bs = bestSet {
            let triggerKey = isHoldBased ? "\(skillId).hold" : skillId
            let triggerReps = isHoldBased ? (bs.holdSeconds ?? 0) : bs.reps
            unlocked = await services.badges.evaluate(
                trigger: .setCompleted(exerciseKey: triggerKey, reps: triggerReps)
            )
        }

        var summary = await RewardComputer.shared.after(
            snapshot: preSnapshot,
            skillTitle: skillTitle,
            bestSet: bestSet ?? LoggedSet(reps: 0, holdSeconds: nil, weightKg: nil, rpe: nil),
            xpGained: completionResult.skillXPGained,
            unlockedBadges: unlocked
        )
        summary.progression = completionResult.progressionReceipt

        UnboundHaptics.medium()
        pendingCompletionLogId = nil

        rewardSequence = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: performanceLog,
            completionResult: completionResult,
            rewardSummary: summary,
            fallbackXP: xp,
            sourceName: "Skill Session"
        )
    }

    func computeXP() -> Int {
        guard totalSlots > 0 else {
            // Generic fallback / no plan — give the standard award.
            return 25
        }
        let fraction = Double(loggedCount) / Double(totalSlots)
        let raw = 25.0 * fraction
        let rounded = Int(raw.rounded())
        // If they logged anything, give at least 1 XP so the work counts.
        if loggedCount > 0 {
            return max(1, rounded)
        }
        return 0
    }
}
