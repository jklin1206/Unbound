import SwiftUI

// MARK: - ActiveWorkoutContainerView reward summary
//
// Assembles the post-workout WorkoutRewardSequenceSummary (incl. the rank
// trial callout) from the completion result.

extension ActiveWorkoutContainerView {
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
