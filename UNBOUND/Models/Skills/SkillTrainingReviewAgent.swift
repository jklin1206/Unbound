import Foundation

enum SkillTrainingReviewAgent {
    static let reviewerName = "skill-rung-review-v1"

    static func evaluate(performanceLog: PerformanceLog) -> [SkillTrainingAgentReview] {
        performanceLog.blocks.compactMap { block in
            guard block.kind == .skill, let skillId = block.skillId else { return nil }
            let completedSets = block.exercises
                .flatMap(\.sets)
                .filter { !$0.isWarmup && hasTrainingMetric($0) }
            guard !completedSets.isEmpty else { return nil }

            let plannedSets = max(
                completedSets.count,
                block.exercises.reduce(0) { $0 + max(0, $1.plannedSets) }
            )
            let cleanSets = completedSets.filter(isCleanProofSet)
            let cleanRatio = ratio(cleanSets.count, completedSets.count)
            let completionRatio = ratio(completedSets.count, plannedSets)
            let assistedRatio = ratio(
                completedSets.filter { $0.qualityFlags.contains(.assisted) }.count,
                completedSets.count
            )
            let frictionRatio = ratio(
                completedSets.filter { set in
                    set.qualityFlags.contains(.formBreak)
                        || set.qualityFlags.contains(.partialRange)
                }.count,
                completedSets.count
            )
            let painLogged = completedSets.contains { $0.qualityFlags.contains(.pain) }
            let averageRPE = average(completedSets.compactMap(\.rpe).map(Double.init))

            let outcome = outcome(
                completionRatio: completionRatio,
                cleanRatio: cleanRatio,
                assistedRatio: assistedRatio,
                frictionRatio: frictionRatio,
                painLogged: painLogged,
                averageRPE: averageRPE
            )

            return SkillTrainingAgentReview(
                id: "\(performanceLog.id):\(block.id):review",
                performanceLogId: performanceLog.id,
                blockId: block.id,
                userId: performanceLog.userId,
                skillId: skillId,
                skillTitle: block.title,
                selectedRungId: block.selectedRungId,
                selectedRungSource: block.selectedRungSource,
                reviewedExerciseNames: block.exercises.map(\.name),
                outcome: outcome,
                confidence: confidence(
                    completedSets: completedSets.count,
                    plannedSets: plannedSets,
                    averageRPE: averageRPE
                ),
                reason: reason(
                    outcome: outcome,
                    completionRatio: completionRatio,
                    cleanRatio: cleanRatio,
                    assistedRatio: assistedRatio,
                    frictionRatio: frictionRatio,
                    painLogged: painLogged,
                    averageRPE: averageRPE
                ),
                completedSets: completedSets.count,
                plannedSets: plannedSets,
                cleanSetRatio: rounded(cleanRatio),
                averageRPE: averageRPE.map(rounded),
                generatedAt: performanceLog.completedAt,
                reviewer: reviewerName
            )
        }
    }

    private static func outcome(
        completionRatio: Double,
        cleanRatio: Double,
        assistedRatio: Double,
        frictionRatio: Double,
        painLogged: Bool,
        averageRPE: Double?
    ) -> SkillTrainingAgentReviewOutcome {
        if painLogged || completionRatio < 0.5 || frictionRatio >= 0.4 {
            return .regress
        }
        if completionRatio >= 1.0,
           cleanRatio >= 0.85,
           assistedRatio <= 0.1,
           (averageRPE ?? 0) <= 8.0 {
            return .promote
        }
        return .hold
    }

    private static func reason(
        outcome: SkillTrainingAgentReviewOutcome,
        completionRatio: Double,
        cleanRatio: Double,
        assistedRatio: Double,
        frictionRatio: Double,
        painLogged: Bool,
        averageRPE: Double?
    ) -> String {
        if painLogged {
            return "Pain was logged, so the next prescription should reduce difficulty."
        }
        if completionRatio < 0.5 {
            return "Less than half of the planned work was completed, so the next prescription should reduce difficulty."
        }
        if frictionRatio >= 0.4 {
            return "Several sets had form or range flags, so the next prescription should reduce difficulty."
        }
        if outcome == .promote {
            return "All planned work was completed cleanly at a manageable effort."
        }
        if assistedRatio > 0.1 {
            return "The work was completed, but assistance was still present, so this rung should repeat."
        }
        if cleanRatio < 0.85 {
            return "The work was completed, but not enough sets were clean enough to advance."
        }
        if let averageRPE, averageRPE > 8.0 {
            return "The work was completed, but effort was high enough to hold this rung."
        }
        return "The review did not find enough proof to advance or regress, so this rung should repeat."
    }

    private static func confidence(
        completedSets: Int,
        plannedSets: Int,
        averageRPE: Double?
    ) -> Double {
        let setCoverage = min(1.0, ratio(completedSets, max(1, plannedSets)))
        let rpeBonus = averageRPE == nil ? 0.0 : 0.1
        return rounded(min(0.95, 0.55 + (setCoverage * 0.3) + rpeBonus))
    }

    private static func hasTrainingMetric(_ set: PerformanceSet) -> Bool {
        set.reps != nil
            || set.holdSeconds != nil
            || set.durationSeconds != nil
            || set.distanceMeters != nil
            || set.calories != nil
    }

    private static func isCleanProofSet(_ set: PerformanceSet) -> Bool {
        !set.qualityFlags.contains(.assisted)
            && !set.qualityFlags.contains(.formBreak)
            && !set.qualityFlags.contains(.partialRange)
            && !set.qualityFlags.contains(.pain)
    }

    private static func ratio(_ numerator: Int, _ denominator: Int) -> Double {
        guard denominator > 0 else { return 0 }
        return Double(numerator) / Double(denominator)
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
