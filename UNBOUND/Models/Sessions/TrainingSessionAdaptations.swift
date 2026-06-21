import Foundation

enum TrainingSessionAdaptationKind: String, Codable, Hashable, Sendable {
    case scheduledSkill
    case travel
    case shortSession
    case substitution
    case deload
    case trialPrep
    case skillTaper
}

struct TrainingSessionAdaptationLine: Equatable, Sendable {
    let kind: TrainingSessionAdaptationKind
    let title: String
    let detail: String
}

enum ProgramModifierColorRole: String, Codable, Hashable, Sendable {
    case accent
    case warning
    case neutral
}

struct ProgramModifierLine: Equatable, Sendable {
    let kind: TrainingSessionAdaptationKind
    let priority: Int
    let iconName: String
    let colorRole: ProgramModifierColorRole
    let title: String
    let detail: String
}

struct ProgramModifierSummary: Equatable, Sendable {
    let lines: [ProgramModifierLine]
    let visibleLimit: Int

    var isEmpty: Bool {
        lines.isEmpty
    }

    var visibleLines: [ProgramModifierLine] {
        Array(lines.prefix(visibleLimit))
    }

    var overflowCount: Int {
        max(0, lines.count - visibleLimit)
    }

    static func summarize(
        draft: TrainingSessionDraft,
        isTravelDay: Bool = false,
        visibleLimit: Int = 3
    ) -> ProgramModifierSummary {
        let lines = TrainingSessionAdaptationSummary.summarize(
            draft: draft,
            isTravelDay: isTravelDay
        )
        .map(ProgramModifierLine.init(adaptation:))
        .sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.title < rhs.title
        }

        return ProgramModifierSummary(lines: lines, visibleLimit: visibleLimit)
    }
}

enum TrainingSessionAdaptationSummary {
    static func summarize(
        draft: TrainingSessionDraft,
        isTravelDay: Bool = false
    ) -> [TrainingSessionAdaptationLine] {
        let prescriptions = draft.blocks.flatMap(\.prescriptions)
        var lines: [TrainingSessionAdaptationLine] = []

        let scheduledSkillCount = draft.blocks.filter { $0.kind == .skill && $0.skillId != nil }.count
        if scheduledSkillCount > 0 {
            lines.append(
                TrainingSessionAdaptationLine(
                    kind: .scheduledSkill,
                    title: scheduledSkillCount == 1 ? "Skill focus attached" : "\(scheduledSkillCount) skill focuses attached",
                    detail: "Placed before the base session so focused practice does not get buried."
                )
            )
        }

        if isTravelDay {
            lines.append(
                TrainingSessionAdaptationLine(
                    kind: .travel,
                    title: "Travel mode active",
                    detail: "Using the travel plan and available-equipment work for this date."
                )
            )
        }

        let shortModeCount = prescriptions.filter { containsNote($0.notes, "Short mode") }.count
        if shortModeCount > 0 {
            lines.append(
                TrainingSessionAdaptationLine(
                    kind: .shortSession,
                    title: "Short mode active",
                    detail: "\(shortModeCount) priority exercise\(shortModeCount == 1 ? "" : "s") kept; accessories trimmed for today."
                )
            )
        }

        let substitutedCount = prescriptions.filter {
            containsNote($0.notes, "today's modifiers") || containsNote($0.notes, "swapped from")
        }.count
        if substitutedCount > 0 {
            lines.append(
                TrainingSessionAdaptationLine(
                    kind: .substitution,
                    title: substitutedCount == 1 ? "1 exercise swapped" : "\(substitutedCount) exercises swapped",
                    detail: "Replacement choices keep the same movement pattern where possible."
                )
            )
        }

        let deloadCount = prescriptions.filter { containsNote($0.notes, "deload") }.count
        if deloadCount > 0 {
            lines.append(
                TrainingSessionAdaptationLine(
                    kind: .deload,
                    title: "Deload volume applied",
                    detail: "\(deloadCount) exercise\(deloadCount == 1 ? "" : "s") reduced to protect recovery."
                )
            )
        }

        let trialPrepCount = prescriptions.filter { containsNote($0.notes, "trial prep") }.count
        if trialPrepCount > 0 {
            lines.append(
                TrainingSessionAdaptationLine(
                    kind: .trialPrep,
                    title: "Trial prep included",
                    detail: "\(trialPrepCount) requirement-focused movement\(trialPrepCount == 1 ? "" : "s") added."
                )
            )
        }

        let taperCount = prescriptions.filter { containsNote($0.notes, "scheduled skill work") }.count
        if taperCount > 0 {
            lines.append(
                TrainingSessionAdaptationLine(
                    kind: .skillTaper,
                    title: "Base volume tapered",
                    detail: "\(taperCount) overlapping exercise\(taperCount == 1 ? "" : "s") trimmed because skill work is already attached."
                )
            )
        }

        return lines
    }

    private static func containsNote(_ note: String?, _ needle: String) -> Bool {
        note?.localizedCaseInsensitiveContains(needle) == true
    }
}

private extension ProgramModifierLine {
    init(adaptation: TrainingSessionAdaptationLine) {
        self.init(
            kind: adaptation.kind,
            priority: adaptation.kind.priority,
            iconName: adaptation.kind.iconName,
            colorRole: adaptation.kind.colorRole,
            title: adaptation.title,
            detail: adaptation.detail
        )
    }
}

private extension TrainingSessionAdaptationKind {
    var priority: Int {
        switch self {
        case .deload:
            return 10
        case .shortSession:
            return 15
        case .substitution:
            return 20
        case .travel:
            return 30
        case .scheduledSkill:
            return 40
        case .trialPrep:
            return 50
        case .skillTaper:
            return 60
        }
    }

    var iconName: String {
        switch self {
        case .scheduledSkill:
            return "figure.strengthtraining.traditional"
        case .travel:
            return "airplane"
        case .shortSession:
            return "timer"
        case .substitution:
            return "arrow.triangle.2.circlepath"
        case .deload:
            return "gauge.with.dots.needle.33percent"
        case .trialPrep:
            return "target"
        case .skillTaper:
            return "scissors"
        }
    }

    var colorRole: ProgramModifierColorRole {
        switch self {
        case .scheduledSkill, .trialPrep, .shortSession:
            return .accent
        case .travel, .substitution:
            return .warning
        case .deload, .skillTaper:
            return .neutral
        }
    }
}
