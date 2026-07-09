import SwiftUI

// MARK: - ActiveWorkoutContainerView completion
//
// The COMPLETE flow: assembles + saves the unified PerformanceLog via
// TrainingCompletionService, records rank-trial attempts, then routes into
// the right post-workout moment (reward sequence, The Crossing, or the
// gate-holds verdict) before dismissing.

extension ActiveWorkoutContainerView {
    func requestComplete() {
        if session.hasUnloggedWorkingSets {
            showCompleteConfirm = true
        } else {
            Task { await complete() }
        }
    }

    // MARK: - Save + reward

    func complete() async {
        guard !saving else { return }
        if isRehearsal {
            HapticManager.notification(.success)
            restTimer.stop()
            finishDismiss()
            return
        }
        guard let uid = services.auth.currentUserId else {
            // No session — don't trap the user behind a disabled dismiss.
            dismiss()
            return
        }
        saving = true
        #if DEBUG
        let performanceLog = session.assemblePerformanceLog(userId: uid, completedAt: DevProgramClock.now)
        #else
        let performanceLog = session.assemblePerformanceLog(userId: uid)
        #endif
        do {
            let completionResult = try await TrainingCompletionService.shared.complete(performanceLog, services: services)
            let rankTrialResult = OverallRankTrialRunner.shared.recordCompletedAttempt(
                performanceLog: performanceLog,
                completionResult: completionResult,
                bodyweightKg: (try? await services.user.fetchProfile(userId: uid))?.weightKg
            )
            HapticManager.notification(.success)
            restTimer.stop()
            draftStore.clear()
            // Finished training — drop squad presence so squadmates stop seeing
            // us as live (best-effort; the row also auto-expires after 3h).
            Task { await services.squadPresence.clearPresence(userId: uid) }

            var summary = makeRewardSequenceSummary(
                performanceLog: performanceLog,
                completionResult: completionResult,
                rankTrialResult: rankTrialResult
            )
            // Tag the final beat so it can offer an opt-in post-workout photo
            // linked to this session. Travels with the summary into the gate tail too.
            summary.workoutPhotoContext = WorkoutPhotoSummary(performanceLog: performanceLog)
            let hasReward = totalLoggedWorkingSets > 0
                || summary.progression?.hasContent == true
                || summary.rankTrialCallout != nil
            saving = false
            if let rt = rankTrialResult, rt.didAdvanceRank {
                // The Crossing IS the gate's reward moment and rank-up announcement;
                // chain the remaining spoils afterward, minus the redundant verdict beat.
                pendingGateDefiningNumber = gateDefiningNumber(rt.evaluation)
                stashedGateRewardSummary = gateRewardTail(from: summary)
                pendingGateCrossing = GateCrossingCatalog.crossing(for: rt.definition.format)
            } else if let rt = rankTrialResult, !rt.evaluation.passed {
                // Failed gate — "THE GATE HOLDS" verdict + ENTER AGAIN. The
                // sequence is skipped, so the verdict carries a one-line spoils
                // note or the banked XP/Arcs would vanish invisibly.
                pendingGateVerdict = GateVerdictContext(
                    evaluation: rt.evaluation,
                    world: GateWorldCatalog.world(for: rt.definition.format),
                    spoils: gateSpoilsLine(from: summary))
            } else if hasReward {
                rewardSequence = summary
            } else {
                finishDismiss()
            }
        } catch {
            HapticManager.notification(.error)
            saving = false
            saveError = true   // surface it + offer Retry / Leave — never trap
        }
    }

    var gateWorld: GateWorld? {
        rankTrialDefinition.map { GateWorldCatalog.world(for: $0.format) }
    }

    /// How many rank-trial stations have a logged working set — drives the beat.
    var rankTrialClearedStations: Int {
        session.rankTrialLoggedStationCount { $0.hasLoggedRankTrialWorkingSet }
    }

    /// "passed / scored" stations, e.g. "4/4", for the minted gate card.
    private func gateDefiningNumber(_ evaluation: OverallRankTrialEvaluation) -> String {
        let scored = evaluation.stationResults.filter(\.isScored)
        let passed = scored.filter { $0.status == .passed }.count
        return "\(passed)/\(scored.count)"
    }

    /// The Crossing IS the rank-up announcement, so the chained reward tail drops
    /// the redundant rank-trial receipt beat and keeps only the rest of the spoils.
    private func gateRewardTail(from summary: WorkoutRewardSequenceSummary) -> WorkoutRewardSequenceSummary? {
        var tail = summary
        tail.rankTrialCallout = nil
        let hasTailReward = totalLoggedWorkingSets > 0
            || tail.progression?.hasContent == true
            || !tail.badges.isEmpty
            || tail.xp.total > 0
        return hasTailReward ? tail : nil
    }

    /// One quiet line for the fail verdict: the XP/Arcs banked during the
    /// attempt, which would otherwise never be shown (a failed gate skips the
    /// reward sequence entirely).
    private func gateSpoilsLine(from summary: WorkoutRewardSequenceSummary) -> String? {
        var parts: [String] = []
        if summary.xp.total > 0 { parts.append("+\(summary.xp.total) XP") }
        if summary.arcsEarned > 0 { parts.append("+\(summary.arcsEarned) ARCS") }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ") + " BANKED"
    }

    func finishDismiss() {
        if let onFinished {
            onFinished()
        } else {
            dismiss()
        }
    }

    func finishRewardSequence() {
        guard !isFinishingRewardSequence else { return }
        isFinishingRewardSequence = true
        rewardSequence = nil
        if !isRehearsal {
            AppStoreReviewPrompt.requestAfterFirstRealWorkoutIfNeeded()
        }
        finishDismiss()
    }
}
