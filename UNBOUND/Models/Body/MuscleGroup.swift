import Foundation

enum MuscleGroup: String, Codable, CaseIterable, Sendable {
    case chest, back, shoulders, biceps, triceps, forearms
    case quads, hamstrings, glutes, core, traps, neck, lats, calves

    /// Legacy coarse groups. Still decodable because they live in persisted
    /// data (workout logs, saved sessions, cloud backups, focus areas), but
    /// the catalog, day templates, and all new tagging emit the fine-grained
    /// cases above instead. Use `modernized` when matching against new tags.
    case arms, legs

    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .forearms: return "Forearms"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .core: return "Core"
        case .traps: return "Traps"
        case .neck: return "Neck"
        case .lats: return "Lats"
        case .calves: return "Calves"
        case .arms: return "Arms"
        case .legs: return "Legs"
        }
    }

    /// Fine-grained equivalents for the legacy coarse cases; identity for
    /// everything else. Matching between persisted data (which may carry
    /// `.arms`/`.legs`) and current tags must go through this.
    var modernized: [MuscleGroup] {
        switch self {
        case .arms: return [.biceps, .triceps]
        case .legs: return [.quads, .hamstrings]
        default: return [self]
        }
    }

    /// Order-preserving, deduplicated modernization of a tag list.
    static func modernized(_ groups: [MuscleGroup]) -> [MuscleGroup] {
        var seen = Set<MuscleGroup>()
        return groups.flatMap(\.modernized).filter { seen.insert($0).inserted }
    }
}
