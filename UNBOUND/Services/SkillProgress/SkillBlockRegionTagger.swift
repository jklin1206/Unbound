import Foundation

enum SkillBlockRegionTagger {
    static func regionLoad(for skillID: String) -> RegionLoad {
        let normalized = normalize(skillID)
        switch normalized {
        case let id where id.contains("pull") || id.contains("chin") || id.contains("front_lever"):
            return RegionLoad([.pull: 1.0, .core: 0.3])
        case let id where id.contains("muscle_up"):
            return RegionLoad([.pull: 1.0, .shoulders: 0.5, .core: 0.3])
        case let id where id.contains("handstand") || id.contains("hspu"):
            return RegionLoad([.shoulders: 1.0, .push: 0.5, .core: 0.3])
        case let id where id.contains("dip") || id.contains("push"):
            return RegionLoad([.push: 1.0, .shoulders: 0.3])
        case let id where id.contains("squat") || id.contains("pistol") || id.contains("shrimp"):
            return RegionLoad([.legs: 1.0, .core: 0.2])
        case let id where id.contains("l_sit") || id.contains("dragon") || id.contains("hollow"):
            return RegionLoad([.core: 1.0, .push: 0.2])
        case let id where id.contains("mobility") || id.contains("bridge"):
            return RegionLoad([.shoulders: 0.3, .posterior: 0.3])
        default:
            return RegionLoad([.other(normalized.isEmpty ? "skill" : normalized): 0.5])
        }
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }
}
