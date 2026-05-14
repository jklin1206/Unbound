import SwiftUI

// MARK: - SideQuestCategory

enum SideQuestCategory: String, Codable, Sendable, CaseIterable {
    case circuit, cardio, mobility, activity

    var label: String {
        switch self {
        case .circuit:  return "CIRCUIT"
        case .cardio:   return "CARDIO"
        case .mobility: return "MOBILITY"
        case .activity: return "ACTIVITY"
        }
    }

    var color: Color {
        switch self {
        case .circuit:  return Color.unbound.accent
        case .cardio:   return Color.unbound.coachCyan
        case .mobility: return Color.unbound.rankGreen
        case .activity: return Color.unbound.warnOrange
        }
    }
}

// MARK: - SideQuestExercise

struct SideQuestExercise: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let sets: Int
    let reps: String       // "12", "8-12", "30s", "AMRAP", "30s each"
    let restSeconds: Int
    let cue: String?
    let muscleGroups: [String]

    init(
        id: String = UUID().uuidString,
        name: String,
        sets: Int,
        reps: String,
        restSeconds: Int,
        cue: String? = nil,
        muscleGroups: [String] = []
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
        self.cue = cue
        self.muscleGroups = muscleGroups
    }

    var defaultRepCount: Int {
        if reps.uppercased().hasPrefix("AMRAP") { return 0 }
        if reps.hasSuffix("s") || reps.lowercased().hasSuffix("s each") {
            let stripped = reps.lowercased()
                .replacingOccurrences(of: " each", with: "")
                .replacingOccurrences(of: "s", with: "")
            return Int(stripped) ?? 30
        }
        if reps.contains("-") {
            let parts = reps.split(separator: "-").compactMap { Int($0) }
            return parts.last ?? 10
        }
        if reps.lowercased().contains("each") {
            return Int(reps.components(separatedBy: " ").first ?? "5") ?? 5
        }
        return Int(reps) ?? 10
    }

    var isTimeBased: Bool {
        reps.hasSuffix("s") || reps.lowercased().hasSuffix("s each") || reps.contains("min")
    }

    var stepperLabel: String { isTimeBased ? "SECS" : "REPS" }
}

// MARK: - SideQuest

struct SideQuest: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let category: SideQuestCategory
    let estimatedMinutes: Int
    let spReward: Int
    let exercises: [SideQuestExercise]

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets } }
}

// MARK: - SideQuestLog

struct SideQuestLog: Codable, Identifiable {
    let id: String
    let userId: String
    let questId: String
    var startedAt: Date
    var completedAt: Date?
    var setLogs: [SideQuestSetLog]
    var spAwarded: Int

    var isComplete: Bool { completedAt != nil }
}

struct SideQuestSetLog: Codable, Identifiable {
    let id: String
    let exerciseId: String
    var exerciseName: String
    var setNumber: Int
    var completedReps: Int
    var completedAt: Date
}
