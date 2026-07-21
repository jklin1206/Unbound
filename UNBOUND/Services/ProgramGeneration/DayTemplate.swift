// UNBOUND/Services/ProgramGeneration/DayTemplate.swift
import Foundation

/// A high-level template for what a training day emphasizes. Used by the
/// split lookup to define the sequence of days inside a block, and by the
/// generator to pick an exercise pool per day.
enum DayTemplate: String, Codable, CaseIterable, Hashable {
    case push
    case pull
    case legs
    case upper
    case lower
    case fullBody
    case skill          // calisthenic-specific skill day (handstand, muscle-up work)
    case weakPoint      // targeted day driven by scan focus areas; muscle groups filled at gen time
    case rest

    var isRest: Bool { self == .rest }

    /// Base muscle groups the template emphasizes. weakPoint and rest return
    /// empty; the generator fills weakPoint dynamically from the scan's focus areas.
    var muscleGroups: [MuscleGroup] {
        switch self {
        case .push: return [.chest, .shoulders, .triceps]
        case .pull: return [.back, .lats, .biceps, .traps]
        case .legs: return [.quads, .hamstrings, .glutes, .calves, .core]
        case .upper: return [.chest, .back, .shoulders, .biceps, .triceps, .lats]
        case .lower: return [.quads, .hamstrings, .glutes, .calves, .core]
        case .fullBody: return [.chest, .back, .quads, .hamstrings, .shoulders, .core]
        case .skill: return [.core, .biceps, .triceps, .shoulders]
        case .weakPoint: return []
        case .rest: return []
        }
    }

    var displayLabel: String {
        switch self {
        case .push: return "Push"
        case .pull: return "Pull"
        case .legs: return "Legs"
        case .upper: return "Upper"
        case .lower: return "Lower"
        case .fullBody: return "Full Body"
        case .skill: return "Skill"
        case .weakPoint: return "Weak Point"
        case .rest: return "Rest"
        }
    }
}
