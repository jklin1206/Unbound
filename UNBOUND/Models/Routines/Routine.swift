import SwiftUI

// MARK: - RoutineCategory

enum RoutineCategory: CaseIterable, Hashable {
    case cardio, mobility, challenge, altCircuit

    var label: String {
        switch self {
        case .cardio:     return "CARDIO WING"
        case .mobility:   return "MOBILITY WING"
        case .challenge:  return "BOSS FLOORS"
        case .altCircuit: return "ARSENAL"
        }
    }

    var systemImage: String {
        switch self {
        case .cardio:     return "figure.run"
        case .mobility:   return "figure.flexibility"
        case .challenge:  return "flame.fill"
        case .altCircuit: return "dumbbell.fill"
        }
    }

    var color: Color {
        switch self {
        case .cardio:     return Color.unbound.coachCyan
        case .mobility:   return Color.unbound.rankGreen
        case .challenge:  return Color.unbound.warnOrange
        case .altCircuit: return Color.unbound.accent
        }
    }
}

// MARK: - RoutineDef

struct RoutineDef: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let durationLabel: String
    let category: RoutineCategory
    let difficultyTier: SkillTier
    let difficultyWeight: Int
    var steps: [RoutineStep]

    init(
        id: String,
        title: String,
        subtitle: String,
        durationLabel: String,
        category: RoutineCategory,
        difficultyTier: SkillTier = .initiate,
        difficultyWeight: Int,
        steps: [RoutineStep] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.durationLabel = durationLabel
        self.category = category
        self.difficultyTier = difficultyTier
        self.difficultyWeight = difficultyWeight
        self.steps = steps
    }
}

// MARK: - RoutineUnlockPolicy

struct RoutineUnlockState: Equatable, Sendable {
    let requiredTier: SkillTier
    let currentTier: SkillTier

    var isUnlocked: Bool {
        currentTier >= requiredTier
    }

    var requirementText: String {
        guard requiredTier > .initiate else { return "Open from the start" }
        return "Reach \(requiredTier.displayName) depth to open this floor"
    }

    var lockedText: String {
        "Reach \(requiredTier.displayName)"
    }
}

enum RoutineUnlockPolicy {
    static func state(for routine: RoutineDef, currentTier: SkillTier) -> RoutineUnlockState {
        RoutineUnlockState(
            requiredTier: routine.difficultyTier,
            currentTier: currentTier
        )
    }
}
