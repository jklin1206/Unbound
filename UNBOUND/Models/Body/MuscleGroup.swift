import Foundation

enum MuscleGroup: String, Codable, CaseIterable, Sendable {
    case chest, back, shoulders, arms, forearms, legs, glutes, core, traps, neck, lats, calves

    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .arms: return "Arms"
        case .forearms: return "Forearms"
        case .legs: return "Legs"
        case .glutes: return "Glutes"
        case .core: return "Core"
        case .traps: return "Traps"
        case .neck: return "Neck"
        case .lats: return "Lats"
        case .calves: return "Calves"
        }
    }
}
