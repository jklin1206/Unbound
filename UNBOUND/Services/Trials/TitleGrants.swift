// UNBOUND/Services/Trials/TitleGrants.swift
import Foundation

/// Derives which rank + axis titles a user is entitled to and grants the
/// missing ones. Rank titles come from the trial-confirmed rank; axis titles
/// are the axis's class name (Titan, Monk, …), earned when the attribute
/// reaches `axisTitleBar`. `reconcile` is quiet — a retroactive backfill must
/// not spam the squad feed — while fresh crossings announce at their event
/// sites (`OverallRankTrialRunner`, `AttributeService`).
@MainActor
enum TitleGrants {
    /// Attribute rank an axis must reach to earn its class-name title —
    /// the crown band, the same bar as the A-tier rank-up cinematic.
    static let axisTitleBar: RankTier = .vessel

    /// Pure entitlement: every title the given state has earned.
    static func entitledTitles(confirmedRank: RankTier, profile: AttributeProfile) -> [TitleID] {
        let rankTitles = RankTier.allCases
            .filter { $0 <= confirmedRank }
            .map { TitleID.rank($0) }
        let axisTitles = AttributeKey.allCases
            .filter { profile.value(for: $0).rankTitle >= axisTitleBar }
            .map { TitleID.axis($0) }
        return rankTitles + axisTitles
    }

    /// Quietly grant every entitled-but-missing title (idempotent,
    /// retroactive). Call after live announced grants so fresh unlocks keep
    /// their feed moment.
    static func reconcile(
        userId: String,
        titles: any WeeklyVowsServiceProtocol = WeeklyVowsService.shared,
        rankProgress: OverallRankTrialStore = .shared,
        attributes: any AttributeServiceProtocol = AttributeService.shared
    ) {
        let rank = rankProgress.load(userId: userId).currentRank
        let profile = attributes.profile(userId: userId)
        for title in entitledTitles(confirmedRank: rank, profile: profile) {
            titles.unlockTitle(title, userId: userId, announce: false)
        }
    }
}
