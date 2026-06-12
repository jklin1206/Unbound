import SwiftUI

extension SkillSessionView {
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

    private func computeXP() -> Int {
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

    // MARK: - Helpers

    func prescription(for id: String) -> TrainingPrescription? {
        guard let ex = aiSession?.exercises.first(where: { $0.id == id }) else { return nil }
        return ex.asLegacyPrescription
    }

    /// Loads (or regenerates) today's AI session. Drops any logged sets when
    /// the session is replaced so the slot strip rehydrates against fresh
    /// prescriptions.
    func loadSession(forceRefresh: Bool) async {
        guard let userId = AuthService.shared.currentUserId else {
            isLoadingSession = false
            loadError = "Sign in before starting a skill session."
            return
        }
        isLoadingSession = true
        loadError = nil
        if forceRefresh {
            loggedSets = [:]
            sessionStart = Date()
            elapsed = 0
        }
        do {
            let session = try await RPESessionService.shared.session(
                forSkillId: skillId,
                userId: userId,
                forceRefresh: forceRefresh
            )
            self.aiSession = session
        } catch {
            loadError = error.localizedDescription
            // Fallback path inside the service catches most cases — but if the
            // service itself rethrows, surface a generic AMRAP shell so the
            // user can still log work.
            self.aiSession = AISession(
                skillId: skillId,
                generatedAt: Date(),
                summary: "Train today's skill — quality over volume.",
                estimatedDurationMinutes: 20,
                exercises: [
                    AIExercise(
                        name: skillTitle,
                        description: "Train the skill directly. Log what you hit.",
                        cues: [],
                        setsCount: 3,
                        target: .amrap,
                        restSeconds: 90,
                        notes: nil,
                        isAccessory: false
                    )
                ],
                isAIGenerated: false
            )
        }
        isLoadingSession = false
    }

    func startTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                elapsed = Int(Date().timeIntervalSince(sessionStart))
            }
        }
    }

    func stopTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    func formatElapsed(_ s: Int) -> String {
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }
}
