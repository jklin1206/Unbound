import Foundation

/// Identifier for an earned Title.
struct TitleID: Codable, Hashable, Sendable {
    enum Path: Codable, Hashable, Sendable {
        /// Proof of an elite attribute axis — the axis's class name (Titan,
        /// Monk, …) earned when it reaches `TitleGrants.axisTitleBar`. Tier is
        /// unused (carried as `.gold`).
        case axis(AttributeKey)
        /// Legacy Binding Vows v1 track; never awarded since v2 but may exist
        /// in persisted state, so the case stays for decode compat.
        case cardKind(WeeklyVowKind)
        /// The title earned by confirming a rank at its gate. Tier is unused
        /// (carried as `.gold`).
        case rank(RankTier)
        /// A title earned by unlocking a badge (badge id). Tier is unused for
        /// these (carried as `.gold`); the name comes from the badge itself.
        case badge(String)
        /// A cosmetic title bought in the Shop. Tier is unused for these
        /// (carried as `.gold`); the name comes from `ShopTitleCatalog`.
        case shop(String)
        /// The single personal title awarded to the #1 member on a squad
        /// season leaderboard.
        case squadSeasonWinner(Int)
    }
    /// Legacy Binding Vows v1 ladder. New awards always carry `.gold`; the
    /// field survives for persisted-state and wire compat.
    enum Tier: String, Codable, CaseIterable, Sendable {
        case bronze
        case silver
        case gold
    }
    let path: Path
    let tier: Tier
}

// MARK: - Display helpers

extension TitleID {
    /// `TitleCatalog` owns all title naming; this is a convenience mirror.
    var displayName: String {
        TitleCatalog.displayName(for: self)
    }

    var rewardAssetName: String? {
        switch path {
        case .squadSeasonWinner(let seasonNumber) where max(1, seasonNumber) == 1:
            return "squad_reward_season_1_winner"
        default:
            return nil
        }
    }

    /// Convenience: the title earned by confirming a rank at its gate.
    static func rank(_ tier: RankTier) -> TitleID {
        TitleID(path: .rank(tier), tier: .gold)
    }

    /// Convenience: the axis class-name title (Titan, Monk, …).
    static func axis(_ key: AttributeKey) -> TitleID {
        TitleID(path: .axis(key), tier: .gold)
    }

    /// Convenience: the title earned by unlocking a badge.
    static func badge(_ badgeId: String) -> TitleID {
        TitleID(path: .badge(badgeId), tier: .gold)
    }

    /// Convenience: a title bought in the Shop.
    static func shop(_ id: String) -> TitleID {
        TitleID(path: .shop(id), tier: .gold)
    }

    /// Convenience: the personal title earned by finishing #1 on a squad
    /// season leaderboard.
    static func squadSeasonWinner(_ seasonNumber: Int) -> TitleID {
        TitleID(path: .squadSeasonWinner(max(1, seasonNumber)), tier: .gold)
    }
}

enum ShopTitleCatalog {
    static func displayName(for id: String) -> String {
        switch id {
        case "chalkGhost": return "Chalked Up"
        case "nightShift": return "Sleep Debt CEO"
        case "ironStatic": return "PR Pending"
        case "goldSignal": return "Aura Farmer"
        case "solarBreaker": return "Main Character Arc"
        default:
            return id
                .replacingOccurrences(of: "_", with: " ")
                .split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
    }
}
