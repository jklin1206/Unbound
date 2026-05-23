// UNBOUND/Services/Ranking/LiftTierService.swift
import Foundation

@MainActor
final class LiftTierService {
    static let shared = LiftTierService()
    private let key = "unbound.liftTier."
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func tier(lift: String, userId: String) -> SkillTier {
        let rawValue = defaults.integer(forKey: key + "\(userId).\(lift)")
        return SkillTier(rawValue: rawValue) ?? .initiate
    }

    func save(tier: SkillTier, lift: String, userId: String) {
        defaults.set(tier.rawValue, forKey: key + "\(userId).\(lift)")
    }
}
