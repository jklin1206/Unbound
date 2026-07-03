// UNBOUND/Services/Trials/TitleCatalog.swift
import Foundation

/// Maps TitleID → human-readable display name. The single naming source —
/// `TitleID.displayName` delegates here.
enum TitleCatalog {

    static func displayName(for id: TitleID) -> String {
        switch id.path {
        // Badge titles are named by the badge itself.
        case .badge(let badgeId):
            return BadgeCatalog.all.first { $0.id == badgeId }?.displayName ?? "Badge"
        // Shop titles are named by the shop-only cosmetic title catalog.
        case .shop(let shopTitleId):
            return ShopTitleCatalog.displayName(for: shopTitleId)
        case .squadSeasonWinner(let seasonNumber):
            // Season 1 is the "Ignition" season — its winner title is "First Flame".
            return max(1, seasonNumber) == 1 ? "First Flame" : "Season \(max(1, seasonNumber)) Winner"
        // Rank titles — one per gate-confirmed rank.
        case .rank(let tier):
            return rankTitleName(tier)
        // Axis titles — proving an axis earns its class name, so the strings
        // stay one source with the BuildClass vocabulary.
        case .axis(let key):
            return BuildClass.specialist(for: key).displayName
        // Legacy Binding Vows v1 names, kept only so persisted titles render.
        case .cardKind(let kind):
            return legacyCardKindName(kind, tier: id.tier)
        }
    }

    static func rankTitleName(_ tier: RankTier) -> String {
        L10n.string("titleRank.\(tier.token)", defaultValue: defaultRankTitleName(tier))
    }

    private static func defaultRankTitleName(_ tier: RankTier) -> String {
        switch tier {
        case .initiate:   return "The Unwritten"
        case .novice:     return "Dawnseeker"
        case .apprentice: return "The Counted"
        case .forged:     return "Emberborn"
        case .veteran:    return "Reckoner"
        case .master:     return "Summitborn"
        case .vessel:     return "Sealbearer"
        case .ascendant:  return "Skysworn"
        case .unbound:    return "Gatebreaker"
        }
    }

    private static func legacyCardKindName(_ kind: WeeklyVowKind, tier: TitleID.Tier) -> String {
        switch (kind, tier) {
        case (.ember, .bronze):     return "Steady Keeper"
        case (.ember, .silver):     return "Recovery Anchor"
        case (.ember, .gold):       return "Still Standard"
        case (.overdrive, .bronze): return "Final Set"
        case (.overdrive, .silver): return "Pressure Finisher"
        case (.overdrive, .gold):   return "Closer"
        case (.apex, .bronze):      return "Limit Tested"
        case (.apex, .silver):      return "Limit Breaker"
        case (.apex, .gold):        return "Limit Standard"
        }
    }

    /// Every earnable title in display order: the nine rank titles, then the
    /// six axis class titles. Legacy cardKind/tiered-axis titles are not
    /// earnable and only surface if already persisted.
    static let all: [TitleID] = {
        RankTier.allCases.map { TitleID.rank($0) }
            + AttributeKey.allCases.map { TitleID.axis($0) }
    }()
}
