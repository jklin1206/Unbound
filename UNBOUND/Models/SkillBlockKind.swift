import Foundation

enum SkillBlockKind: String, Codable, CaseIterable, Sendable, Hashable {
    case primer
    case main
    case accessory
    case mobility

    var displayName: String {
        switch self {
        case .primer: return "Primer"
        case .main: return "Main Skill"
        case .accessory: return "Accessory Skill"
        case .mobility: return "Mobility"
        }
    }
}
