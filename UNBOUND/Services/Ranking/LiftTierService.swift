// UNBOUND/Services/Ranking/LiftTierService.swift
import Foundation

@MainActor
final class LiftTierService {
    static let shared = LiftTierService()
    private let key = "unbound.liftTier."
    private let defaults: UserDefaults

    /// The barbell compounds whose per-lift tiers feed the overall-rank aggregate
    /// and are mirrored to the cloud (`lift_tiers`). The single source for the set
    /// of lift keys, shared by `RankService` and the rank-progress backup/restore.
    /// `nonisolated` so the sign-in migration (off the main actor) can read it.
    nonisolated static let trackedLiftKeys = ["bench press", "back squat", "deadlift", "overhead press"]

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
