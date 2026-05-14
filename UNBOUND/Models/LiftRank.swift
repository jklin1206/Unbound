import Foundation

// MARK: - LiftRank
//
// Per-user-per-lift persistent rank. Written by RankService whenever a
// logged session crosses a sub-rank threshold. `peakRank` floors decay so
// a user who once hit B+ can never drop below B+ — only `currentRank`
// moves during inactivity.
//
// MIGRATION NOTE: This type is being phased out in favour of SkillTier +
// LiftTierService. All public API references in protocols and views have
// been migrated. The remaining internal usages in RankService /
// MuscleRankCalculator will be cleaned up in a follow-up once RegionRank
// is ported to SkillTier.

struct LiftRank: Codable, Identifiable, Sendable, Hashable {
    /// "{userId}:{exerciseKey}" — stable composite key for DatabaseService.
    let id: String
    let userId: String
    let exerciseKey: String
    let displayName: String
    var currentRank: SubRank
    var peakRank: SubRank
    var lastAdvanceAt: Date
    var lastActivityAt: Date

    init(
        userId: String,
        exerciseKey: String,
        displayName: String,
        currentRank: SubRank,
        peakRank: SubRank? = nil,
        lastAdvanceAt: Date = Date(),
        lastActivityAt: Date = Date()
    ) {
        let key = exerciseKey.trimmingCharacters(in: .whitespaces).lowercased()
        self.id = "\(userId):\(key)"
        self.userId = userId
        self.exerciseKey = key
        self.displayName = displayName
        self.currentRank = currentRank
        self.peakRank = peakRank ?? currentRank
        self.lastAdvanceAt = lastAdvanceAt
        self.lastActivityAt = lastActivityAt
    }
}
