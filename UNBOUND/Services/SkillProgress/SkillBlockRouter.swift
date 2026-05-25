import Foundation

enum SkillBlockRouter {
    static func insert(
        skillID: String,
        title: String,
        kind: SkillBlockKind,
        into draft: TrainingSessionDraft
    ) -> TrainingSessionDraft {
        var updated = draft
        let block = trainingBlock(skillID: skillID, title: title, kind: kind)
        let index = insertionIndex(for: kind, in: updated.blocks)
        updated.blocks.insert(block, at: index)
        return updated
    }

    static func workoutBlock(
        skillID: String,
        title: String,
        kind: SkillBlockKind
    ) -> WorkoutBlock {
        WorkoutBlock(
            kind: .skill,
            title: title,
            skillKind: kind,
            skillID: skillID,
            regionLoad: SkillBlockRegionTagger.regionLoad(for: skillID),
            prescriptions: [prescription(skillID: skillID, title: title)]
        )
    }

    private static func trainingBlock(
        skillID: String,
        title: String,
        kind: SkillBlockKind
    ) -> TrainingBlock {
        TrainingBlock(
            kind: .skill,
            title: "\(kind.displayName): \(title)",
            subtitle: "Program skill block",
            skillId: skillID,
            prescriptions: [prescription(skillID: skillID, title: title)],
            notes: "Scheduled skill work. Region load: \(regionSummary(for: skillID))."
        )
    }

    private static func insertionIndex(for kind: SkillBlockKind, in blocks: [TrainingBlock]) -> Int {
        switch kind {
        case .primer:
            return blocks.firstIndex { $0.kind != .routine && $0.kind != .cardio } ?? 0
        case .main:
            return blocks.firstIndex { $0.kind == .strength || $0.kind == .bodyweight } ?? blocks.count
        case .accessory:
            let lastMain = blocks.lastIndex { $0.kind == .strength || $0.kind == .bodyweight }
            return lastMain.map { $0 + 1 } ?? blocks.count
        case .mobility:
            return blocks.count
        }
    }

    private static func prescription(skillID: String, title: String) -> TrainingBlockPrescription {
        TrainingBlockPrescription(
            exerciseName: title,
            rankStandardMovementId: skillID,
            sets: 3,
            target: .repsRange(3, 5),
            restSeconds: 90,
            muscleGroups: muscleGroups(for: SkillBlockRegionTagger.regionLoad(for: skillID)),
            rpe: 7,
            notes: "Skill block inserted into Program."
        )
    }

    private static func muscleGroups(for load: RegionLoad) -> [MuscleGroup] {
        var groups: [MuscleGroup] = []
        for region in load.loads.keys {
            switch region {
            case .pull:
                groups.append(.back)
            case .push:
                groups.append(.chest)
            case .legs:
                groups.append(.legs)
            case .core:
                groups.append(.core)
            case .posterior:
                groups.append(.glutes)
            case .shoulders:
                groups.append(.shoulders)
            case .other:
                break
            }
        }
        return groups.isEmpty ? [.core] : Array(Set(groups))
    }

    private static func regionSummary(for skillID: String) -> String {
        SkillBlockRegionTagger.regionLoad(for: skillID).loads
            .sorted { $0.key.displayName < $1.key.displayName }
            .map { "\($0.key.displayName) \(String(format: "%.1f", $0.value))" }
            .joined(separator: ", ")
    }
}
