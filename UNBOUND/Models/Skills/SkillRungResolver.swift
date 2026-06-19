import Foundation

enum SkillRungResolver {
    static func resolve(
        skillId: String,
        isTrainable: Bool,
        plan: SkillTrainingPlan? = nil,
        lastReview: SkillTrainingAgentReview? = nil
    ) -> SkillTrainingRungDecision? {
        let plan = plan ?? SkillTrainingPlanLibrary.plan(for: skillId)
        guard let plan else { return nil }

        let targetTitle = SkillGraph.shared.node(id: skillId)?.title ?? skillId
        if isTrainable || plan.regressions.isEmpty {
            return directDecision(skillId: skillId, targetTitle: targetTitle, plan: plan)
        }
        return regressionDecision(
            skillId: skillId,
            targetTitle: targetTitle,
            plan: plan,
            lastReview: lastReview
        )
    }

    private static func directDecision(
        skillId: String,
        targetTitle: String,
        plan: SkillTrainingPlan
    ) -> SkillTrainingRungDecision {
        let reason = "Train direct \(targetTitle) work because the skill is currently available."
        return SkillTrainingRungDecision(
            targetSkillId: skillId,
            targetSkillTitle: targetTitle,
            selectedRungId: "\(skillId).main",
            selectedRungTitle: "Direct \(targetTitle) work",
            source: .main,
            reason: reason,
            prescriptions: plan.mainSets.map { prescription in
                prescription.withRungReason(reason)
            }
        )
    }

    private static func regressionDecision(
        skillId: String,
        targetTitle: String,
        plan: SkillTrainingPlan,
        lastReview: SkillTrainingAgentReview?
    ) -> SkillTrainingRungDecision {
        let index = regressionIndex(skillId: skillId, plan: plan, lastReview: lastReview)
        let regression = plan.regressions[index]
        let reason = regressionReason(targetTitle: targetTitle, index: index, lastReview: lastReview)
        let prescription = TrainingPrescription(
            exerciseName: regression.name,
            sets: 3,
            target: defaultTarget(for: regression.name),
            restSeconds: 90,
            notes: ([reason] + regression.cues).joined(separator: " ")
        )
        return SkillTrainingRungDecision(
            targetSkillId: skillId,
            targetSkillTitle: targetTitle,
            selectedRungId: regressionRungId(skillId: skillId, name: regression.name),
            selectedRungTitle: regression.name,
            source: .regression,
            reason: reason,
            prescriptions: [prescription]
        )
    }

    private static func regressionIndex(
        skillId: String,
        plan: SkillTrainingPlan,
        lastReview: SkillTrainingAgentReview?
    ) -> Int {
        guard let lastReview, lastReview.skillId == skillId else { return 0 }
        let currentIndex = plan.regressions.firstIndex { regression in
            regressionRungId(skillId: skillId, name: regression.name) == lastReview.selectedRungId
        } ?? 0

        switch lastReview.outcome {
        case .promote:
            return min(currentIndex + 1, plan.regressions.count - 1)
        case .hold:
            return currentIndex
        case .regress:
            return max(currentIndex - 1, 0)
        }
    }

    private static func regressionReason(
        targetTitle: String,
        index: Int,
        lastReview: SkillTrainingAgentReview?
    ) -> String {
        guard let lastReview else {
            return "Build toward \(targetTitle) with the first regression rung."
        }
        switch lastReview.outcome {
        case .promote:
            return "Advance one regression rung toward \(targetTitle) after the last review."
        case .hold:
            return "Repeat this regression rung for \(targetTitle) until the review is cleaner."
        case .regress:
            if index == 0 {
                return "Stay on the base regression for \(targetTitle) after the last review found friction."
            }
            return "Step back one regression rung for \(targetTitle) after the last review found friction."
        }
    }

    static func regressionRungId(skillId: String, name: String) -> String {
        "\(skillId).regression.\(slug(name))"
    }

    private static func defaultTarget(for exerciseName: String) -> PrescriptionTarget {
        let lower = exerciseName.lowercased()
        if lower.contains("hang")
            || lower.contains("hold")
            || lower.contains("support")
            || lower.contains("lean") {
            return .hold(seconds: 12)
        }
        return .repsRange(5, 8)
    }

    private static func slug(_ value: String) -> String {
        var output = ""
        var pendingHyphen = false
        for scalar in value.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                if pendingHyphen && !output.isEmpty {
                    output.append("-")
                }
                output.unicodeScalars.append(scalar)
                pendingHyphen = false
            } else {
                pendingHyphen = true
            }
        }
        return output.isEmpty ? "rung" : output
    }
}

private extension TrainingPrescription {
    func withRungReason(_ reason: String) -> TrainingPrescription {
        let combinedNotes: String
        if let notes, !notes.isEmpty {
            combinedNotes = "\(reason) \(notes)"
        } else {
            combinedNotes = reason
        }
        return TrainingPrescription(
            exerciseName: exerciseName,
            sets: sets,
            target: target,
            restSeconds: restSeconds,
            notes: combinedNotes
        )
    }
}
