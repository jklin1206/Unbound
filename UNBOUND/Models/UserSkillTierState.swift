import Foundation

/// User's persisted per-skill tier state. Per-skill current tier + macro
/// counters for the profile surface. Skills not present in `perSkill`
/// default to `.initiate` when read via `tier(for:)`.
struct UserSkillTierState: Codable, Equatable, Sendable {
    var perSkill: [String: SkillTier]
    var rankUpsEarned: Int
    var ascendantSkills: [String]

    static let empty = UserSkillTierState(
        perSkill: [:],
        rankUpsEarned: 0,
        ascendantSkills: []
    )

    func tier(for skillId: String) -> SkillTier {
        perSkill[skillId] ?? .initiate
    }
}
