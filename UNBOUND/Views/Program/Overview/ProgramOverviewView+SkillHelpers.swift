import Foundation

extension ProgramOverviewView {
    func routedSkillNodes(on date: Date) -> [SkillNode] {
        ProgramSkillFocusResolver.scheduledSkillNodes(on: date)
    }

    func skillNodes(from draft: TrainingSessionDraft?) -> [SkillNode] {
        ProgramSkillFocusResolver.skillNodes(from: draft)
    }

    func compactSkillTitle(_ nodes: [SkillNode]) -> String? {
        ProgramSkillFocusResolver.compactTitle(for: nodes)
    }

    func skillMetricTitle(for nodes: [SkillNode], day: ProgramDay?) -> String {
        ProgramSkillFocusResolver.metricTitle(
            for: nodes,
            day: day,
            isCalibration: isCalibrationDay(day)
        )
    }

    func skillMetricIcon(for nodes: [SkillNode], day: ProgramDay?) -> String {
        ProgramSkillFocusResolver.metricIcon(
            for: nodes,
            day: day,
            isCalibration: isCalibrationDay(day)
        )
    }
}
