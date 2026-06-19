import SwiftUI

// MARK: - ActiveWorkoutContainerView save + reward sequence

extension ActiveWorkoutContainerView {
    var totalLoggedWorkingSets: Int {
        session.exercises.filter { !$0.skipped }.reduce(0) {
            $0 + $1.sets.filter { !$0.isWarmup && $0.logged }.count
        }
    }

    func complete() async {
        guard !saving else { return }
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
            var completionResult = try await TrainingCompletionService.shared.complete(performanceLog, services: services)
            let weeklyVowReceipt = services.trials.recordCompletedVowWork(
                performanceLog: performanceLog,
                completionResult: completionResult
            )
            if let weeklyVowReceipt {
                completionResult = await applyWeeklyVowBonus(
                    weeklyVowReceipt,
                    to: completionResult
                )
            }
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

            let summary = makeRewardSequenceSummary(
                performanceLog: performanceLog,
                completionResult: completionResult,
                rankTrialResult: rankTrialResult,
                weeklyVowReceipt: weeklyVowReceipt
            )
            if totalLoggedWorkingSets > 0
                || summary.progression?.hasContent == true
                || summary.weeklyVowCallout != nil
                || summary.rankTrialCallout != nil {
                saving = false
                rewardSequence = summary
            } else {
                saving = false
                finishDismiss()
            }
        } catch {
            HapticManager.notification(.error)
            saving = false
            saveError = true   // surface it + offer Retry / Leave — never trap
        }
    }

    func applyWeeklyVowBonus(
        _ receipt: WeeklyVowCompletionReceipt,
        to completionResult: TrainingCompletionResult
    ) async -> TrainingCompletionResult {
        var updated = completionResult
        do {
            let reward = try await OverallLevelService.shared.grantFlatXPStrict(
                amount: receipt.completionBonus.overallLevelXP,
                sourceId: "weekly-vow-bonus:\(receipt.performanceLogId)",
                userId: receipt.vow.userId,
                at: receipt.completedAt,
                database: services.database
            )
            updated.appendOverallLevelReward(reward)
        } catch {
            LoggingService.shared.log(
                "Weekly Vow bonus XP persistence failed: \(error)",
                level: .warning,
                context: [
                    "vowId": receipt.vow.id,
                    "performanceLogId": receipt.performanceLogId
                ]
            )
        }
        return updated
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
        finishDismiss()
    }

    func makeRewardSequenceSummary(
        performanceLog: PerformanceLog,
        completionResult: TrainingCompletionResult,
        rankTrialResult: OverallRankTrialRunResult?,
        weeklyVowReceipt: WeeklyVowCompletionReceipt?
    ) -> WorkoutRewardSequenceSummary {
        let loggedSets = session.exercises
            .filter { !$0.skipped }
            .flatMap(\.sets)
            .filter { !$0.isWarmup && $0.logged }
        let workSets = loggedSets.count
        let rewardSummary: RewardSummary? = {
            guard let rankUp = rankTrialResult?.rankUp else { return nil }
            var summary = RewardSummary()
            summary.rankUp = rankUp
            summary.skillTitle = rankUp.skillTitle
            summary.progression = completionResult.progressionReceipt
            return summary
        }()

        var summary = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: performanceLog,
            completionResult: completionResult,
            rewardSummary: rewardSummary,
            fallbackXP: workSets * 12,
            sourceName: weeklyVowReceipt == nil ? session.source.rawValue.capitalized : "Binding Vow",
            weeklyVowCallout: weeklyVowReceipt?.callout
        )
        summary.rankTrialCallout = rankTrialResult.map(rankTrialCallout)
        return summary
    }

    func rankTrialCallout(_ result: OverallRankTrialRunResult) -> RankTrialRewardCallout {
        let failed = result.evaluation.failedStation
        let clearedCount = result.evaluation.stationResults.filter { $0.status == .passed }.count
        let totalCount = result.evaluation.stationResults.count
        let detail = failed.map { station in
            station.failureReason.map { "\(station.title): \($0)" } ?? station.title
        } ?? "\(clearedCount)/\(totalCount) stations cleared"

        return RankTrialRewardCallout(
            id: result.attempt.id,
            title: result.definition.displayName,
            subtitle: result.attempt.passed ? "\(result.definition.targetRank.displayName) gate cleared" : "\(result.definition.targetRank.displayName) gate held",
            statusLine: result.attempt.passed ? "Official result saved" : "First failed station saved",
            detailLine: detail,
            receiptLine: "\(clearedCount)/\(totalCount) stations cleared",
            passed: result.attempt.passed
        )
    }
}
