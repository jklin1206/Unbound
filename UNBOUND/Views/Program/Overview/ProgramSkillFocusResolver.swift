import Foundation

enum ProgramSkillFocusResolver {
    @MainActor
    static func scheduledSkillNodes(on date: Date) -> [SkillNode] {
        ProgramScheduler.shared.skillIds(forDate: date).compactMap { SkillGraph.shared.node(id: $0) }
    }

    static func skillNodes(from draft: TrainingSessionDraft?) -> [SkillNode] {
        guard let draft else { return [] }
        let skillIds = draft.blocks.compactMap { block -> String? in
            guard block.kind == .skill else { return nil }
            return block.skillId
        }

        return skillIds.reduce(into: [SkillNode]()) { result, skillId in
            guard
                result.contains(where: { $0.id == skillId }) == false,
                let node = SkillGraph.shared.node(id: skillId)
            else { return }
            result.append(node)
        }
    }

    static func compactTitle(for nodes: [SkillNode]) -> String? {
        guard let first = nodes.first else { return nil }
        if nodes.count == 1 { return first.title.uppercased() }
        if nodes.count == 2 {
            return "\(first.title) + \(nodes[1].title)".uppercased()
        }
        return "\(first.title) + \(nodes.count - 1) SKILLS".uppercased()
    }

    static func metricTitle(
        for nodes: [SkillNode],
        day: ProgramDay?,
        isCalibration: Bool
    ) -> String {
        if isCalibration { return "RPE 6-7" }
        if day?.isRestDay == true { return "REC" }
        if nodes.isEmpty { return "LIVE" }
        return "\(nodes.count) SKILL\(nodes.count == 1 ? "" : "S")"
    }

    static func metricIcon(
        for nodes: [SkillNode],
        day: ProgramDay?,
        isCalibration: Bool
    ) -> String {
        if isCalibration { return "target" }
        if day?.isRestDay == true { return "moon.zzz.fill" }
        return nodes.isEmpty ? "bolt.fill" : "scope"
    }
}
