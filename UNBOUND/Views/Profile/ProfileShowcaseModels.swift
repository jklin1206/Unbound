import SwiftUI
import PhotosUI

struct ProfileShowcaseSelection: Codable, Equatable {
    var skillId: String?
    var liftId: String?

    static let empty = ProfileShowcaseSelection(skillId: nil, liftId: nil)
}

struct ProfileShowcaseOption: Identifiable, Hashable {
    let id: String
    let name: String
    let tier: SkillTier
    let metricSort: Double
    let repsSort: Int
}

enum ProfileShowcaseStore {
    private static let keyPrefix = "unbound.profileShowcase."

    static func load(userId: String) -> ProfileShowcaseSelection {
        guard let data = UserDefaults.standard.data(forKey: keyPrefix + userId),
              let selection = try? JSONDecoder().decode(ProfileShowcaseSelection.self, from: data)
        else {
            return .empty
        }
        return selection
    }

    static func save(_ selection: ProfileShowcaseSelection, userId: String) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: keyPrefix + userId)
    }
}
